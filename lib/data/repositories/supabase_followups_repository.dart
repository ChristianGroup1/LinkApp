part of 'database_repository.dart';

mixin _SupabaseFollowUpsRepository on _SupabaseRepositoryBase {
  // Follow-ups
  @override
  Future<List<FollowUpEntity>> getMemberFollowUps(String memberId) async {
    Future<List<FollowUpEntity>> fromCache() async {
      final churchId = await _cachedChurchIdForCurrentUser();
      if (churchId == null) return [];
      final cached = await _offlineCache.readFollowUps(churchId) ?? [];
      return cached.where((item) => item.memberId == memberId).toList();
    }

    if (isOfflineId(memberId)) return fromCache();

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
      offline: fromCache,
      fallbackOnTimeout: true,
    );
  }

  @override
  Future<List<FollowUpEntity>> getAllFollowUps() => _joinReadRequest(
    'follow-ups:${_client.auth.currentUser?.id ?? "signed-out"}',
    _loadAllFollowUps,
  );

  Future<List<FollowUpEntity>> _loadAllFollowUps() async {
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
        final merged = {
          for (final row in filteredRows)
            row['id'] as String: FollowUpEntity.fromJson(row),
        };
        // Keep queued edits visible when connectivity returns before sync finishes.
        final pendingIds = await getPendingFollowUpIds();
        final cached = await _offlineCache.readFollowUps(churchId) ?? [];
        await _offlineCache.saveFollowUps(churchId, filteredRows);
        for (final item in cached) {
          if (pendingIds.contains(item.id) &&
              !pendingDeletes.contains(item.id)) {
            final resolvedId = await _writeQueue.resolveId(item.id);
            merged.remove(resolvedId);
            merged[item.id] = item;
            await _offlineCache.upsertFollowUp(churchId, item);
          }
        }
        return merged.values.toList();
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
    String activityType = 'absence_follow_up',
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
        activityType: activityType,
      ),
      {AppDataArea.followUps},
    );
  }

  @override
  Future<Set<String>> getPendingFollowUpIds() async {
    final operations = await _writeQueue.all();
    final ids = <String>{};
    for (final op in operations) {
      if (op.type != OfflineOpType.followUpCreate &&
          op.type != OfflineOpType.followUpUpdate) {
        continue;
      }
      final id = (op.payload['local_id'] ?? op.payload['id']) as String;
      ids.add(id);
      ids.add(await _writeQueue.resolveId(id));
    }
    return ids;
  }

  @override
  Future<bool> updateFollowUp(FollowUpEntity followUp) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId != followUp.churchId) {
      throw StateError('الزيارة غير مرتبطة بالكنيسة الحالية');
    }
    return _notifyAfter(_offlineWriter.updateFollowUp(followUp), {
      AppDataArea.followUps,
    });
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
  Future<List<Map<String, dynamic>>>
  getAttendanceReportStats() => _joinReadRequest(
    'attendance-report-stats:${_client.auth.currentUser?.id ?? "signed-out"}',
    _loadAttendanceReportStats,
  );

  Future<List<Map<String, dynamic>>> _loadAttendanceReportStats() async {
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
