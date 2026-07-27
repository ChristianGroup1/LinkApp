import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/data/app_models.dart';
import 'offline_entity_json.dart';

/// Persists Supabase row JSON locally for offline reads.
class OfflineCache {
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

  Future<void> saveClasses(String churchId, List<dynamic> rows) async {
    await _writeList('$_classesPrefix$churchId', rows);
  }

  Future<List<SundaySchoolClassEntity>?> readClasses(String churchId) async {
    return _readEntities(
      '$_classesPrefix$churchId',
      SundaySchoolClassEntity.fromJson,
    );
  }

  Future<void> saveMembers(String churchId, List<dynamic> rows) async {
    await _writeList('$_membersPrefix$churchId', rows);
  }

  Future<List<MemberEntity>?> readMembers(String churchId) async {
    return _readEntities('$_membersPrefix$churchId', MemberEntity.fromJson);
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
    final members = await readMembers(churchId) ?? [];
    final index = members.indexWhere((item) => item.id == member.id);
    if (index >= 0) {
      members[index] = member;
    } else {
      members.add(member);
    }
    await saveMembers(churchId, members.map(memberToJson).toList());
  }

  Future<void> removeMember(String churchId, String memberId) async {
    final members = await readMembers(churchId) ?? [];
    members.removeWhere((item) => item.id == memberId);
    await saveMembers(churchId, members.map(memberToJson).toList());
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

  Future<void> saveInvitations(String churchId, List<dynamic> rows) async {
    await _writeList('$_invitationsPrefix$churchId', rows);
  }

  Future<List<HelperInvitation>?> readInvitations(String churchId) async {
    return _readEntities(
      '$_invitationsPrefix$churchId',
      HelperInvitation.fromJson,
    );
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

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key == _profileKey ||
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
              key.startsWith(_invitationsPrefix),
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
}
