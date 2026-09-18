import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_deletion_errors.dart';
import '../../core/auth/password_recovery_link.dart';
import '../../core/auth/retry_nullable_load.dart';
import '../../core/invitations/invitation_email_errors.dart';
import '../../core/invitations/invitation_identity.dart';
import '../../core/invitations/invitation_preview.dart';
import '../../shared/data/app_data_changes.dart';
import '../models/models.dart';
import '../offline/invitation_create_result.dart';
import '../offline/member_create_draft.dart';
import '../offline/offline_cache.dart';
import '../offline/offline_entity_json.dart';
import '../offline/offline_network_policy.dart';
import '../offline/offline_save_result.dart';
import '../offline/offline_write_handler.dart';
import '../offline/offline_write_queue.dart';

part 'supabase_attendance_repository.dart';
part 'supabase_auth_repository.dart';
part 'supabase_followups_repository.dart';
part 'supabase_invitations_repository.dart';
part 'supabase_members_repository.dart';
part 'supabase_servants_repository.dart';
part 'supabase_structure_repository.dart';

abstract class DatabaseRepository {
  // Auth
  Future<AppProfile?> signInWithEmailAndPassword(String email, String password);
  Future<AppProfile?> signUpWithEmailAndPassword({
    required String name,
    required String churchName,
    required String email,
    required String password,
    String? phone,
  });
  Future<AppProfile?> signUpWithActivationCode({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String code,
  });
  Future<AppProfile?> signUpWithInvitationToken({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String inviteToken,
  });
  Future<bool> validateInvitationCode(String code);
  Future<InvitationPreview> getInvitationPreview(String inviteToken);
  Future<void> declineInvitationByToken(String inviteToken);
  Future<void> acceptInvitationLink(String inviteToken);
  Future<List<Map<String, dynamic>>> getUserReceivedInvitations();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> updatePassword(String password);
  Future<AppProfile> updateCurrentProfile({
    required String fullName,
    String? phone,
  });
  Future<void> submitSupportTicket({
    required String category,
    required String subject,
    required String description,
  });
  Future<void> deleteCurrentAccount();
  Future<void> signOut();
  bool hasActiveSession();
  Future<AppProfile?> getCurrentProfile();

  // Churches
  Future<Church?> getChurch(String churchId);
  Future<List<Church>> getAllChurches();
  Future<bool> updateChurch(
    String churchId,
    String nameAr,
    String? phone,
    String? address,
  );

  // Meetings
  Future<List<MeetingEntity>> getMeetings();
  Future<OfflineSaveResult<MeetingEntity>> createMeeting({
    required String name,
    required String nameAr,
    required MeetingKind kind,
    required int weekday,
    int? attendanceReminderMinutes,
    String? description,
  });
  Future<OfflineSaveResult<MeetingEntity>> updateMeeting({
    required String id,
    required String name,
    required String nameAr,
    required int weekday,
    required bool isActive,
    int? attendanceReminderMinutes,
    String? description,
  });
  Future<bool> deleteMeeting(String id);

  // Classes
  Future<List<SundaySchoolClassEntity>> getSundaySchoolClasses(
    String meetingId,
  );
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses();
  Future<OfflineSaveResult<SundaySchoolClassEntity>> createSundaySchoolClass({
    required String meetingId,
    required String name,
    required String nameAr,
    required int displayOrder,
  });
  Future<OfflineSaveResult<SundaySchoolClassEntity>> updateSundaySchoolClass({
    required String id,
    required String name,
    required String nameAr,
    required int displayOrder,
    required bool isActive,
  });
  Future<bool> deleteSundaySchoolClass(String id);

  // Members
  Future<List<MemberEntity>> getClassMembers(String classId);
  Future<List<MemberEntity>> getMeetingMembers(String meetingId);
  Future<List<MemberEntity>> getAllMembers();
  Future<MemberEntity?> getMemberDetails(String memberId);
  Future<OfflineSaveResult<MemberEntity>> createMember({
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    String? notes,
  });
  Future<List<OfflineSaveResult<MemberEntity>>> createMembers(
    List<MemberCreateDraft> drafts,
  );
  Future<OfflineSaveResult<MemberEntity>> updateMember({
    required String id,
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    required bool isActive,
    String? notes,
  });
  Future<bool> deleteMember(String id);

  // Assignments
  Future<List<Map<String, dynamic>>> getClassAssignments(String classId);
  Future<List<Map<String, dynamic>>> getMeetingAssignments(String meetingId);
  Future<void> assignClassLeader(
    String classId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  });
  Future<void> assignAllMeetingClasses(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  });
  Future<void> assignMeetingOfficer(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  });
  Future<void> removeClassAssignment(String assignmentId);
  Future<void> removeMeetingAssignment(String assignmentId);

  // Profiles (Servant Accounts)
  Future<List<AppProfile>> getProfiles();
  Future<void> updateProfileRole(String userId, AppRole role);
  Future<void> updateProfileStatus(String userId, bool isActive);

  // Weekly Attendance Sessions
  Future<List<AttendanceSessionEntity>> getSessions(
    String meetingId, {
    String? classId,
  });
  Future<OfflineSaveResult<AttendanceSessionEntity>> createWeeklySession({
    required String meetingId,
    String? classId,
    required DateTime sessionDate,
    required int weekNumber,
    String? title,
  });
  Future<bool> deleteWeeklySession(
    String sessionId, {
    String? meetingId,
    String? classId,
  });

  // Attendance Records
  Future<List<AttendanceRecordEntity>> getAttendanceRecords(String sessionId);
  Future<List<MemberAttendanceHistoryEntry>> getMemberAttendanceHistory(
    String memberId,
  );
  Future<bool> saveAttendanceRecords({
    required String sessionId,
    required Map<String, AttendanceStatus> statusesByMemberId,
  });

  // Follow-ups
  Future<List<FollowUpEntity>> getMemberFollowUps(String memberId);
  Future<List<FollowUpEntity>> getAllFollowUps();
  Future<bool> addFollowUp({
    required String memberId,
    String? sessionId,
    String? reason,
    required String contactStatus,
    String? result,
    String? responsibleUserId,
    required DateTime followUpDate,
  });
  Future<bool> deleteFollowUp(String id);

  // Reports Views
  Future<List<Map<String, dynamic>>> getAttendanceReportStats();

  // Helper Invitations & Assignments
  Future<OfflineSaveResult<InvitationCreateResult>> createInvitation({
    required String fullName,
    String? email,
    String? phone,
    required AppRole role,
    String? targetId,
    String? assignmentScope,
    bool canTakeAttendance = true,
    bool canViewReports = true,
  });
  Future<List<HelperInvitation>> getInvitations();
  Future<bool> updateInvitation({
    required HelperInvitation invitation,
    required String fullName,
    String? email,
  });
  Future<bool> deleteInvitation(String id);
  Future<void> sendInvitationEmail(String invitationId);
  Future<List<Map<String, dynamic>>> getUserClassAssignments(String userId);
  Future<List<Map<String, dynamic>>> getUserMeetingAssignments(String userId);

  // Realtime Sync
  Stream<List<AttendanceRecordEntity>> subscribeToAttendanceRecords(
    String sessionId,
  );
  Stream<List<MemberEntity>> subscribeToMembers();
  Stream<List<FollowUpEntity>> subscribeToFollowUps();

  // Offline sync
  Future<void> syncPendingOfflineData();
  Future<bool> hasPendingOfflineData();

  /// How many locally accepted changes the server refused for good. They stay on
  /// the device so the interface can report them instead of losing the servant's
  /// work silently.
  Future<int> rejectedOfflineDataCount();

  /// Forgets the refused changes once the user has dismissed the warning.
  Future<void> clearRejectedOfflineData();

  Future<void> warmOfflineCache();
}

abstract class _SupabaseRepositoryBase implements DatabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final OfflineCache _offlineCache = OfflineCache();
  final OfflineWriteQueue _writeQueue = OfflineWriteQueue();
  late final OfflineWriteHandler _offlineWriter;

  Future<T> _notifyAfter<T>(Future<T> operation, Set<AppDataArea> areas) async {
    final result = await operation;
    AppDataChanges.instance.notify(areas);
    return result;
  }

  bool _isRecoverableOfflineError(Object error) =>
      _offlineWriter.isRecoverableOfflineError(error);

  Future<String?> _cachedChurchIdForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final cached = await _offlineCache.readProfile();
    if (cached != null && cached.id == user.id) {
      return cached.churchId;
    }
    return null;
  }

  Future<List<MemberEntity>> _readCachedMembers() async {
    final churchId = await _cachedChurchIdForCurrentUser();
    if (churchId == null) return [];
    return await _offlineCache.readMembers(churchId) ?? [];
  }

  Future<AppProfile?> _readCachedProfileForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final cached = await _offlineCache.readProfile();
    if (cached != null && cached.id == user.id) {
      return cached;
    }
    return null;
  }

  Future<Set<String>> _pendingDeletedEntityIds() =>
      _writeQueue.pendingDeletedEntityIds();

  List<Map<String, dynamic>> _filterDeletedRows(
    List rows,
    Set<String> pendingDeletes,
  ) {
    if (pendingDeletes.isEmpty) {
      return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }
    return rows
        .where((row) => !pendingDeletes.contains((row as Map)['id'] as String))
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  List<T> _filterDeletedEntities<T>(
    List<T> items,
    String Function(T item) idOf,
    Set<String> pendingDeletes,
  ) {
    if (pendingDeletes.isEmpty) return items;
    return items.where((item) => !pendingDeletes.contains(idOf(item))).toList();
  }

  @override
  Future<void> syncPendingOfflineData() async {
    final hadPendingData = await _offlineWriter.hasPendingData();
    await _offlineWriter.syncAll();
    if (hadPendingData) {
      AppDataChanges.instance.notify(AppDataArea.values.toSet());
    }
  }

  @override
  Future<bool> hasPendingOfflineData() => _offlineWriter.hasPendingData();

  @override
  Future<int> rejectedOfflineDataCount() => _offlineWriter.rejectedDataCount();

  @override
  Future<void> clearRejectedOfflineData() => _offlineWriter.clearRejectedData();

  @override
  Future<void> warmOfflineCache() async {
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) return;

    try {
      final profile = await getCurrentProfile();
      if (profile?.churchId == null) return;

      final results = await Future.wait([
        getAllMembers(),
        getMeetings(),
        getAllSundaySchoolClasses(),
        getAllFollowUps(),
        getProfiles(),
        getUserClassAssignments(profile!.id),
        getUserMeetingAssignments(profile.id),
        getAttendanceReportStats(),
        getInvitations(),
      ]);
      final meetings = results[1] as List<MeetingEntity>;
      final classes = results[2] as List<SundaySchoolClassEntity>;
      final profiles = results[4] as List<AppProfile>;

      await Future.wait([
        ...classes.map((cls) => getClassAssignments(cls.id)),
        ...meetings
            .where((meeting) => meeting.kind != MeetingKind.sundaySchool)
            .map((meeting) => getMeetingAssignments(meeting.id)),
        ...profiles.expand(
          (servant) => [
            getUserClassAssignments(servant.id),
            getUserMeetingAssignments(servant.id),
          ],
        ),
      ]);

      final sessionFetches = <Future<void>>[];
      for (final cls in classes.where((item) => item.isActive)) {
        sessionFetches.add(() async {
          final sessions = await getSessions(cls.meetingId, classId: cls.id);
          for (final session in sessions) {
            await getAttendanceRecords(session.id);
          }
        }());
      }
      for (final meeting in meetings.where(
        (item) => item.isActive && item.kind != MeetingKind.sundaySchool,
      )) {
        sessionFetches.add(() async {
          final sessions = await getSessions(meeting.id);
          for (final session in sessions) {
            await getAttendanceRecords(session.id);
          }
        }());
      }
      await Future.wait(sessionFetches);
    } catch (_) {}
  }

  Stream<List<T>> _streamTable<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<List<T>> Function() offlineFallback,
    String? filterColumn,
    Object? filterValue,
  }) async* {
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      yield await offlineFallback();
      return;
    }
    try {
      final stream = filterColumn != null && filterValue != null
          ? _client
                .from(table)
                .stream(primaryKey: const ['id'])
                .eq(filterColumn, filterValue)
          : _client.from(table).stream(primaryKey: const ['id']);
      await for (final rows in stream) {
        yield [for (final row in rows) fromJson(row)];
      }
    } catch (_) {
      yield await offlineFallback();
    }
  }

  Future<List<FollowUpEntity>> _readCachedFollowUps() async {
    final churchId = await _cachedChurchIdForCurrentUser();
    if (churchId == null) return [];
    return await _offlineCache.readFollowUps(churchId) ?? [];
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class SupabaseRepository extends _SupabaseRepositoryBase
    with
        _SupabaseAuthRepository,
        _SupabaseStructureRepository,
        _SupabaseMembersRepository,
        _SupabaseServantsRepository,
        _SupabaseAttendanceRepository,
        _SupabaseFollowUpsRepository,
        _SupabaseInvitationsRepository {
  SupabaseRepository() {
    _offlineWriter = OfflineWriteHandler(
      client: _client,
      cache: _offlineCache,
      queue: _writeQueue,
      loadProfile: getCurrentProfile,
      saveAttendanceOnline: _saveAttendanceRecordsOnline,
      emptyToNull: _emptyToNull,
    );
  }
}
