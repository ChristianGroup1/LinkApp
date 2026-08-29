part of 'database_repository.dart';

mixin _SupabaseAttendanceRepository on _SupabaseRepositoryBase {
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

  @override
  Stream<List<AttendanceRecordEntity>> subscribeToAttendanceRecords(
    String sessionId,
  ) {
    return _streamTable(
      table: 'attendance_records',
      fromJson: AttendanceRecordEntity.fromJson,
      offlineFallback: () => _readCachedAttendanceRecords(sessionId),
      filterColumn: 'session_id',
      filterValue: sessionId,
    );
  }
}
