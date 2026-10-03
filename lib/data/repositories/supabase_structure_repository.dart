part of 'database_repository.dart';

mixin _SupabaseStructureRepository on _SupabaseRepositoryBase {
  // Churches
  @override
  Future<Church?> getChurch(String churchId) => _joinReadRequest(
    'church:${_client.auth.currentUser?.id ?? "signed-out"}:$churchId',
    () => _loadChurch(churchId),
  );

  Future<Church?> _loadChurch(String churchId) async {
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
        return _offlineCache.readChurch(churchId);
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
  Future<List<MeetingEntity>> getMeetings() => _joinReadRequest(
    'meetings:${_client.auth.currentUser?.id ?? "signed-out"}',
    _loadMeetings,
  );

  Future<List<MeetingEntity>> _loadMeetings() async {
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
        final remote = filteredRows
            .map((json) => MeetingEntity.fromJson(json))
            .toList();
        return _offlineCache.mergeAndSaveMeetings(
          churchId,
          remote,
          pendingDeletes: pendingDeletes,
        );
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
  ) => _joinReadRequest(
    'classes:${_client.auth.currentUser?.id ?? "signed-out"}:meeting:$meetingId',
    () => _loadSundaySchoolClasses(meetingId),
  );

  Future<List<SundaySchoolClassEntity>> _loadSundaySchoolClasses(
    String meetingId,
  ) async {
    // Offline-created meetings are not server UUIDs — never query them online.
    if (isOfflineId(meetingId)) {
      final churchId = await _cachedChurchIdForCurrentUser();
      if (churchId == null) return [];
      final cached = await _offlineCache.readClasses(churchId) ?? [];
      return cached.where((item) => item.meetingId == meetingId).toList();
    }

    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('sunday_school_classes')
            .select()
            .eq('meeting_id', meetingId)
            .order('display_order');
        final churchId = await _cachedChurchIdForCurrentUser();
        final remote = (rows as List)
            .map((json) => SundaySchoolClassEntity.fromJson(json))
            .toList();
        if (churchId == null) return remote;
        return _offlineCache.mergeAndSaveClassesForMeeting(
          churchId: churchId,
          meetingId: meetingId,
          remoteForMeeting: remote,
          pendingDeletes: pendingDeletes,
        );
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
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses() =>
      _joinReadRequest(
        'classes:church:${_client.auth.currentUser?.id ?? "signed-out"}',
        _loadAllSundaySchoolClasses,
      );

  Future<List<SundaySchoolClassEntity>> _loadAllSundaySchoolClasses() async {
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
        final remote = filteredRows
            .map((json) => SundaySchoolClassEntity.fromJson(json))
            .toList();
        return _offlineCache.mergeAndSaveClasses(
          churchId,
          remote,
          pendingDeletes: pendingDeletes,
        );
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
}
