import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:link/data/offline/offline_cache.dart';
import 'package:link/data/offline/offline_entity_json.dart';
import 'package:link/data/offline/offline_write_queue.dart';
import 'package:link/data/models/models.dart';

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
    'corrupt cached JSON is discarded instead of crashing offline reads',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_cache_members_church-1': '{incomplete-json',
      });

      final cache = OfflineCache();
      expect(await cache.readMembers('church-1'), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offline_cache_members_church-1'), isFalse);
    },
  );
}
