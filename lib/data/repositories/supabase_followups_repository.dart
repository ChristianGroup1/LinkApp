part of 'database_repository.dart';

mixin _SupabaseFollowUpsRepository on _SupabaseRepositoryBase {
  // Follow-ups
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

  @override
  Stream<List<FollowUpEntity>> subscribeToFollowUps() {
    return _streamTable(
      table: 'follow_ups',
      fromJson: FollowUpEntity.fromJson,
      offlineFallback: _readCachedFollowUps,
    );
  }
}
