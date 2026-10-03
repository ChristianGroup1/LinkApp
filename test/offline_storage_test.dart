import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/offline/member_local_store.dart';
import 'package:link/data/offline/offline_cache.dart';
import 'package:link/data/offline/offline_entity_json.dart';
import 'package:link/data/offline/offline_write_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('concurrent queue writes preserve every offline operation', () async {
    final queues = List.generate(4, (_) => OfflineWriteQueue());

    await Future.wait(
      List.generate(100, (index) {
        return queues[index % queues.length].enqueue(
          QueuedOperation(
            id: 'operation-$index',
            type: OfflineOpType.memberUpdate,
            payload: {'id': 'member-$index'},
            queuedAt: DateTime.utc(2026, 1, 1),
          ),
        );
      }),
    );

    final operations = await OfflineWriteQueue().all();
    expect(operations, hasLength(100));
    expect(operations.map((item) => item.id).toSet(), hasLength(100));
  });

  test('concurrent id mappings preserve every remapping', () async {
    final queue = OfflineWriteQueue();

    await Future.wait(
      List.generate(
        100,
        (index) => queue.mapId('offline-$index', 'server-$index'),
      ),
    );

    final mappings = await queue.idMappings();
    expect(mappings, hasLength(100));
    expect(await queue.resolveId('offline-42'), 'server-42');
  });

  test(
    'pendingDeletedEntityIds returns ids from queued delete operations',
    () async {
      final queue = OfflineWriteQueue();
      await queue.enqueue(
        QueuedOperation(
          id: 'delete-member',
          type: OfflineOpType.memberDelete,
          payload: {'id': 'member-1'},
          queuedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'delete-meeting',
          type: OfflineOpType.meetingDelete,
          payload: {'id': 'meeting-9'},
          queuedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'update-member',
          type: OfflineOpType.memberUpdate,
          payload: {'id': 'member-2'},
          queuedAt: DateTime.utc(2026, 1, 3),
        ),
      );

      final pendingDeletes = await queue.pendingDeletedEntityIds();
      expect(pendingDeletes, {'member-1', 'meeting-9'});
    },
  );

  test('profile changes are reflected in the offline profile list', () async {
    const original = AppProfile(
      id: 'servant-1',
      churchId: 'church-1',
      fullName: 'خادم تجريبي',
      role: AppRole.attendanceOfficer,
      isActive: true,
    );
    const updated = AppProfile(
      id: 'servant-1',
      churchId: 'church-1',
      fullName: 'خادم تجريبي',
      role: AppRole.churchAdmin,
      isActive: false,
    );
    final cache = OfflineCache();
    await cache.saveProfiles('church-1', [profileToJson(original)]);

    await cache.upsertProfile('church-1', updated);

    final profiles = await cache.readProfiles('church-1');
    expect(profiles, hasLength(1));
    expect(profiles!.single.role, AppRole.churchAdmin);
    expect(profiles.single.isActive, isFalse);
  });

  test('offline assignments stay consistent in both cache views', () async {
    const servant = AppProfile(
      id: 'servant-1',
      churchId: 'church-1',
      fullName: 'مينا',
      role: AppRole.attendanceOfficer,
      email: 'mina@example.com',
    );
    const cls = SundaySchoolClassEntity(
      id: 'class-1',
      churchId: 'church-1',
      meetingId: 'meeting-1',
      name: 'Class 1',
      nameAr: 'فصل أولى',
      displayOrder: 0,
      isActive: true,
    );
    final cache = OfflineCache();
    await cache.saveProfiles('church-1', [profileToJson(servant)]);
    await cache.saveClasses('church-1', [classToJson(cls)]);

    final assignmentId = await cache.upsertClassAssignment(
      churchId: 'church-1',
      assignmentId: 'offline_assignment_1',
      classId: 'class-1',
      userId: 'servant-1',
      canTakeAttendance: true,
      canViewReports: false,
    );

    expect(assignmentId, 'offline_assignment_1');
    final byUser = await cache.readClassAssignments('servant-1');
    final byClass = await cache.readClassAssignmentsForClass('class-1');
    expect(byUser!.single['class_id'], 'class-1');
    expect(byClass!.single['user_id'], 'servant-1');
    expect(byUser.single['can_view_reports'], isFalse);

    final sameAssignmentId = await cache.upsertClassAssignment(
      churchId: 'church-1',
      assignmentId: 'offline_assignment_2',
      classId: 'class-1',
      userId: 'servant-1',
      canTakeAttendance: false,
      canViewReports: true,
    );
    expect(sameAssignmentId, assignmentId);
    expect(
      (await cache.readClassAssignments(
        'servant-1',
      ))!.single['can_view_reports'],
      isTrue,
    );

    await cache.removeAssignmentEverywhere(
      assignmentId,
      isClassAssignment: true,
    );
    expect(await cache.readClassAssignments('servant-1'), isEmpty);
    expect(await cache.readClassAssignmentsForClass('class-1'), isEmpty);
  });

  test('every queued offline operation has a deterministic sync order', () {
    expect(
      OfflineOpType.syncOrder,
      contains(OfflineOpType.currentProfileUpdate),
    );
    expect(OfflineOpType.syncOrder, contains(OfflineOpType.profileRoleUpdate));
    expect(OfflineOpType.syncOrder, contains(OfflineOpType.invitationUpdate));
    expect(
      OfflineOpType.syncOrder,
      contains(OfflineOpType.classAssignmentUpsert),
    );
    expect(
      OfflineOpType.syncOrder,
      contains(OfflineOpType.meetingAssignmentDelete),
    );
    expect(
      OfflineOpType.syncOrder.toSet(),
      hasLength(OfflineOpType.syncOrder.length),
    );
  });

  test(
    'rejected operations are counted and cleared on acknowledgement',
    () async {
      final queue = OfflineWriteQueue();
      final operation = QueuedOperation(
        id: 'op-refused',
        type: OfflineOpType.memberUpdate,
        payload: {'id': 'member-1'},
        queuedAt: DateTime.utc(2026, 1, 1),
      );

      expect(await queue.rejectedCount(), 0);
      await queue.reject(operation, 'row-level security');
      expect(await queue.rejectedCount(), 1);

      await queue.clearRejected();
      expect(await queue.rejectedCount(), 0);
    },
  );

  test('only unfixable server refusals count as permanent rejections', () {
    expect(
      isPermanentServerRejection(
        PostgrestException(message: 'rls', code: '42501'),
      ),
      isTrue,
    );
    expect(
      isPermanentServerRejection(
        PostgrestException(message: 'duplicate', code: '23505'),
      ),
      isTrue,
    );
    // An expired session or a dropped connection can succeed later, so those
    // operations must stay queued.
    expect(
      isPermanentServerRejection(
        PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      ),
      isFalse,
    );
    expect(isPermanentServerRejection(Exception('connection reset')), isFalse);
  });

  test(
    'corrupt cached JSON is discarded instead of crashing offline reads',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_cache_members_church-1': '{incomplete-json',
      });

      final cache = OfflineCache(memberStore: MemberMemoryStore());
      expect(await cache.readMembers('church-1'), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offline_cache_members_church-1'), isFalse);
    },
  );

  test(
    'legacy SharedPreferences members migrate into the local store',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_cache_members_church-1': jsonEncode([
          memberToJson(
            const MemberEntity(
              id: 'mem-1',
              churchId: 'church-1',
              fullName: 'مريم جرجس',
              scope: MemberScope.sundaySchoolClass,
              sundaySchoolClassId: 'cls-1',
              phone: '0122',
              isActive: true,
            ),
          ),
        ]),
      });

      final store = MemberMemoryStore();
      final cache = OfflineCache(memberStore: store);

      final members = await cache.readMembers('church-1');
      expect(members, hasLength(1));
      expect(members!.single.fullName, 'مريم جرجس');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offline_cache_members_church-1'), isFalse);

      final page = await cache.queryMembersPage(
        churchId: 'church-1',
        page: 0,
        pageSize: 50,
        query: 'مريم',
      );
      expect(page.items, hasLength(1));
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'structure merge keeps offline meetings and classes across online refresh',
    () async {
      final cache = OfflineCache(memberStore: MemberMemoryStore());
      await cache.upsertMeeting(
        'church-1',
        const MeetingEntity(
          id: 'offline_meeting_1',
          churchId: 'church-1',
          name: 'Local',
          nameAr: 'محلي',
          kind: MeetingKind.normal,
          weekday: 5,
          isActive: true,
        ),
      );
      await cache.upsertClass(
        'church-1',
        const SundaySchoolClassEntity(
          id: 'offline_class_1',
          churchId: 'church-1',
          meetingId: 'offline_meeting_1',
          name: 'Class',
          nameAr: 'فصل',
          displayOrder: 0,
          isActive: true,
        ),
      );

      final meetings = await cache.mergeAndSaveMeetings('church-1', [
        const MeetingEntity(
          id: 'server-meeting',
          churchId: 'church-1',
          name: 'Server',
          nameAr: 'سيرفر',
          kind: MeetingKind.normal,
          weekday: 5,
          isActive: true,
        ),
      ]);
      expect(meetings.map((m) => m.id), containsAll(['offline_meeting_1', 'server-meeting']));

      final classes = await cache.mergeAndSaveClassesForMeeting(
        churchId: 'church-1',
        meetingId: 'offline_meeting_1',
        remoteForMeeting: const [],
      );
      expect(classes.map((c) => c.id), ['offline_class_1']);

      await cache.upsertClass(
        'church-1',
        const SundaySchoolClassEntity(
          id: 'other-class',
          churchId: 'church-1',
          meetingId: 'other-meeting',
          name: 'Other',
          nameAr: 'آخر',
          displayOrder: 0,
          isActive: true,
        ),
      );
      await cache.mergeAndSaveClassesForMeeting(
        churchId: 'church-1',
        meetingId: 'server-meeting',
        remoteForMeeting: [
          const SundaySchoolClassEntity(
            id: 'server-class',
            churchId: 'church-1',
            meetingId: 'server-meeting',
            name: 'Srv',
            nameAr: 'فصل سيرفر',
            displayOrder: 0,
            isActive: true,
          ),
        ],
      );
      final allClasses = await cache.readClasses('church-1');
      expect(
        allClasses!.map((c) => c.id),
        containsAll(['offline_class_1', 'other-class', 'server-class']),
      );
    },
  );

  test('cascade remove meeting clears dependents and queue refs', () async {
    final cache = OfflineCache(memberStore: MemberMemoryStore());
    final queue = OfflineWriteQueue();

    await cache.upsertMeeting(
      'church-1',
      const MeetingEntity(
        id: 'offline_meeting_1',
        churchId: 'church-1',
        name: 'Local',
        nameAr: 'محلي',
        kind: MeetingKind.normal,
        weekday: 5,
        isActive: true,
      ),
    );
    await cache.upsertClass(
      'church-1',
      const SundaySchoolClassEntity(
        id: 'offline_class_1',
        churchId: 'church-1',
        meetingId: 'offline_meeting_1',
        name: 'Class',
        nameAr: 'فصل',
        displayOrder: 0,
        isActive: true,
      ),
    );
    await cache.upsertMember(
      'church-1',
      const MemberEntity(
        id: 'offline_member_1',
        churchId: 'church-1',
        fullName: 'مخدوم',
        scope: MemberScope.sundaySchoolClass,
        sundaySchoolClassId: 'offline_class_1',
        isActive: true,
      ),
    );
    await cache.upsertSession(
      'offline_meeting_1',
      'offline_class_1',
      AttendanceSessionEntity(
        id: 'offline_session_1',
        churchId: 'church-1',
        meetingId: 'offline_meeting_1',
        classId: 'offline_class_1',
        sessionDate: DateTime(2026, 10, 3),
        weekNumber: 1,
      ),
    );
    await queue.enqueue(
      QueuedOperation(
        id: 'op-class',
        type: OfflineOpType.classCreate,
        payload: {
          'local_id': 'offline_class_1',
          'meeting_id': 'offline_meeting_1',
        },
        queuedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final removed = await cache.cascadeRemoveMeeting(
      'church-1',
      'offline_meeting_1',
    );
    await queue.removeOperationsTouching(removed);

    expect(await cache.readMeetings('church-1'), isEmpty);
    expect(await cache.readClasses('church-1'), isEmpty);
    expect(await cache.readMembers('church-1'), isEmpty);
    expect(
      await cache.readSessions('offline_meeting_1', 'offline_class_1'),
      isNull,
    );
    expect(await queue.all(), isEmpty);
  });

  test('assignment cache remaps class id after sync', () async {
    final cache = OfflineCache(memberStore: MemberMemoryStore());
    await cache.saveClassAssignmentsForClass('offline_class_1', [
      {
        'id': 'assign-1',
        'user_id': 'user-1',
        'can_take_attendance': true,
        'can_view_reports': true,
      },
    ]);
    await cache.saveClassAssignments('user-1', [
      {
        'id': 'assign-1',
        'class_id': 'offline_class_1',
        'can_take_attendance': true,
        'can_view_reports': true,
      },
    ]);

    await cache.remapAssignmentParentIds(
      oldClassId: 'offline_class_1',
      newClassId: 'server-class',
    );

    expect(await cache.readClassAssignmentsForClass('offline_class_1'), isNull);
    expect(
      await cache.readClassAssignmentsForClass('server-class'),
      isNotEmpty,
    );
    final byUser = await cache.readClassAssignments('user-1');
    expect(byUser!.single['class_id'], 'server-class');
  });

  test('session scope rename follows meeting id remap', () async {
    final cache = OfflineCache(memberStore: MemberMemoryStore());
    await cache.upsertSession(
      'offline_meeting_1',
      null,
      AttendanceSessionEntity(
        id: 'offline_session_1',
        churchId: 'church-1',
        meetingId: 'offline_meeting_1',
        classId: null,
        sessionDate: DateTime(2026, 10, 3),
        weekNumber: 1,
      ),
    );

    await cache.renameSessionsScope(
      oldMeetingId: 'offline_meeting_1',
      newMeetingId: 'server-meeting',
    );

    expect(
      await cache.readSessions('offline_meeting_1', null),
      isNull,
    );
    final renamed = await cache.readSessions('server-meeting', null);
    expect(renamed, hasLength(1));
    expect(renamed!.single.id, 'offline_session_1');
    expect(renamed.single.meetingId, 'server-meeting');
  });

  test('removeByEntityId keeps child ops that only reference the parent', () async {
    final queue = OfflineWriteQueue();
    await queue.enqueue(
      QueuedOperation(
        id: 'op-meeting',
        type: OfflineOpType.meetingCreate,
        payload: {'local_id': 'offline_meeting_1'},
        queuedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await queue.enqueue(
      QueuedOperation(
        id: 'op-class',
        type: OfflineOpType.classCreate,
        payload: {
          'local_id': 'offline_class_1',
          'meeting_id': 'offline_meeting_1',
        },
        queuedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await queue.removeByEntityId('offline_meeting_1');
    final remaining = await queue.all();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 'op-class');
  });

  test(
    'roster merge keeps offline-created members missing from the server',
    () {
      const remote = MemberEntity(
        id: 'server-1',
        churchId: 'church-1',
        fullName: 'من السيرفر',
        scope: MemberScope.sundaySchoolClass,
        sundaySchoolClassId: 'cls-1',
        isActive: true,
      );
      const pending = MemberEntity(
        id: 'offline_member_1',
        churchId: 'church-1',
        fullName: 'مسجّل أوفلاين',
        scope: MemberScope.sundaySchoolClass,
        sundaySchoolClassId: 'cls-1',
        isActive: true,
      );
      const syncedLocal = MemberEntity(
        id: 'server-1',
        churchId: 'church-1',
        fullName: 'من السيرفر',
        scope: MemberScope.sundaySchoolClass,
        sundaySchoolClassId: 'cls-1',
        isActive: true,
      );

      final merged = mergeRosterWithPendingOfflineMembers(
        remote: const [remote],
        local: const [pending, syncedLocal],
      );

      expect(merged.map((m) => m.id), ['offline_member_1', 'server-1']);
      expect(
        mergeRosterWithPendingOfflineMembers(
          remote: const [remote],
          local: const [pending],
          pendingDeletes: {'offline_member_1'},
        ),
        [remote],
      );
    },
  );

  test(
    'offline sync order creates members before sessions',
    () {
      final memberIndex = OfflineOpType.syncOrder.indexOf(
        OfflineOpType.memberCreate,
      );
      final sessionIndex = OfflineOpType.syncOrder.indexOf(
        OfflineOpType.sessionCreate,
      );
      expect(memberIndex, greaterThanOrEqualTo(0));
      expect(sessionIndex, greaterThan(memberIndex));
    },
  );

  test(
    'member store pages and filters without loading the whole church',
    () async {
      final store = MemberMemoryStore();
      final members = [
        for (var index = 0; index < 120; index++)
          MemberEntity(
            id: 'mem-$index',
            churchId: 'church-1',
            fullName: 'عضو ${index.toString().padLeft(3, '0')}',
            scope: index.isEven
                ? MemberScope.sundaySchoolClass
                : MemberScope.meeting,
            sundaySchoolClassId: index.isEven ? 'cls-1' : null,
            meetingId: index.isEven ? null : 'mtg-1',
            meetingIds: index.isEven ? const [] : const ['mtg-1'],
            phone: '010${index.toString().padLeft(8, '0')}',
            isActive: true,
          ),
      ];
      await store.upsertMany('church-1', members);

      final first = await store.queryPage(
        churchId: 'church-1',
        page: 0,
        pageSize: 50,
      );
      expect(first.items, hasLength(50));
      expect(first.hasMore, isTrue);

      final second = await store.queryPage(
        churchId: 'church-1',
        page: 1,
        pageSize: 50,
      );
      expect(second.items, hasLength(50));
      expect(second.items.first.id, isNot(first.items.first.id));

      final searched = await store.queryPage(
        churchId: 'church-1',
        page: 0,
        pageSize: 50,
        query: '01000000010',
      );
      expect(searched.items, hasLength(1));
      expect(searched.items.single.id, 'mem-10');

      final counts = await store.counts(churchId: 'church-1');
      expect(counts.total, 120);
      expect(counts.sundaySchool, 60);
      expect(counts.meetings, 60);
    },
  );
}
