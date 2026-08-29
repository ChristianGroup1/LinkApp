part of 'database_repository.dart';

mixin _SupabaseServantsRepository on _SupabaseRepositoryBase {
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
}
