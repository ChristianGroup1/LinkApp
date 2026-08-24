import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../../core/auth/account_deletion_errors.dart';
import '../../core/auth/password_recovery_link.dart';
import '../../core/invitations/invitation_email_errors.dart';
import '../../core/invitations/invitation_identity.dart';
import '../../core/invitations/invitation_preview.dart';
import '../offline/invitation_create_result.dart';
import '../offline/offline_cache.dart';
import '../offline/offline_entity_json.dart';
import '../offline/offline_network_policy.dart';
import '../offline/offline_save_result.dart';
import '../offline/offline_write_handler.dart';
import '../offline/offline_write_queue.dart';
import '../../shared/data/app_data_changes.dart';

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

  // Offline sync
  Future<void> syncPendingOfflineData();
  Future<bool> hasPendingOfflineData();
  Future<void> warmOfflineCache();
}

class SupabaseRepository implements DatabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final OfflineCache _offlineCache = OfflineCache();
  final OfflineWriteQueue _writeQueue = OfflineWriteQueue();
  late final OfflineWriteHandler _offlineWriter = OfflineWriteHandler(
    client: _client,
    cache: _offlineCache,
    queue: _writeQueue,
    loadProfile: getCurrentProfile,
    saveAttendanceOnline: _saveAttendanceRecordsOnline,
    emptyToNull: _emptyToNull,
  );

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

  @override
  Future<AppProfile?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user != null) {
      final profile = await getCurrentProfile();
      if (profile == null) {
        await _client.auth.signOut();
        throw Exception(
          'تم قبول بيانات الدخول، لكن الحساب غير مربوط بملف خادم داخل الكنيسة. اطلب من مسؤول الكنيسة إعادة دعوتك أو إصلاح حسابك.',
        );
      }
      if (!profile.isActive) {
        await _client.auth.signOut();
        throw Exception('تم إيقاف حسابك. راجع مسؤول الكنيسة لإعادة تفعيله.');
      }
      unawaited(warmOfflineCache());
      return profile;
    }
    return null;
  }

  @override
  Future<AppProfile?> signUpWithEmailAndPassword({
    required String name,
    required String churchName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'new_church',
        'church_name': churchName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerNewChurchProfile(
        userId: response.user!.id,
        churchName: churchName,
        fullName: name,
        email: response.user!.email ?? email,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<bool> validateInvitationCode(String code) async {
    final result = await _client.rpc(
      'validate_invitation_code',
      params: {'invite_code': code.trim().toUpperCase()},
    );
    if (result is Map) {
      return result['valid'] == true;
    }
    return false;
  }

  Future<void> _registerNewChurchProfile({
    required String userId,
    required String churchName,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await _client.rpc(
      'register_new_church_signup',
      params: {
        'profile_id': userId,
        'church_name': churchName.trim(),
        'profile_full_name': fullName.trim(),
        'profile_email': email.trim(),
        'profile_phone': phone?.trim(),
      },
    );
  }

  Future<void> _registerInvitedProfile({
    required String userId,
    String? code,
    String? inviteToken,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await _client.rpc(
      'register_invited_signup',
      params: {
        'profile_id': userId,
        'invite_code': code?.trim().toUpperCase(),
        'invite_token': inviteToken?.trim(),
        'profile_full_name': fullName.trim(),
        'profile_email': email.trim(),
        'profile_phone': phone?.trim(),
      },
    );
  }

  Future<void> _completePendingSignupIfNeeded(User user) async {
    final meta = user.userMetadata;
    if (meta == null) return;

    final signupType = meta['signup_type'] as String?;
    if (signupType == 'new_church') {
      final churchName = meta['church_name'] as String?;
      if (churchName == null || churchName.trim().isEmpty) return;
      await _registerNewChurchProfile(
        userId: user.id,
        churchName: churchName,
        fullName: (meta['full_name'] as String?) ?? user.email ?? 'مستخدم',
        email: user.email ?? '',
        phone: meta['phone'] as String?,
      );
      return;
    }

    if (signupType == 'invitation') {
      final code = meta['invitation_code'] as String?;
      final token = meta['invitation_token'] as String?;
      if ((code == null || code.trim().isEmpty) &&
          (token == null || token.trim().isEmpty)) {
        return;
      }
      await _registerInvitedProfile(
        userId: user.id,
        code: code,
        inviteToken: token,
        fullName: (meta['full_name'] as String?) ?? user.email ?? 'مستخدم',
        email: user.email ?? '',
        phone: meta['phone'] as String?,
      );
    }
  }

  @override
  Future<AppProfile?> signUpWithActivationCode({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String code,
  }) async {
    final isValid = await validateInvitationCode(code);
    if (!isValid) {
      throw Exception('كود التفعيل غير صالح أو تم استخدامه مسبقاً.');
    }

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'invitation',
        'invitation_code': code.trim().toUpperCase(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerInvitedProfile(
        userId: response.user!.id,
        code: code,
        fullName: name,
        email: response.user!.email ?? email,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<AppProfile?> signUpWithInvitationToken({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String inviteToken,
  }) async {
    final preview = await getInvitationPreview(inviteToken);
    if (!preview.valid) {
      throw Exception('رابط الدعوة غير صالح أو انتهت صلاحيته.');
    }

    if (!invitationEmailMatchesAccount(
      invitationEmail: preview.email,
      accountEmail: email,
    )) {
      throw Exception(
        'يجب إنشاء الحساب بنفس البريد الإلكتروني المكتوب في الدعوة.',
      );
    }

    final invitationEmail = preview.email!.trim();

    final response = await _client.auth.signUp(
      email: invitationEmail,
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'invitation',
        'invitation_token': inviteToken.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerInvitedProfile(
        userId: response.user!.id,
        inviteToken: inviteToken,
        fullName: name,
        email: response.user!.email ?? invitationEmail,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<InvitationPreview> getInvitationPreview(String inviteToken) async {
    final result = await _client.rpc(
      'get_invitation_by_token',
      params: {'p_token': inviteToken.trim()},
    );
    if (result is Map) {
      return InvitationPreview.fromJson(Map<String, dynamic>.from(result));
    }
    return const InvitationPreview(valid: false);
  }

  @override
  Future<void> declineInvitationByToken(String inviteToken) async {
    try {
      await _client.rpc(
        'decline_invitation_by_token',
        params: {'p_token': inviteToken.trim()},
      );
    } on PostgrestException catch (error) {
      throw Exception(_invitationActionErrorMessage(error));
    }
  }

  @override
  Future<void> acceptInvitationLink(String inviteToken) async {
    try {
      await _client.rpc(
        'accept_invitation_link',
        params: {'p_token': inviteToken.trim()},
      );
    } on PostgrestException catch (error) {
      throw Exception(_invitationActionErrorMessage(error));
    }
  }

  String _invitationActionErrorMessage(PostgrestException error) {
    if (error.code == '23503') {
      return 'المهمة المرتبطة بالدعوة لم تعد موجودة. اطلب من مسؤول الكنيسة تحديث الدعوة أو إنشاء دعوة جديدة.';
    }
    final message = error.message.trim();
    return message.isEmpty ? 'تعذر تنفيذ الإجراء على الدعوة.' : message;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserReceivedInvitations() async {
    try {
      final res = await _client.rpc('get_my_received_invitations');
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (_) {}

    final profile = await getCurrentProfile();
    if (profile?.email == null || profile!.email!.trim().isEmpty) {
      return [];
    }

    final email = profile.email!.trim().toLowerCase();
    try {
      final rows = await _client
          .from('invitations')
          .select('*, churches(name_ar, name)')
          .ilike('email', email)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: passwordResetRedirectUrl,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<AppProfile> updateCurrentProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('لا يوجد حساب مسجل دخول');

    final cachedProfile = await _readCachedProfileForCurrentUser();
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      return _saveCurrentProfileOffline(
        userId: user.id,
        existing: cachedProfile,
        fullName: fullName,
        phone: phone,
      );
    }

    try {
      final row = await _client
          .from('profiles')
          .update({'full_name': fullName.trim(), 'phone': _emptyToNull(phone)})
          .eq('id', user.id)
          .select()
          .single();
      await _offlineCache.saveProfile(Map<String, dynamic>.from(row));
      final profile = AppProfile.fromJson(row);
      if (profile.churchId != null) {
        await _offlineCache.upsertProfile(profile.churchId!, profile);
      }
      AppDataChanges.instance.notify({AppDataArea.profile});
      return profile;
    } catch (error) {
      if (!_isRecoverableOfflineError(error)) rethrow;
      return _saveCurrentProfileOffline(
        userId: user.id,
        existing: cachedProfile,
        fullName: fullName,
        phone: phone,
      );
    }
  }

  Future<AppProfile> _saveCurrentProfileOffline({
    required String userId,
    required AppProfile? existing,
    required String fullName,
    String? phone,
  }) async {
    if (existing == null) {
      throw Exception('بيانات الحساب غير متاحة محليًا بعد');
    }
    final updated = AppProfile(
      id: existing.id,
      churchId: existing.churchId,
      fullName: fullName.trim(),
      role: existing.role,
      email: existing.email,
      phone: _emptyToNull(phone),
      isActive: existing.isActive,
    );
    await _offlineCache.saveProfile(profileToJson(updated));
    if (updated.churchId != null) {
      await _offlineCache.upsertProfile(updated.churchId!, updated);
    }
    await _writeQueue.removeByEntityId(userId);
    await _writeQueue.enqueue(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: OfflineOpType.currentProfileUpdate,
        payload: {
          'id': userId,
          'full_name': updated.fullName,
          'phone': updated.phone,
        },
        queuedAt: DateTime.now(),
      ),
    );
    AppDataChanges.instance.notify({AppDataArea.profile});
    return updated;
  }

  @override
  Future<void> deleteCurrentAccount() async {
    if (_client.auth.currentUser == null) {
      throw Exception('لا يوجد حساب مسجل دخول');
    }

    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final message = data is Map ? data['error']?.toString() : null;
        throw Exception(message ?? 'تعذر حذف الحساب');
      }
    } catch (error) {
      throw Exception(accountDeletionErrorMessage(error));
    }

    await _offlineCache.clearAll();
    await _writeQueue.clear();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _offlineCache.clearAll();
    await _writeQueue.clear();
  }

  @override
  bool hasActiveSession() {
    return _client.auth.currentSession != null ||
        _client.auth.currentUser != null;
  }

  @override
  Future<AppProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    await OfflineNetworkPolicy.ensureReady();

    if (OfflineNetworkPolicy.isConnectivityOffline) {
      return _readCachedProfileForCurrentUser();
    }

    try {
      unawaited(syncPendingOfflineData());

      var data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(OfflineNetworkPolicy.requestTimeout);

      if (data == null && _client.auth.currentSession != null) {
        await _completePendingSignupIfNeeded(user);
        data = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(OfflineNetworkPolicy.requestTimeout);
      }

      if (data != null) {
        await _offlineCache.saveProfile(Map<String, dynamic>.from(data));
        return AppProfile.fromJson(data);
      }
      return null;
    } catch (error) {
      final cached = await _readCachedProfileForCurrentUser();
      if (cached != null) return cached;
      if (_isRecoverableOfflineError(error)) return null;
      rethrow;
    }
  }

  // Churches
  @override
  Future<Church?> getChurch(String churchId) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final row = await _client
            .from('churches')
            .select()
            .eq('id', churchId)
            .maybeSingle();
        if (row == null) return null;
        await _offlineCache.saveChurch(
          churchId,
          Map<String, dynamic>.from(row),
        );
        return Church.fromJson(row);
      },
      offline: () async {
        return await _offlineCache.readChurch(churchId);
      },
    );
  }

  @override
  Future<List<Church>> getAllChurches() async {
    final rows = await _client.from('churches').select().order('name_ar');
    return (rows as List).map((json) => Church.fromJson(json)).toList();
  }

  @override
  Future<bool> updateChurch(
    String churchId,
    String nameAr,
    String? phone,
    String? address,
  ) {
    return _notifyAfter(
      _offlineWriter.updateChurch(churchId, nameAr, phone, address),
      {AppDataArea.church},
    );
  }

  // Meetings
  @override
  Future<List<MeetingEntity>> getMeetings() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('meetings')
            .select()
            .eq('church_id', churchId)
            .order('kind')
            .order('name_ar');
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveMeetings(churchId, filteredRows);
        return filteredRows
            .map((json) => MeetingEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final meetings = await _offlineCache.readMeetings(churchId) ?? [];
        return _filterDeletedEntities(
          meetings,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<OfflineSaveResult<MeetingEntity>> createMeeting({
    required String name,
    required String nameAr,
    required MeetingKind kind,
    required int weekday,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.createMeeting(
        churchId: profile!.churchId!,
        createdBy: profile.id,
        name: name,
        nameAr: nameAr,
        kind: kind,
        weekday: weekday,
        attendanceReminderMinutes: attendanceReminderMinutes,
        description: description,
      ),
      {AppDataArea.meetings},
    );
  }

  @override
  Future<OfflineSaveResult<MeetingEntity>> updateMeeting({
    required String id,
    required String name,
    required String nameAr,
    required int weekday,
    required bool isActive,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.updateMeeting(
        churchId: profile!.churchId!,
        id: id,
        name: name,
        nameAr: nameAr,
        weekday: weekday,
        isActive: isActive,
        attendanceReminderMinutes: attendanceReminderMinutes,
        description: description,
      ),
      {AppDataArea.meetings},
    );
  }

  @override
  Future<bool> deleteMeeting(String id) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(_offlineWriter.deleteMeeting(profile!.churchId!, id), {
      AppDataArea.meetings,
      AppDataArea.classes,
    });
  }

  // Classes
  @override
  Future<List<SundaySchoolClassEntity>> getSundaySchoolClasses(
    String meetingId,
  ) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('sunday_school_classes')
            .select()
            .eq('meeting_id', meetingId)
            .order('display_order');
        final churchId = await _cachedChurchIdForCurrentUser();
        if (churchId != null) {
          await _offlineCache.saveClasses(churchId, rows as List);
        }
        return (rows as List)
            .map((json) => SundaySchoolClassEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final churchId = await _cachedChurchIdForCurrentUser();
        if (churchId == null) return [];
        final cached = await _offlineCache.readClasses(churchId);
        return cached?.where((item) => item.meetingId == meetingId).toList() ??
            [];
      },
    );
  }

  @override
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('sunday_school_classes')
            .select()
            .eq('church_id', churchId)
            .order('display_order');
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveClasses(churchId, filteredRows);
        return filteredRows
            .map((json) => SundaySchoolClassEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final classes = await _offlineCache.readClasses(churchId) ?? [];
        return _filterDeletedEntities(
          classes,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<OfflineSaveResult<SundaySchoolClassEntity>> createSundaySchoolClass({
    required String meetingId,
    required String name,
    required String nameAr,
    required int displayOrder,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.createSundaySchoolClass(
        churchId: profile!.churchId!,
        meetingId: meetingId,
        name: name,
        nameAr: nameAr,
        displayOrder: displayOrder,
      ),
      {AppDataArea.classes},
    );
  }

  @override
  Future<OfflineSaveResult<SundaySchoolClassEntity>> updateSundaySchoolClass({
    required String id,
    required String name,
    required String nameAr,
    required int displayOrder,
    required bool isActive,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.updateSundaySchoolClass(
        churchId: profile!.churchId!,
        id: id,
        name: name,
        nameAr: nameAr,
        displayOrder: displayOrder,
        isActive: isActive,
      ),
      {AppDataArea.classes},
    );
  }

  @override
  Future<bool> deleteSundaySchoolClass(String id) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.deleteSundaySchoolClass(profile!.churchId!, id),
      {AppDataArea.classes},
    );
  }

  // Members
  @override
  Future<List<MemberEntity>> getClassMembers(String classId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('sunday_school_class_id', classId)
            .eq('is_active', true)
            .order('full_name');
        return _filterDeletedRows(
          rows as List,
          pendingDeletes,
        ).map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _readCachedMembers();
        return _filterDeletedEntities(
          members
              .where((m) => m.isActive && m.sundaySchoolClassId == classId)
              .toList(),
          (item) => item.id,
          pendingDeletes,
        )..sort((a, b) => a.fullName.compareTo(b.fullName));
      },
    );
  }

  @override
  Future<List<MemberEntity>> getMeetingMembers(String meetingId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('meeting_id', meetingId)
            .eq('is_active', true)
            .order('full_name');
        return _filterDeletedRows(
          rows as List,
          pendingDeletes,
        ).map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _readCachedMembers();
        return _filterDeletedEntities(
          members.where((m) => m.isActive && m.meetingId == meetingId).toList(),
          (item) => item.id,
          pendingDeletes,
        )..sort((a, b) => a.fullName.compareTo(b.fullName));
      },
    );
  }

  @override
  Future<List<MemberEntity>> getAllMembers() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('church_id', churchId)
            .order('full_name');
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveMembers(churchId, filteredRows);
        return filteredRows.map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _offlineCache.readMembers(churchId) ?? [];
        return _filterDeletedEntities(
          members,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<MemberEntity?> getMemberDetails(String memberId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    if (pendingDeletes.contains(memberId)) return null;

    return OfflineNetworkPolicy.run(
      online: () async {
        final row = await _client
            .from('members')
            .select()
            .eq('id', memberId)
            .maybeSingle();
        return row == null ? null : MemberEntity.fromJson(row);
      },
      offline: () async {
        final members = await _readCachedMembers();
        for (final member in members) {
          if (member.id == memberId) return member;
        }
        return null;
      },
    );
  }

  @override
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
  }) {
    return _notifyAfter(
      _offlineWriter.createMember(
        fullName: fullName,
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        phone: phone,
        parentName: parentName,
        parentPhone: parentPhone,
        code: code,
        birthDate: birthDate,
        notes: notes,
      ),
      {AppDataArea.members},
    );
  }

  @override
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
  }) {
    return _notifyAfter(
      _offlineWriter.updateMember(
        id: id,
        fullName: fullName,
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        phone: phone,
        parentName: parentName,
        parentPhone: parentPhone,
        code: code,
        birthDate: birthDate,
        isActive: isActive,
        notes: notes,
      ),
      {AppDataArea.members},
    );
  }

  @override
  Future<bool> deleteMember(String id) =>
      _notifyAfter(_offlineWriter.deleteMember(id), {AppDataArea.members});

  // Assignments
  @override
  Future<List<Map<String, dynamic>>> getClassAssignments(String classId) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('class_assignments')
            .select(
              'id, user_id, can_take_attendance, can_view_reports, profiles(full_name, email)',
            )
            .eq('class_id', classId);
        final assignments = List<Map<String, dynamic>>.from(rows as List);
        await _offlineCache.saveClassAssignmentsForClass(classId, assignments);
        return assignments;
      },
      offline: () async {
        return await _offlineCache.readClassAssignmentsForClass(classId) ?? [];
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMeetingAssignments(
    String meetingId,
  ) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('meeting_assignments')
            .select(
              'id, user_id, can_take_attendance, can_view_reports, profiles(full_name, email)',
            )
            .eq('meeting_id', meetingId);
        final assignments = List<Map<String, dynamic>>.from(rows as List);
        await _offlineCache.saveMeetingAssignmentsForMeeting(
          meetingId,
          assignments,
        );
        return assignments;
      },
      offline: () async {
        return await _offlineCache.readMeetingAssignmentsForMeeting(
              meetingId,
            ) ??
            [];
      },
    );
  }

  @override
  Future<void> assignClassLeader(
    String classId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }

    final payload = {
      'church_id': profile!.churchId!,
      'class_id': classId,
      'user_id': userId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'assigned_by': profile.id,
    };
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      await _saveClassAssignmentOffline(payload);
      AppDataChanges.instance.notify({AppDataArea.assignments});
      return;
    }
    try {
      final row = await _client
          .from('class_assignments')
          .upsert(payload, onConflict: 'class_id,user_id')
          .select('id')
          .single();
      await _offlineCache.upsertClassAssignment(
        churchId: profile.churchId!,
        assignmentId: row['id'] as String,
        classId: classId,
        userId: userId,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
      );
    } catch (error) {
      if (!_isRecoverableOfflineError(error)) rethrow;
      await _saveClassAssignmentOffline(payload);
    }
    AppDataChanges.instance.notify({AppDataArea.assignments});
  }

  Future<void> _saveClassAssignmentOffline(Map<String, dynamic> payload) async {
    final localId = await _writeQueue.generateId('class_assignment');
    final resolvedId = await _offlineCache.upsertClassAssignment(
      churchId: payload['church_id'] as String,
      assignmentId: localId,
      classId: payload['class_id'] as String,
      userId: payload['user_id'] as String,
      canTakeAttendance: payload['can_take_attendance'] as bool,
      canViewReports: payload['can_view_reports'] as bool,
    );
    await _writeQueue.removeByEntityId(resolvedId);
    await _writeQueue.enqueue(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: OfflineOpType.classAssignmentUpsert,
        payload: {...payload, 'local_id': resolvedId},
        queuedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> assignAllMeetingClasses(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final classes = await getSundaySchoolClasses(meetingId);
    for (final cls in classes.where((c) => c.isActive)) {
      await assignClassLeader(
        cls.id,
        userId,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
      );
    }
  }

  @override
  Future<void> assignMeetingOfficer(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }

    final payload = {
      'church_id': profile!.churchId!,
      'meeting_id': meetingId,
      'user_id': userId,
      'can_take_attendance': canTakeAttendance,
      'can_view_reports': canViewReports,
      'assigned_by': profile.id,
    };
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      await _saveMeetingAssignmentOffline(payload);
      AppDataChanges.instance.notify({AppDataArea.assignments});
      return;
    }
    try {
      final row = await _client
          .from('meeting_assignments')
          .upsert(payload, onConflict: 'meeting_id,user_id')
          .select('id')
          .single();
      await _offlineCache.upsertMeetingAssignment(
        churchId: profile.churchId!,
        assignmentId: row['id'] as String,
        meetingId: meetingId,
        userId: userId,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
      );
    } catch (error) {
      if (!_isRecoverableOfflineError(error)) rethrow;
      await _saveMeetingAssignmentOffline(payload);
    }
    AppDataChanges.instance.notify({AppDataArea.assignments});
  }

  Future<void> _saveMeetingAssignmentOffline(
    Map<String, dynamic> payload,
  ) async {
    final localId = await _writeQueue.generateId('meeting_assignment');
    final resolvedId = await _offlineCache.upsertMeetingAssignment(
      churchId: payload['church_id'] as String,
      assignmentId: localId,
      meetingId: payload['meeting_id'] as String,
      userId: payload['user_id'] as String,
      canTakeAttendance: payload['can_take_attendance'] as bool,
      canViewReports: payload['can_view_reports'] as bool,
    );
    await _writeQueue.removeByEntityId(resolvedId);
    await _writeQueue.enqueue(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: OfflineOpType.meetingAssignmentUpsert,
        payload: {...payload, 'local_id': resolvedId},
        queuedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> removeClassAssignment(String assignmentId) async {
    await _removeAssignment(
      assignmentId,
      table: 'class_assignments',
      operationType: OfflineOpType.classAssignmentDelete,
      isClassAssignment: true,
    );
    AppDataChanges.instance.notify({AppDataArea.assignments});
  }

  @override
  Future<void> removeMeetingAssignment(String assignmentId) async {
    await _removeAssignment(
      assignmentId,
      table: 'meeting_assignments',
      operationType: OfflineOpType.meetingAssignmentDelete,
      isClassAssignment: false,
    );
    AppDataChanges.instance.notify({AppDataArea.assignments});
  }

  Future<void> _removeAssignment(
    String assignmentId, {
    required String table,
    required String operationType,
    required bool isClassAssignment,
  }) async {
    await _offlineCache.removeAssignmentEverywhere(
      assignmentId,
      isClassAssignment: isClassAssignment,
    );
    final resolvedId = await _writeQueue.resolveId(assignmentId);
    if (isOfflineId(assignmentId) && resolvedId == assignmentId) {
      await _writeQueue.removeByEntityId(assignmentId);
      return;
    }
    await OfflineNetworkPolicy.ensureReady();
    if (!OfflineNetworkPolicy.isConnectivityOffline) {
      try {
        await _client.from(table).delete().eq('id', resolvedId);
        return;
      } catch (error) {
        if (!_isRecoverableOfflineError(error)) rethrow;
      }
    }
    await _writeQueue.enqueue(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: operationType,
        payload: {'id': resolvedId},
        queuedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getUserClassAssignments(
    String userId,
  ) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('class_assignments')
            .select(
              'id, class_id, can_take_attendance, can_view_reports, sunday_school_classes(name_ar)',
            )
            .eq('user_id', userId);
        final assignments = List<Map<String, dynamic>>.from(rows as List);
        await _offlineCache.saveClassAssignments(userId, assignments);
        return assignments;
      },
      offline: () async {
        return await _offlineCache.readClassAssignments(userId) ?? [];
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getUserMeetingAssignments(
    String userId,
  ) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('meeting_assignments')
            .select(
              'id, meeting_id, can_take_attendance, can_view_reports, meetings(name_ar)',
            )
            .eq('user_id', userId);
        final assignments = List<Map<String, dynamic>>.from(rows as List);
        await _offlineCache.saveMeetingAssignments(userId, assignments);
        return assignments;
      },
      offline: () async {
        return await _offlineCache.readMeetingAssignments(userId) ?? [];
      },
    );
  }

  // Profiles
  @override
  Future<List<AppProfile>> getProfiles() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('profiles')
            .select()
            .eq('church_id', churchId)
            .order('full_name');
        await _offlineCache.saveProfiles(churchId, rows as List);
        return (rows as List).map((json) => AppProfile.fromJson(json)).toList();
      },
      offline: () async {
        return await _offlineCache.readProfiles(churchId) ?? [];
      },
    );
  }

  @override
  Future<void> updateProfileRole(String userId, AppRole role) async {
    await OfflineNetworkPolicy.ensureReady();
    var shouldQueue = OfflineNetworkPolicy.isConnectivityOffline;
    if (!shouldQueue) {
      try {
        await _client.rpc(
          'admin_update_profile_role',
          params: {'target_user_id': userId, 'new_role': role.value},
        );
      } catch (error) {
        if (!_isRecoverableOfflineError(error)) rethrow;
        shouldQueue = true;
      }
    }
    await _updateCachedProfile(userId, role: role);
    if (shouldQueue) {
      await _writeQueue.enqueue(
        QueuedOperation(
          id: await _writeQueue.generateId('op'),
          type: OfflineOpType.profileRoleUpdate,
          payload: {'user_id': userId, 'role': role.value},
          queuedAt: DateTime.now(),
        ),
      );
    }
    AppDataChanges.instance.notify({
      AppDataArea.profile,
      AppDataArea.assignments,
    });
  }

  @override
  Future<void> updateProfileStatus(String userId, bool isActive) async {
    await OfflineNetworkPolicy.ensureReady();
    var shouldQueue = OfflineNetworkPolicy.isConnectivityOffline;
    if (!shouldQueue) {
      try {
        await _client.rpc(
          'admin_update_profile_status',
          params: {'target_user_id': userId, 'new_is_active': isActive},
        );
      } catch (error) {
        if (!_isRecoverableOfflineError(error)) rethrow;
        shouldQueue = true;
      }
    }
    await _updateCachedProfile(userId, isActive: isActive);
    if (shouldQueue) {
      await _writeQueue.enqueue(
        QueuedOperation(
          id: await _writeQueue.generateId('op'),
          type: OfflineOpType.profileStatusUpdate,
          payload: {'user_id': userId, 'is_active': isActive},
          queuedAt: DateTime.now(),
        ),
      );
    }
    AppDataChanges.instance.notify({AppDataArea.profile});
  }

  Future<void> _updateCachedProfile(
    String userId, {
    AppRole? role,
    bool? isActive,
  }) async {
    final current = await _readCachedProfileForCurrentUser();
    final churchId = current?.churchId ?? await _cachedChurchIdForCurrentUser();
    if (churchId == null) return;
    final profiles = await _offlineCache.readProfiles(churchId) ?? [];
    final target = profiles.where((item) => item.id == userId).firstOrNull;
    final source = target ?? (current?.id == userId ? current : null);
    if (source == null) return;
    final updated = AppProfile(
      id: source.id,
      churchId: source.churchId,
      fullName: source.fullName,
      role: role ?? source.role,
      email: source.email,
      phone: source.phone,
      isActive: isActive ?? source.isActive,
    );
    await _offlineCache.upsertProfile(churchId, updated);
    if (current?.id == userId) {
      await _offlineCache.saveProfile(profileToJson(updated));
    }
  }

  // Attendance Sessions
  @override
  Future<List<AttendanceSessionEntity>> getSessions(
    String meetingId, {
    String? classId,
  }) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        var query = _client
            .from('attendance_sessions')
            .select()
            .eq('meeting_id', meetingId);
        if (classId != null) {
          query = query.eq('class_id', classId);
        } else {
          query = query.filter('class_id', 'is', null);
        }

        final rows = await query.order('session_date', ascending: false);
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveSessions(meetingId, classId, filteredRows);
        return filteredRows
            .map((json) => AttendanceSessionEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final sessions =
            await _offlineCache.readSessions(meetingId, classId) ?? [];
        return _filterDeletedEntities(
          sessions,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<OfflineSaveResult<AttendanceSessionEntity>> createWeeklySession({
    required String meetingId,
    String? classId,
    required DateTime sessionDate,
    required int weekNumber,
    String? title,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.createWeeklySession(
        churchId: profile!.churchId!,
        meetingId: meetingId,
        classId: classId,
        sessionDate: sessionDate,
        weekNumber: weekNumber,
        title: title,
      ),
      {AppDataArea.attendance},
    );
  }

  @override
  Future<bool> deleteWeeklySession(
    String sessionId, {
    String? meetingId,
    String? classId,
  }) {
    return _notifyAfter(
      _offlineWriter.deleteWeeklySession(
        meetingId: meetingId ?? '',
        classId: classId,
        sessionId: sessionId,
      ),
      {AppDataArea.attendance},
    );
  }

  // Attendance Records
  @override
  Future<List<AttendanceRecordEntity>> getAttendanceRecords(
    String sessionId,
  ) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('attendance_records')
            .select()
            .eq('session_id', sessionId);
        final records = (rows as List)
            .map((json) => AttendanceRecordEntity.fromJson(json))
            .toList();

        try {
          await _writeOfflineAttendanceCache(sessionId, {
            for (final record in records) record.memberId: record.status,
          });
        } catch (_) {}

        return records;
      },
      offline: () async => _readCachedAttendanceRecords(sessionId),
    );
  }

  @override
  Future<List<MemberAttendanceHistoryEntry>> getMemberAttendanceHistory(
    String memberId,
  ) async {
    final cacheKey = 'offline_member_attendance_history_$memberId';

    return OfflineNetworkPolicy.run(
      online: () async {
        final recordRows = await _client
            .from('attendance_records')
            .select('id, session_id, status, notes')
            .eq('member_id', memberId);
        final records = List<Map<String, dynamic>>.from(recordRows as List);
        if (records.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, '[]');
          return [];
        }

        final sessionIds = records
            .map((row) => row['session_id'] as String)
            .toSet()
            .toList();
        final sessionRows = await _client
            .from('attendance_sessions')
            .select('id, meeting_id, class_id, session_date, title')
            .inFilter('id', sessionIds);
        final sessionsById = {
          for (final row in List<Map<String, dynamic>>.from(
            sessionRows as List,
          ))
            row['id'] as String: row,
        };

        final history = <MemberAttendanceHistoryEntry>[];
        for (final record in records) {
          final session = sessionsById[record['session_id'] as String];
          if (session == null) continue;
          history.add(
            MemberAttendanceHistoryEntry(
              recordId: record['id'] as String,
              sessionId: record['session_id'] as String,
              meetingId: session['meeting_id'] as String,
              classId: session['class_id'] as String?,
              sessionDate: DateTime.parse(session['session_date'] as String),
              sessionTitle: session['title'] as String?,
              status: AttendanceStatus.fromJson(record['status'] as String),
              notes: record['notes'] as String?,
            ),
          );
        }
        history.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          cacheKey,
          jsonEncode(history.map((entry) => entry.toJson()).toList()),
        );
        return history;
      },
      offline: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(cacheKey);
          if (cached == null) return [];
          final rows = jsonDecode(cached) as List<dynamic>;
          return rows
              .map(
                (row) => MemberAttendanceHistoryEntry.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList();
        } catch (_) {
          return [];
        }
      },
    );
  }

  Future<List<AttendanceRecordEntity>> _readCachedAttendanceRecords(
    String sessionId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'offline_attendance_records_$sessionId';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final parsed = _parseOfflineAttendanceCache(cachedData);
        if (parsed != null) {
          final cachedRecords = <AttendanceRecordEntity>[];
          parsed.statuses.forEach((memberId, status) {
            cachedRecords.add(
              AttendanceRecordEntity(
                id: 'cached_${memberId}_$sessionId',
                sessionId: sessionId,
                memberId: memberId,
                status: status,
              ),
            );
          });
          return cachedRecords;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _saveAttendanceRecordsOnline({
    required String sessionId,
    required Map<String, AttendanceStatus> statusesByMemberId,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }

    final rows = statusesByMemberId.entries
        .map(
          (entry) => {
            'church_id': profile!.churchId!,
            'session_id': sessionId,
            'member_id': entry.key,
            'status': entry.value.value,
            'recorded_by': profile.id,
            'recorded_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    await _client
        .from('attendance_records')
        .upsert(rows, onConflict: 'session_id,member_id');

    final prefs = await SharedPreferences.getInstance();
    final unsynced = prefs.getStringList('offline_unsynced_sessions') ?? [];
    if (unsynced.contains(sessionId)) {
      unsynced.remove(sessionId);
      await prefs.setStringList('offline_unsynced_sessions', unsynced);
    }
    await _writeOfflineAttendanceCache(sessionId, statusesByMemberId);
    return true;
  }

  @override
  Future<bool> saveAttendanceRecords({
    required String sessionId,
    required Map<String, AttendanceStatus> statusesByMemberId,
  }) async {
    try {
      await OfflineNetworkPolicy.ensureReady();
      if (OfflineNetworkPolicy.isConnectivityOffline) {
        throw TimeoutException('offline');
      }
      final resolvedSessionId = await _writeQueue.resolveId(sessionId);
      final remappedStatuses = <String, AttendanceStatus>{};
      for (final entry in statusesByMemberId.entries) {
        remappedStatuses[await _writeQueue.resolveId(entry.key)] = entry.value;
      }
      return await _notifyAfter(
        _saveAttendanceRecordsOnline(
          sessionId: resolvedSessionId,
          statusesByMemberId: remappedStatuses,
        ),
        {AppDataArea.attendance},
      );
    } catch (e) {
      if (!_isRecoverableOfflineError(e)) rethrow;
      try {
        final prefs = await SharedPreferences.getInstance();
        await _writeOfflineAttendanceCache(sessionId, statusesByMemberId);
        final unsynced = prefs.getStringList('offline_unsynced_sessions') ?? [];
        if (!unsynced.contains(sessionId)) {
          unsynced.add(sessionId);
          await prefs.setStringList('offline_unsynced_sessions', unsynced);
        }
        AppDataChanges.instance.notify({AppDataArea.attendance});
        return false;
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<void> _writeOfflineAttendanceCache(
    String sessionId,
    Map<String, AttendanceStatus> statusesByMemberId, {
    DateTime? queuedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'offline_attendance_records_$sessionId';
    final payload = {
      'queued_at': (queuedAt ?? DateTime.now()).toIso8601String(),
      'statuses': statusesByMemberId.map(
        (key, value) => MapEntry(key, value.value),
      ),
    };
    await prefs.setString(cacheKey, jsonEncode(payload));
  }

  ({DateTime queuedAt, Map<String, AttendanceStatus> statuses})?
  _parseOfflineAttendanceCache(String cachedData) {
    final decoded = jsonDecode(cachedData);
    if (decoded is Map<String, dynamic> && decoded['statuses'] is Map) {
      final statuses = <String, AttendanceStatus>{};
      (decoded['statuses'] as Map).forEach((memberId, statusStr) {
        statuses['$memberId'] = AttendanceStatus.fromJson(statusStr as String);
      });
      final queuedAt =
          DateTime.tryParse(decoded['queued_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return (queuedAt: queuedAt, statuses: statuses);
    }

    if (decoded is Map<String, dynamic>) {
      final statuses = <String, AttendanceStatus>{};
      decoded.forEach((memberId, statusStr) {
        if (memberId == 'queued_at') return;
        statuses[memberId] = AttendanceStatus.fromJson(statusStr as String);
      });
      return (
        queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
        statuses: statuses,
      );
    }
    return null;
  }

  // Reports
  @override
  Future<List<FollowUpEntity>> getMemberFollowUps(String memberId) async {
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('follow_ups')
            .select()
            .eq('member_id', memberId)
            .order('follow_up_date', ascending: false);
        return (rows as List)
            .map((json) => FollowUpEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final churchId = await _cachedChurchIdForCurrentUser();
        if (churchId == null) return [];
        final cached = await _offlineCache.readFollowUps(churchId) ?? [];
        return cached.where((item) => item.memberId == memberId).toList();
      },
    );
  }

  @override
  Future<List<FollowUpEntity>> getAllFollowUps() async {
    final profile = await getCurrentProfile();
    if (profile == null || profile.churchId == null) return [];

    final churchId = profile.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('follow_ups')
            .select()
            .eq('church_id', churchId)
            .order('follow_up_date', ascending: false);
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveFollowUps(churchId, filteredRows);
        return filteredRows
            .map((json) => FollowUpEntity.fromJson(json))
            .toList();
      },
      offline: () async {
        final followUps = await _offlineCache.readFollowUps(churchId) ?? [];
        return _filterDeletedEntities(
          followUps,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<bool> addFollowUp({
    required String memberId,
    String? sessionId,
    String? reason,
    required String contactStatus,
    String? result,
    String? responsibleUserId,
    required DateTime followUpDate,
  }) async {
    final profile = await getCurrentProfile();
    if (profile == null || profile.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.addFollowUp(
        churchId: profile.churchId!,
        createdBy: profile.id,
        memberId: memberId,
        sessionId: sessionId,
        reason: reason,
        contactStatus: contactStatus,
        result: result,
        responsibleUserId: responsibleUserId,
        followUpDate: followUpDate,
      ),
      {AppDataArea.followUps},
    );
  }

  @override
  Future<bool> deleteFollowUp(String id) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return _notifyAfter(_offlineWriter.deleteFollowUp(profile!.churchId!, id), {
      AppDataArea.followUps,
    });
  }

  // Reports
  @override
  Future<List<Map<String, dynamic>>> getAttendanceReportStats() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('member_attendance_stats')
            .select()
            .eq('church_id', churchId);
        final stats = List<Map<String, dynamic>>.from(rows as List);
        await _offlineCache.saveReportStats(churchId, stats);
        return stats;
      },
      offline: () async {
        return await _offlineCache.readReportStats(churchId) ?? [];
      },
    );
  }

  // Helper Invitations
  @override
  Future<OfflineSaveResult<InvitationCreateResult>> createInvitation({
    required String fullName,
    String? email,
    String? phone,
    required AppRole role,
    String? targetId,
    String? assignmentScope,
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    final normalizedRole =
        role == AppRole.churchAdmin ||
            role == AppRole.superAdmin ||
            assignmentScope == null
        ? role
        : assignmentScope == 'meeting'
        ? AppRole.attendanceOfficer
        : AppRole.classLeader;
    return _notifyAfter(
      _offlineWriter.createInvitation(
        churchId: profile!.churchId!,
        fullName: fullName,
        email: email,
        phone: phone,
        role: normalizedRole,
        targetId: targetId,
        assignmentScope: assignmentScope,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
      ),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }

  @override
  Future<void> sendInvitationEmail(String invitationId) async {
    try {
      final response = await _client.functions.invoke(
        'send-invitation-email',
        body: {'invitation_id': invitationId},
      );
      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw Exception(invitationEmailErrorMessage(data));
      }
    } on FunctionException catch (error) {
      throw Exception(invitationEmailErrorMessage(error));
    }
  }

  @override
  Future<List<HelperInvitation>> getInvitations() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('invitations')
            .select()
            .eq('church_id', churchId)
            .eq('is_used', false)
            .isFilter('declined_at', null)
            .order('created_at', ascending: false);
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        final invitations = filteredRows
            .map((json) => HelperInvitation.fromJson(json))
            .where((invite) => invite.isPending)
            .toList();
        await _offlineCache.saveInvitations(
          churchId,
          invitations.map(invitationToJson).toList(),
        );
        return invitations;
      },
      offline: () async {
        final cached = await _offlineCache.readInvitations(churchId) ?? [];
        return _filterDeletedEntities(
          cached.where((item) => item.isPending).toList(),
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<bool> updateInvitation({
    required HelperInvitation invitation,
    required String fullName,
    String? email,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.updateInvitation(
        invitation: invitation,
        fullName: fullName,
        email: email,
      ),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }

  @override
  Future<bool> deleteInvitation(String id) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.deleteInvitation(profile!.churchId!, id),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }

  // Realtime Sync
  @override
  Stream<List<AttendanceRecordEntity>> subscribeToAttendanceRecords(
    String sessionId,
  ) async* {
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      yield await _readCachedAttendanceRecords(sessionId);
      return;
    }
    try {
      await for (final rows
          in _client
              .from('attendance_records')
              .stream(primaryKey: ['id'])
              .eq('session_id', sessionId)) {
        yield rows.map((row) => AttendanceRecordEntity.fromJson(row)).toList();
      }
    } catch (_) {
      yield await _readCachedAttendanceRecords(sessionId);
    }
  }

  // Offline Auto-Sync Queue — handled by OfflineWriteHandler.syncAll()

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
