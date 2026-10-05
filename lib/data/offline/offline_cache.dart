import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/data/app_models.dart';
import 'member_import_history.dart';
import 'member_local_store.dart';
import 'member_store_factory.dart';
import 'offline_entity_json.dart';

/// Persists Supabase row JSON locally for offline reads.
class OfflineCache {
  static MemberLocalStore? _sharedMemberStore;

  static MemberLocalStore get _defaultMemberStore =>
      _sharedMemberStore ??= createMemberLocalStore();

  final MemberLocalStore? _injectedMemberStore;

  MemberLocalStore get _memberStore =>
      _injectedMemberStore ?? _defaultMemberStore;

  OfflineCache({MemberLocalStore? memberStore})
    : _injectedMemberStore = memberStore;
  static const _profileKey = 'offline_cache_profile';
  static const _churchPrefix = 'offline_cache_church_';
  static const _meetingsPrefix = 'offline_cache_meetings_';
  static const _classesPrefix = 'offline_cache_classes_';
  static const _membersPrefix = 'offline_cache_members_';
  static const _sessionsPrefix = 'offline_cache_sessions_';
  static const _followUpsPrefix = 'offline_cache_followups_';
  static const _reportStatsPrefix = 'offline_cache_report_stats_';
  static const _classAssignmentsPrefix = 'offline_cache_class_assignments_';
  static const _meetingAssignmentsPrefix = 'offline_cache_meeting_assignments_';
  static const _classAssignmentsByClassPrefix =
      'offline_cache_class_assignments_class_';
  static const _meetingAssignmentsByMeetingPrefix =
      'offline_cache_meeting_assignments_meeting_';
  static const _profilesPrefix = 'offline_cache_profiles_';
  static const _invitationsPrefix = 'offline_cache_invitations_';

  /// Attendance status caches, keyed by session id. Written by the attendance
  /// repository and the offline sync paths rather than by this cache, so the key
  /// names live here and those writers reference them.
  static const attendanceRecordsPrefix = 'offline_attendance_records_';

  /// Sessions that still hold attendance records waiting to be synced.
  static const unsyncedSessionsKey = 'offline_unsynced_sessions';

  Future<void> saveProfile(Map<String, dynamic> row) async {
    await _write(_profileKey, row);
  }

  Future<AppProfile?> readProfile() async {
    final row = await _readMap(_profileKey);
    if (row == null) return null;
    return AppProfile.fromJson(row);
  }

  Future<void> saveChurch(String churchId, Map<String, dynamic> row) async {
    await _write('$_churchPrefix$churchId', row);
  }

  Future<Church?> readChurch(String churchId) async {
    final row = await _readMap('$_churchPrefix$churchId');
    if (row == null) return null;
    return Church.fromJson(row);
  }

  Future<void> saveMeetings(String churchId, List<dynamic> rows) async {
    await _writeList('$_meetingsPrefix$churchId', rows);
  }

  Future<List<MeetingEntity>?> readMeetings(String churchId) async {
    return _readEntities('$_meetingsPrefix$churchId', MeetingEntity.fromJson);
  }

  /// Persists a server meeting list without dropping unsynced `offline_*` rows.
  Future<List<MeetingEntity>> mergeAndSaveMeetings(
    String churchId,
    List<MeetingEntity> remote, {
    Set<String> pendingDeletes = const {},
  }) async {
    final local = await readMeetings(churchId) ?? [];
    final merged = mergeRemoteWithPendingOffline(
      remote: remote,
      local: local,
      idOf: (item) => item.id,
      pendingDeletes: pendingDeletes,
      compare: (a, b) {
        final kind = a.kind.value.compareTo(b.kind.value);
        if (kind != 0) return kind;
        return a.nameAr.compareTo(b.nameAr);
      },
    );
    await saveMeetings(churchId, merged.map(meetingToJson).toList());
    return merged;
  }

  Future<void> saveClasses(String churchId, List<dynamic> rows) async {
    await _writeList('$_classesPrefix$churchId', rows);
  }

  Future<List<SundaySchoolClassEntity>?> readClasses(String churchId) async {
    return _readEntities(
      '$_classesPrefix$churchId',
      SundaySchoolClassEntity.fromJson,
    );
  }

  /// Persists a full church class list without dropping unsynced `offline_*` rows.
  Future<List<SundaySchoolClassEntity>> mergeAndSaveClasses(
    String churchId,
    List<SundaySchoolClassEntity> remote, {
    Set<String> pendingDeletes = const {},
  }) async {
    final local = await readClasses(churchId) ?? [];
    final merged = mergeRemoteWithPendingOffline(
      remote: remote,
      local: local,
      idOf: (item) => item.id,
      pendingDeletes: pendingDeletes,
      compare: (a, b) => a.displayOrder.compareTo(b.displayOrder),
    );
    await saveClasses(churchId, merged.map(classToJson).toList());
    return merged;
  }

  /// Updates one meeting's classes in cache without wiping other meetings.
  Future<List<SundaySchoolClassEntity>> mergeAndSaveClassesForMeeting({
    required String churchId,
    required String meetingId,
    required List<SundaySchoolClassEntity> remoteForMeeting,
    Set<String> pendingDeletes = const {},
  }) async {
    final local = await readClasses(churchId) ?? [];
    final others = local.where((item) => item.meetingId != meetingId).toList();
    final localForMeeting = local
        .where((item) => item.meetingId == meetingId)
        .toList();
    final forMeeting = mergeRemoteWithPendingOffline(
      remote: remoteForMeeting,
      local: localForMeeting,
      idOf: (item) => item.id,
      pendingDeletes: pendingDeletes,
      compare: (a, b) => a.displayOrder.compareTo(b.displayOrder),
    );
    await saveClasses(
      churchId,
      [...others, ...forMeeting].map(classToJson).toList(),
    );
    return forMeeting;
  }

  Future<void> saveMembers(String churchId, List<dynamic> rows) async {
    await _ensureLegacyMembersMigrated(churchId);
    await _memberStore.upsertMany(
      churchId,
      rows.map(
        (row) => MemberEntity.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
  }

  Future<List<MemberEntity>?> readMembers(String churchId) async {
    await _ensureLegacyMembersMigrated(churchId);
    final members = await _memberStore.readAll(churchId);
    return members;
  }

  Future<List<MemberEntity>> readMembersByIds(
    String churchId,
    Iterable<String> ids,
  ) async {
    await _ensureLegacyMembersMigrated(churchId);
    return _memberStore.readByIds(churchId, ids);
  }

  Future<MemberEntity?> readMemberById(String churchId, String id) async {
    await _ensureLegacyMembersMigrated(churchId);
    return _memberStore.readById(churchId, id);
  }

  Future<MemberQueryPage> queryMembersPage({
    required String churchId,
    required int page,
    required int pageSize,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
  }) async {
    await _ensureLegacyMembersMigrated(churchId);
    return _memberStore.queryPage(
      churchId: churchId,
      page: page,
      pageSize: pageSize,
      query: query,
      meetingId: meetingId,
      classId: classId,
      scope: scope,
      activeOnly: activeOnly,
    );
  }

  Future<List<MemberEntity>> queryMembersAll({
    required String churchId,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
  }) async {
    await _ensureLegacyMembersMigrated(churchId);
    return _memberStore.queryAll(
      churchId: churchId,
      query: query,
      meetingId: meetingId,
      classId: classId,
      scope: scope,
      activeOnly: activeOnly,
    );
  }

  Future<MembersListCounts> readMemberCounts({
    required String churchId,
    bool activeOnly = true,
  }) async {
    await _ensureLegacyMembersMigrated(churchId);
    return _memberStore.counts(churchId: churchId, activeOnly: activeOnly);
  }

  Future<void> _ensureLegacyMembersMigrated(String churchId) async {
    await _migrateLegacyMembersBlob(churchId);
    await restorePendingMembers(churchId, _memberStore);
  }

  Future<void> _migrateLegacyMembersBlob(String churchId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_membersPrefix$churchId';
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.remove(key);
        return;
      }
      await _memberStore.upsertMany(
        churchId,
        decoded.map(
          (row) => MemberEntity.fromJson(Map<String, dynamic>.from(row as Map)),
        ),
      );
      // Remove the old blob only after every row has reached the store.
      await prefs.remove(key);
    } on FormatException {
      await prefs.remove(key);
    } on TypeError {
      await prefs.remove(key);
    }
  }

  String sessionsKey(String meetingId, String? classId) {
    return '$_sessionsPrefix${meetingId}_${classId ?? 'none'}';
  }

  Future<void> saveSessions(
    String meetingId,
    String? classId,
    List<dynamic> rows,
  ) async {
    await _writeList(sessionsKey(meetingId, classId), rows);
  }

  Future<List<AttendanceSessionEntity>?> readSessions(
    String meetingId,
    String? classId,
  ) async {
    return _readEntities(
      sessionsKey(meetingId, classId),
      AttendanceSessionEntity.fromJson,
    );
  }

  /// Persists a session scope without dropping unsynced `offline_*` sessions.
  Future<List<AttendanceSessionEntity>> mergeAndSaveSessions(
    String meetingId,
    String? classId,
    List<AttendanceSessionEntity> remote, {
    Set<String> pendingDeletes = const {},
  }) async {
    final local = await readSessions(meetingId, classId) ?? [];
    final merged = mergeRemoteWithPendingOffline(
      remote: remote,
      local: local,
      idOf: (item) => item.id,
      pendingDeletes: pendingDeletes,
      compare: (a, b) => b.sessionDate.compareTo(a.sessionDate),
    );
    await saveSessions(
      meetingId,
      classId,
      merged.map(sessionToJson).toList(),
    );
    return merged;
  }

  /// Moves session cache rows when a parent meeting/class id is remapped.
  Future<void> renameSessionsScope({
    required String oldMeetingId,
    required String newMeetingId,
    String? oldClassId,
    String? newClassId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (oldClassId != null || newClassId != null) {
      await _moveSessionsKey(
        prefs,
        sessionsKey(oldMeetingId, oldClassId),
        sessionsKey(newMeetingId, newClassId),
      );
      return;
    }

    final oldPrefix = '$_sessionsPrefix${oldMeetingId}_';
    final keys = prefs.getKeys().where((key) => key.startsWith(oldPrefix));
    for (final oldKey in keys.toList()) {
      final suffix = oldKey.substring(oldPrefix.length);
      final newKey = '$_sessionsPrefix${newMeetingId}_$suffix';
      await _moveSessionsKey(prefs, oldKey, newKey);
    }
  }

  Future<void> _moveSessionsKey(
    SharedPreferences prefs,
    String oldKey,
    String newKey,
  ) async {
    if (oldKey == newKey) return;
    final raw = prefs.getString(oldKey);
    if (raw == null) return;

    final newMeetingId = _meetingIdFromSessionsKey(newKey);
    final newClassId = _classIdFromSessionsKey(newKey);

    List<Map<String, dynamic>> rewrite(List<Map<String, dynamic>> rows) {
      return [
        for (final row in rows)
          {
            ...row,
            if (newMeetingId != null) 'meeting_id': newMeetingId,
            'class_id': newClassId,
          },
      ];
    }

    final existing = prefs.getString(newKey);
    if (existing == null) {
      try {
        final rows = (jsonDecode(raw) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        await prefs.setString(newKey, jsonEncode(rewrite(rows)));
      } on FormatException {
        await prefs.setString(newKey, raw);
      } on TypeError {
        await prefs.setString(newKey, raw);
      }
    } else {
      try {
        final oldRows = rewrite(
          (jsonDecode(raw) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
        );
        final newRows = rewrite(
          (jsonDecode(existing) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
        );
        final byId = <String, Map<String, dynamic>>{
          for (final row in newRows) row['id'] as String: row,
        };
        for (final row in oldRows) {
          byId.putIfAbsent(row['id'] as String, () => row);
        }
        await prefs.setString(newKey, jsonEncode(byId.values.toList()));
      } on FormatException {
        await prefs.setString(newKey, raw);
      } on TypeError {
        await prefs.setString(newKey, raw);
      }
    }
    await prefs.remove(oldKey);
  }

  String? _meetingIdFromSessionsKey(String key) {
    if (!key.startsWith(_sessionsPrefix)) return null;
    final rest = key.substring(_sessionsPrefix.length);
    final split = rest.lastIndexOf('_');
    if (split <= 0) return null;
    return rest.substring(0, split);
  }

  String? _classIdFromSessionsKey(String key) {
    if (!key.startsWith(_sessionsPrefix)) return null;
    final rest = key.substring(_sessionsPrefix.length);
    final split = rest.lastIndexOf('_');
    if (split < 0 || split + 1 >= rest.length) return null;
    final classPart = rest.substring(split + 1);
    return classPart == 'none' ? null : classPart;
  }

  /// Rewrites class.meetingId after an offline meeting syncs to a server id.
  Future<void> remapClassMeetingIds({
    required String churchId,
    required String oldMeetingId,
    required String newMeetingId,
  }) async {
    if (oldMeetingId == newMeetingId) return;
    final classes = await readClasses(churchId) ?? [];
    var changed = false;
    final updated = classes.map((cls) {
      if (cls.meetingId != oldMeetingId) return cls;
      changed = true;
      return SundaySchoolClassEntity(
        id: cls.id,
        churchId: cls.churchId,
        meetingId: newMeetingId,
        name: cls.name,
        nameAr: cls.nameAr,
        displayOrder: cls.displayOrder,
        isActive: cls.isActive,
      );
    }).toList();
    if (changed) {
      await saveClasses(churchId, updated.map(classToJson).toList());
    }
    await renameSessionsScope(
      oldMeetingId: oldMeetingId,
      newMeetingId: newMeetingId,
    );
  }

  /// Rewrites member FKs after an offline meeting/class syncs to a server id.
  Future<void> remapMemberParentIds({
    required String churchId,
    String? oldMeetingId,
    String? newMeetingId,
    String? oldClassId,
    String? newClassId,
  }) async {
    await _ensureLegacyMembersMigrated(churchId);
    final members = await _memberStore.readAll(churchId);
    for (final member in members) {
      var next = member;
      var changed = false;

      if (oldClassId != null &&
          newClassId != null &&
          member.sundaySchoolClassId == oldClassId) {
        next = next.copyWith(sundaySchoolClassId: newClassId);
        changed = true;
      }

      if (oldMeetingId != null && newMeetingId != null) {
        final meetingIds = [
          for (final id in member.meetingIds)
            id == oldMeetingId ? newMeetingId : id,
        ];
        final meetingChanged =
            member.meetingId == oldMeetingId ||
            !_sameStringList(meetingIds, member.meetingIds);
        if (meetingChanged) {
          next = next.copyWith(
            meetingId: member.meetingId == oldMeetingId
                ? newMeetingId
                : member.meetingId,
            meetingIds: meetingIds,
          );
          changed = true;
        }
      }

      if (changed) {
        await _memberStore.upsert(churchId, next);
      }
    }

    if (oldClassId != null &&
        newClassId != null &&
        oldMeetingId != null &&
        newMeetingId != null) {
      await renameSessionsScope(
        oldMeetingId: oldMeetingId,
        newMeetingId: newMeetingId,
        oldClassId: oldClassId,
        newClassId: newClassId,
      );
    } else if (oldClassId != null &&
        newClassId != null &&
        oldMeetingId == null) {
      // Class remap alone: rewrite every sessions key ending with the old class.
      final prefs = await SharedPreferences.getInstance();
      final suffix = '_$oldClassId';
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith(_sessionsPrefix) || !key.endsWith(suffix)) {
          continue;
        }
        final meetingPart = key.substring(
          _sessionsPrefix.length,
          key.length - suffix.length,
        );
        await _moveSessionsKey(
          prefs,
          key,
          sessionsKey(meetingPart, newClassId),
        );
      }
    }
  }

  /// Rewrites cached servant assignments when a meeting/class id is remapped.
  Future<void> remapAssignmentParentIds({
    String? oldClassId,
    String? newClassId,
    String? oldMeetingId,
    String? newMeetingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (oldClassId != null &&
        newClassId != null &&
        oldClassId != newClassId) {
      await _moveListKey(
        prefs,
        '$_classAssignmentsByClassPrefix$oldClassId',
        '$_classAssignmentsByClassPrefix$newClassId',
      );
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith(_classAssignmentsPrefix) ||
            key.startsWith(_classAssignmentsByClassPrefix)) {
          continue;
        }
        await _rewriteAssignmentField(
          prefs,
          key,
          field: 'class_id',
          oldValue: oldClassId,
          newValue: newClassId,
        );
      }
    }

    if (oldMeetingId != null &&
        newMeetingId != null &&
        oldMeetingId != newMeetingId) {
      await _moveListKey(
        prefs,
        '$_meetingAssignmentsByMeetingPrefix$oldMeetingId',
        '$_meetingAssignmentsByMeetingPrefix$newMeetingId',
      );
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith(_meetingAssignmentsPrefix) ||
            key.startsWith(_meetingAssignmentsByMeetingPrefix)) {
          continue;
        }
        await _rewriteAssignmentField(
          prefs,
          key,
          field: 'meeting_id',
          oldValue: oldMeetingId,
          newValue: newMeetingId,
        );
      }
    }
  }

  Future<void> remapInvitationTargetIds({
    required String churchId,
    required String oldTargetId,
    required String newTargetId,
  }) async {
    if (oldTargetId == newTargetId) return;
    final invitations = await readInvitations(churchId) ?? [];
    var changed = false;
    final updated = invitations.map((invite) {
      if (invite.targetId != oldTargetId) return invite;
      changed = true;
      return invite.copyWith(targetId: newTargetId);
    }).toList();
    if (changed) {
      await saveInvitations(
        churchId,
        updated.map(invitationToJson).toList(),
      );
    }
  }

  /// Removes an unsynced class and every local dependent (members, sessions,
  /// attendance, assignments, invitations). Returns removed entity ids.
  Future<Set<String>> cascadeRemoveClass(
    String churchId,
    String classId,
  ) async {
    final removed = <String>{classId};
    final members = await queryMembersAll(
      churchId: churchId,
      classId: classId,
      activeOnly: false,
    );
    for (final member in members) {
      await removeMember(churchId, member.id);
      removed.add(member.id);
      await _removeFollowUpsForMember(churchId, member.id);
    }

    final prefs = await SharedPreferences.getInstance();
    final suffix = '_$classId';
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_sessionsPrefix) || !key.endsWith(suffix)) continue;
      final sessions = await _readEntities(
        key,
        AttendanceSessionEntity.fromJson,
      );
      for (final session in sessions ?? const <AttendanceSessionEntity>[]) {
        await _clearAttendanceForSession(session.id);
        removed.add(session.id);
      }
      await prefs.remove(key);
    }

    await prefs.remove('$_classAssignmentsByClassPrefix$classId');
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_classAssignmentsPrefix) ||
          key.startsWith(_classAssignmentsByClassPrefix)) {
        continue;
      }
      await _removeAssignmentRows(
        prefs,
        key,
        field: 'class_id',
        value: classId,
      );
    }

    await _removeInvitationsForTarget(churchId, classId);
    await removeClass(churchId, classId);
    return removed;
  }

  /// Removes an unsynced meeting and every local dependent.
  Future<Set<String>> cascadeRemoveMeeting(
    String churchId,
    String meetingId,
  ) async {
    final removed = <String>{meetingId};
    final classes = (await readClasses(churchId) ?? [])
        .where((item) => item.meetingId == meetingId)
        .toList();
    for (final cls in classes) {
      removed.addAll(await cascadeRemoveClass(churchId, cls.id));
    }

    final members = await queryMembersAll(
      churchId: churchId,
      meetingId: meetingId,
      activeOnly: false,
    );
    for (final member in members) {
      await removeMember(churchId, member.id);
      removed.add(member.id);
      await _removeFollowUpsForMember(churchId, member.id);
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_sessionsPrefix${meetingId}_';
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(prefix)) continue;
      final sessions = await _readEntities(
        key,
        AttendanceSessionEntity.fromJson,
      );
      for (final session in sessions ?? const <AttendanceSessionEntity>[]) {
        await _clearAttendanceForSession(session.id);
        removed.add(session.id);
      }
      await prefs.remove(key);
    }

    await prefs.remove('$_meetingAssignmentsByMeetingPrefix$meetingId');
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_meetingAssignmentsPrefix) ||
          key.startsWith(_meetingAssignmentsByMeetingPrefix)) {
        continue;
      }
      await _removeAssignmentRows(
        prefs,
        key,
        field: 'meeting_id',
        value: meetingId,
      );
    }

    await _removeInvitationsForTarget(churchId, meetingId);
    await removeMeeting(churchId, meetingId);
    return removed;
  }

  Future<void> _clearAttendanceForSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$attendanceRecordsPrefix$sessionId');
    final unsynced = prefs.getStringList(unsyncedSessionsKey) ?? [];
    if (unsynced.remove(sessionId)) {
      await prefs.setStringList(unsyncedSessionsKey, unsynced);
    }
  }

  Future<void> _removeFollowUpsForMember(
    String churchId,
    String memberId,
  ) async {
    final followUps = await readFollowUps(churchId) ?? [];
    final remaining = followUps
        .where((item) => item.memberId != memberId)
        .toList();
    if (remaining.length != followUps.length) {
      await saveFollowUps(
        churchId,
        remaining.map(followUpToJson).toList(),
      );
    }
  }

  Future<void> _removeInvitationsForTarget(
    String churchId,
    String targetId,
  ) async {
    final invitations = await readInvitations(churchId) ?? [];
    final remaining = invitations
        .where((item) => item.targetId != targetId)
        .toList();
    if (remaining.length != invitations.length) {
      await saveInvitations(
        churchId,
        remaining.map(invitationToJson).toList(),
      );
    }
  }

  Future<void> _moveListKey(
    SharedPreferences prefs,
    String oldKey,
    String newKey,
  ) async {
    if (oldKey == newKey) return;
    final raw = prefs.getString(oldKey);
    if (raw == null) return;
    final existing = prefs.getString(newKey);
    if (existing == null) {
      await prefs.setString(newKey, raw);
    } else {
      try {
        final oldRows = (jsonDecode(raw) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final newRows = (jsonDecode(existing) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final byId = <String, Map<String, dynamic>>{
          for (final row in newRows) '${row['id']}': row,
        };
        for (final row in oldRows) {
          byId.putIfAbsent('${row['id']}', () => row);
        }
        await prefs.setString(newKey, jsonEncode(byId.values.toList()));
      } on FormatException {
        await prefs.setString(newKey, raw);
      } on TypeError {
        await prefs.setString(newKey, raw);
      }
    }
    await prefs.remove(oldKey);
  }

  Future<void> _rewriteAssignmentField(
    SharedPreferences prefs,
    String key, {
    required String field,
    required String oldValue,
    required String newValue,
  }) async {
    final rows = await _readList(key);
    if (rows == null) return;
    var changed = false;
    for (var i = 0; i < rows.length; i++) {
      final row = Map<String, dynamic>.from(rows[i] as Map);
      if (row[field]?.toString() == oldValue) {
        row[field] = newValue;
        rows[i] = row;
        changed = true;
      }
    }
    if (changed) await _writeList(key, rows);
  }

  Future<void> _removeAssignmentRows(
    SharedPreferences prefs,
    String key, {
    required String field,
    required String value,
  }) async {
    final rows = await _readList(key);
    if (rows == null) return;
    final before = rows.length;
    rows.removeWhere(
      (row) => (row as Map)[field]?.toString() == value,
    );
    if (rows.length != before) await _writeList(key, rows);
  }

  Future<void> saveFollowUps(String churchId, List<dynamic> rows) async {
    await _writeList('$_followUpsPrefix$churchId', rows);
  }

  Future<List<FollowUpEntity>?> readFollowUps(String churchId) async {
    return _readEntities('$_followUpsPrefix$churchId', FollowUpEntity.fromJson);
  }

  Future<void> upsertMeeting(String churchId, MeetingEntity meeting) async {
    final meetings = await readMeetings(churchId) ?? [];
    final index = meetings.indexWhere((item) => item.id == meeting.id);
    if (index >= 0) {
      meetings[index] = meeting;
    } else {
      meetings.add(meeting);
    }
    await saveMeetings(churchId, meetings.map(meetingToJson).toList());
  }

  Future<void> removeMeeting(String churchId, String meetingId) async {
    final meetings = await readMeetings(churchId) ?? [];
    meetings.removeWhere((item) => item.id == meetingId);
    await saveMeetings(churchId, meetings.map(meetingToJson).toList());
  }

  Future<void> upsertClass(String churchId, SundaySchoolClassEntity cls) async {
    final classes = await readClasses(churchId) ?? [];
    final index = classes.indexWhere((item) => item.id == cls.id);
    if (index >= 0) {
      classes[index] = cls;
    } else {
      classes.add(cls);
    }
    await saveClasses(churchId, classes.map(classToJson).toList());
  }

  Future<void> removeClass(String churchId, String classId) async {
    final classes = await readClasses(churchId) ?? [];
    classes.removeWhere((item) => item.id == classId);
    await saveClasses(churchId, classes.map(classToJson).toList());
  }

  Future<void> upsertMember(String churchId, MemberEntity member) async {
    await _ensureLegacyMembersMigrated(churchId);
    await _memberStore.upsert(churchId, member);
  }

  Future<void> removeMember(String churchId, String memberId) async {
    await _ensureLegacyMembersMigrated(churchId);
    await _memberStore.deleteMember(churchId, memberId);
  }

  Future<void> upsertSession(
    String meetingId,
    String? classId,
    AttendanceSessionEntity session,
  ) async {
    final sessions = await readSessions(meetingId, classId) ?? [];
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.insert(0, session);
    }
    await saveSessions(
      meetingId,
      classId,
      sessions.map(sessionToJson).toList(),
    );
  }

  Future<void> removeSession(
    String meetingId,
    String? classId,
    String sessionId,
  ) async {
    final sessions = await readSessions(meetingId, classId) ?? [];
    sessions.removeWhere((item) => item.id == sessionId);
    await saveSessions(
      meetingId,
      classId,
      sessions.map(sessionToJson).toList(),
    );
  }

  Future<void> upsertFollowUp(String churchId, FollowUpEntity followUp) async {
    final followUps = await readFollowUps(churchId) ?? [];
    final index = followUps.indexWhere((item) => item.id == followUp.id);
    if (index >= 0) {
      followUps[index] = followUp;
    } else {
      followUps.insert(0, followUp);
    }
    await saveFollowUps(churchId, followUps.map(followUpToJson).toList());
  }

  Future<void> removeFollowUp(String churchId, String followUpId) async {
    final followUps = await readFollowUps(churchId) ?? [];
    followUps.removeWhere((item) => item.id == followUpId);
    await saveFollowUps(churchId, followUps.map(followUpToJson).toList());
  }

  Future<void> saveReportStats(String churchId, List<dynamic> rows) async {
    await _writeList('$_reportStatsPrefix$churchId', rows);
  }

  Future<List<Map<String, dynamic>>?> readReportStats(String churchId) async {
    final rows = await _readList('$_reportStatsPrefix$churchId');
    if (rows == null) return null;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveClassAssignments(String userId, List<dynamic> rows) async {
    await _writeList('$_classAssignmentsPrefix$userId', rows);
  }

  Future<List<Map<String, dynamic>>?> readClassAssignments(
    String userId,
  ) async {
    final rows = await _readList('$_classAssignmentsPrefix$userId');
    if (rows == null) return null;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveMeetingAssignments(String userId, List<dynamic> rows) async {
    await _writeList('$_meetingAssignmentsPrefix$userId', rows);
  }

  Future<List<Map<String, dynamic>>?> readMeetingAssignments(
    String userId,
  ) async {
    final rows = await _readList('$_meetingAssignmentsPrefix$userId');
    if (rows == null) return null;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveClassAssignmentsForClass(
    String classId,
    List<dynamic> rows,
  ) async {
    await _writeList('$_classAssignmentsByClassPrefix$classId', rows);
  }

  Future<List<Map<String, dynamic>>?> readClassAssignmentsForClass(
    String classId,
  ) async {
    final rows = await _readList('$_classAssignmentsByClassPrefix$classId');
    if (rows == null) return null;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveMeetingAssignmentsForMeeting(
    String meetingId,
    List<dynamic> rows,
  ) async {
    await _writeList('$_meetingAssignmentsByMeetingPrefix$meetingId', rows);
  }

  Future<List<Map<String, dynamic>>?> readMeetingAssignmentsForMeeting(
    String meetingId,
  ) async {
    final rows = await _readList(
      '$_meetingAssignmentsByMeetingPrefix$meetingId',
    );
    if (rows == null) return null;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> saveProfiles(String churchId, List<dynamic> rows) async {
    await _writeList('$_profilesPrefix$churchId', rows);
  }

  Future<List<AppProfile>?> readProfiles(String churchId) async {
    return _readEntities('$_profilesPrefix$churchId', AppProfile.fromJson);
  }

  Future<void> upsertProfile(String churchId, AppProfile profile) async {
    final profiles = await readProfiles(churchId) ?? [];
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await saveProfiles(churchId, profiles.map(profileToJson).toList());
  }

  Future<String> upsertClassAssignment({
    required String churchId,
    required String assignmentId,
    required String classId,
    required String userId,
    required bool canTakeAttendance,
    required bool canViewReports,
  }) async {
    final profiles = await readProfiles(churchId) ?? [];
    final classes = await readClasses(churchId) ?? [];
    final profile = profiles.where((item) => item.id == userId).firstOrNull;
    final cls = classes.where((item) => item.id == classId).firstOrNull;

    final byUser = await readClassAssignments(userId) ?? [];
    final existingByUser = byUser.indexWhere(
      (item) => item['class_id'] == classId,
    );
    final resolvedId = existingByUser >= 0
        ? byUser[existingByUser]['id'] as String? ?? assignmentId
        : assignmentId;
    final userRow = <String, dynamic>{
      'id': resolvedId,
      'class_id': classId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'sunday_school_classes': {'name_ar': cls?.nameAr},
    };
    if (existingByUser >= 0) {
      byUser[existingByUser] = userRow;
    } else {
      byUser.add(userRow);
    }
    await saveClassAssignments(userId, byUser);

    final byClass = await readClassAssignmentsForClass(classId) ?? [];
    final existingByClass = byClass.indexWhere(
      (item) => item['user_id'] == userId,
    );
    final classRow = <String, dynamic>{
      'id': resolvedId,
      'user_id': userId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'profiles': {'full_name': profile?.fullName, 'email': profile?.email},
    };
    if (existingByClass >= 0) {
      byClass[existingByClass] = classRow;
    } else {
      byClass.add(classRow);
    }
    await saveClassAssignmentsForClass(classId, byClass);
    return resolvedId;
  }

  Future<String> upsertMeetingAssignment({
    required String churchId,
    required String assignmentId,
    required String meetingId,
    required String userId,
    required bool canTakeAttendance,
    required bool canViewReports,
  }) async {
    final profiles = await readProfiles(churchId) ?? [];
    final meetings = await readMeetings(churchId) ?? [];
    final profile = profiles.where((item) => item.id == userId).firstOrNull;
    final meeting = meetings.where((item) => item.id == meetingId).firstOrNull;

    final byUser = await readMeetingAssignments(userId) ?? [];
    final existingByUser = byUser.indexWhere(
      (item) => item['meeting_id'] == meetingId,
    );
    final resolvedId = existingByUser >= 0
        ? byUser[existingByUser]['id'] as String? ?? assignmentId
        : assignmentId;
    final userRow = <String, dynamic>{
      'id': resolvedId,
      'meeting_id': meetingId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'meetings': {'name_ar': meeting?.nameAr},
    };
    if (existingByUser >= 0) {
      byUser[existingByUser] = userRow;
    } else {
      byUser.add(userRow);
    }
    await saveMeetingAssignments(userId, byUser);

    final byMeeting = await readMeetingAssignmentsForMeeting(meetingId) ?? [];
    final existingByMeeting = byMeeting.indexWhere(
      (item) => item['user_id'] == userId,
    );
    final meetingRow = <String, dynamic>{
      'id': resolvedId,
      'user_id': userId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'profiles': {'full_name': profile?.fullName, 'email': profile?.email},
    };
    if (existingByMeeting >= 0) {
      byMeeting[existingByMeeting] = meetingRow;
    } else {
      byMeeting.add(meetingRow);
    }
    await saveMeetingAssignmentsForMeeting(meetingId, byMeeting);
    return resolvedId;
  }

  Future<void> removeAssignmentEverywhere(
    String assignmentId, {
    required bool isClassAssignment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefixes = isClassAssignment
        ? [_classAssignmentsPrefix, _classAssignmentsByClassPrefix]
        : [_meetingAssignmentsPrefix, _meetingAssignmentsByMeetingPrefix];
    final keys = prefs
        .getKeys()
        .where((key) => prefixes.any(key.startsWith))
        .toList();
    for (final key in keys) {
      final rows = await _readList(key);
      if (rows == null) continue;
      rows.removeWhere((row) => (row as Map)['id']?.toString() == assignmentId);
      await _writeList(key, rows);
    }
  }

  Future<void> saveInvitations(String churchId, List<dynamic> rows) async {
    await _writeList('$_invitationsPrefix$churchId', rows);
  }

  Future<List<HelperInvitation>?> readInvitations(String churchId) async {
    return _readEntities(
      '$_invitationsPrefix$churchId',
      HelperInvitation.fromJson,
    );
  }

  Future<List<HelperInvitation>> mergeAndSaveInvitations(
    String churchId,
    List<HelperInvitation> remote, {
    Set<String> pendingDeletes = const {},
  }) async {
    final local = await readInvitations(churchId) ?? [];
    final merged = mergeRemoteWithPendingOffline(
      remote: remote,
      local: local.where((item) => item.isPending).toList(),
      idOf: (item) => item.id,
      pendingDeletes: pendingDeletes,
    );
    await saveInvitations(churchId, merged.map(invitationToJson).toList());
    return merged;
  }

  Future<void> upsertInvitation(
    String churchId,
    HelperInvitation invitation,
  ) async {
    final invitations = await readInvitations(churchId) ?? [];
    final index = invitations.indexWhere((item) => item.id == invitation.id);
    if (index >= 0) {
      invitations[index] = invitation;
    } else {
      invitations.insert(0, invitation);
    }
    await saveInvitations(churchId, invitations.map(invitationToJson).toList());
  }

  Future<void> removeInvitation(String churchId, String invitationId) async {
    final invitations = await readInvitations(churchId) ?? [];
    invitations.removeWhere((item) => item.id == invitationId);
    await saveInvitations(churchId, invitations.map(invitationToJson).toList());
  }

  /// Removes every church-scoped value this device keeps, so the next account
  /// that signs in never reads the previous church's data.
  Future<void> clearAll() async {
    await _memberStore.clear();
    resetMemberStoreMigration();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key == _profileKey ||
              key == unsyncedSessionsKey ||
              key.startsWith(_churchPrefix) ||
              key.startsWith(_meetingsPrefix) ||
              key.startsWith(_classesPrefix) ||
              key.startsWith(_membersPrefix) ||
              key.startsWith(_sessionsPrefix) ||
              key.startsWith(_followUpsPrefix) ||
              key.startsWith(_reportStatsPrefix) ||
              key.startsWith(_classAssignmentsPrefix) ||
              key.startsWith(_meetingAssignmentsPrefix) ||
              key.startsWith(_classAssignmentsByClassPrefix) ||
              key.startsWith(_meetingAssignmentsByMeetingPrefix) ||
              key.startsWith(_profilesPrefix) ||
              key.startsWith(_invitationsPrefix) ||
              key.startsWith(attendanceRecordsPrefix) ||
              key.startsWith(MemberImportHistoryStore.keyPrefix),
        )
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> _write(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<void> _writeList(String key, List<dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // A partial/corrupt local value must not prevent the app from opening.
      await prefs.remove(key);
    }
    return null;
  }

  Future<List<dynamic>?> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } on FormatException {
      await prefs.remove(key);
    }
    return null;
  }

  Future<List<T>?> _readEntities<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final rows = await _readList(key);
    if (rows == null) return null;
    return rows
        .map((row) => fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
