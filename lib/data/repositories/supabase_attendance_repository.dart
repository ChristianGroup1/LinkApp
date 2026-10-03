part of 'database_repository.dart';

mixin _SupabaseAttendanceRepository on _SupabaseRepositoryBase {
  // Attendance Sessions
  @override
  Future<List<AttendanceSessionEntity>> getSessions(
    String meetingId, {
    String? classId,
  }) => _joinReadRequest(
    'attendance-sessions:${_client.auth.currentUser?.id ?? "signed-out"}:$meetingId:${classId ?? "meeting"}',
    () => _loadSessions(meetingId, classId: classId),
  );

  Future<List<AttendanceSessionEntity>> _loadSessions(
    String meetingId, {
    String? classId,
  }) async {
    final pendingDeletes = await _pendingDeletedEntityIds();

    Future<List<AttendanceSessionEntity>> fromCache() async {
      final sessions =
          await _offlineCache.readSessions(meetingId, classId) ?? [];
      return _filterDeletedEntities(
        sessions,
        (item) => item.id,
        pendingDeletes,
      );
    }

    // Offline-created parents are not valid server UUIDs.
    if (isOfflineId(meetingId) ||
        (classId != null && isOfflineId(classId))) {
      return fromCache();
    }

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
        // Preserve the latest local lock decision until its RPC is synced.
        final pendingLocks = (await _writeQueue.all()).where(
          (op) => op.type == OfflineOpType.sessionLockState,
        );
        for (final op in pendingLocks) {
          final id = await _writeQueue.resolveId(op.payload['id'] as String);
          for (final row in filteredRows) {
            if (row['id'] == id) {
              row['is_locked'] = op.payload['is_locked'];
              row['locked_at'] = op.payload['locked_at'];
              row['locked_by'] = op.payload['locked_by'];
            }
          }
        }
        final remote = filteredRows
            .map((json) => AttendanceSessionEntity.fromJson(json))
            .toList();
        return _offlineCache.mergeAndSaveSessions(
          meetingId,
          classId,
          remote,
          pendingDeletes: pendingDeletes,
        );
      },
      offline: fromCache,
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

  @override
  Future<OfflineSaveResult<AttendanceSessionEntity>> lockAttendanceSession(
    AttendanceSessionEntity session,
  ) => _setAttendanceSessionLock(session, lock: true);

  @override
  Future<OfflineSaveResult<AttendanceSessionEntity>> unlockAttendanceSession(
    AttendanceSessionEntity session,
  ) => _setAttendanceSessionLock(session, lock: false);

  Future<OfflineSaveResult<AttendanceSessionEntity>> _setAttendanceSessionLock(
    AttendanceSessionEntity session, {
    required bool lock,
  }) async {
    await OfflineNetworkPolicy.ensureReady();
    final resolvedId = await _writeQueue.resolveId(session.id);
    final prefs = await SharedPreferences.getInstance();
    final unsyncedSessions =
        prefs.getStringList(OfflineCache.unsyncedSessionsKey) ?? [];
    final hasPendingAttendance =
        unsyncedSessions.contains(session.id) ||
        unsyncedSessions.contains(resolvedId);
    final hasPendingLock = (await _writeQueue.all()).any(
      (op) =>
          op.type == OfflineOpType.sessionLockState &&
          (op.payload['id'] == session.id || op.payload['id'] == resolvedId),
    );

    if (OfflineNetworkPolicy.isConnectivityOffline ||
        hasPendingAttendance ||
        hasPendingLock ||
        isOfflineId(session.id)) {
      final updated = _attendanceSessionWithLock(session, lock: lock);
      await _queueAttendanceSessionLock(session, updated);
      await _offlineCache.upsertSession(
        session.meetingId,
        session.classId,
        updated,
      );
      _notifyDataChanged({AppDataArea.attendance});
      if (!OfflineNetworkPolicy.isConnectivityOffline) {
        _scheduleQueuedAttendanceLockSync();
      }
      return OfflineSaveResult(data: updated, syncedToServer: false);
    }

    try {
      final row = await _client.rpc(
        lock ? 'lock_attendance_session' : 'unlock_attendance_session',
        params: {'target_session_id': resolvedId},
      );
      final updated = AttendanceSessionEntity.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      await _offlineCache.upsertSession(
        updated.meetingId,
        updated.classId,
        updated,
      );
      _notifyDataChanged({AppDataArea.attendance});
      return OfflineSaveResult(data: updated, syncedToServer: true);
    } catch (error) {
      if (!_isRecoverableOfflineError(error)) rethrow;
      final updated = _attendanceSessionWithLock(session, lock: lock);
      await _queueAttendanceSessionLock(session, updated);
      await _offlineCache.upsertSession(
        session.meetingId,
        session.classId,
        updated,
      );
      _notifyDataChanged({AppDataArea.attendance});
      if (!OfflineNetworkPolicy.isConnectivityOffline) {
        _scheduleQueuedAttendanceLockSync();
      }
      return OfflineSaveResult(data: updated, syncedToServer: false);
    }
  }

  void _scheduleQueuedAttendanceLockSync() {
    final syncWasAlreadyRunning = _offlineSyncInFlight != null;
    unawaited(
      syncPendingOfflineData()
          .then((_) async {
            // A sync already in progress may have taken its queue snapshot
            // before this lock was added. Run one more pass in that case.
            if (syncWasAlreadyRunning && await hasPendingOfflineData()) {
              await syncPendingOfflineData();
            }
          })
          .catchError((_) {}),
    );
  }

  AttendanceSessionEntity _attendanceSessionWithLock(
    AttendanceSessionEntity session, {
    required bool lock,
  }) => AttendanceSessionEntity(
    id: session.id,
    churchId: session.churchId,
    meetingId: session.meetingId,
    classId: session.classId,
    sessionDate: session.sessionDate,
    weekNumber: session.weekNumber,
    title: session.title,
    isLocked: lock,
    lockedAt: lock ? (session.lockedAt ?? DateTime.now()) : null,
    lockedBy: lock ? (session.lockedBy ?? _client.auth.currentUser?.id) : null,
  );

  Future<void> _queueAttendanceSessionLock(
    AttendanceSessionEntity previous,
    AttendanceSessionEntity updated,
  ) async {
    await _writeQueue.setAttendanceSessionLock(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: OfflineOpType.sessionLockState,
        payload: {
          ...sessionToJson(updated),
          'previous_is_locked': previous.isLocked,
          'previous_session': sessionToJson(previous),
          'is_locked': updated.isLocked,
        },
        queuedAt: DateTime.now(),
      ),
    );
  }

  // Attendance Records
  @override
  Future<List<AttendanceRecordEntity>> getAttendanceRecords(
    String sessionId,
  ) => _joinReadRequest(
    'attendance-records:${_client.auth.currentUser?.id ?? "signed-out"}:$sessionId',
    () => _loadAttendanceRecords(sessionId),
  );

  Future<List<AttendanceRecordEntity>> _loadAttendanceRecords(
    String sessionId,
  ) async {
    if (isOfflineId(sessionId)) {
      return _readCachedAttendanceRecords(sessionId);
    }

    final prefs = await SharedPreferences.getInstance();
    final unsynced =
        prefs.getStringList(OfflineCache.unsyncedSessionsKey) ?? [];
    // Never let a server read wipe marks that are still waiting to upload.
    if (unsynced.contains(sessionId) ||
        unsynced.contains(await _writeQueue.resolveId(sessionId))) {
      return _readCachedAttendanceRecords(sessionId);
    }

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
      fallbackOnTimeout: true,
    );
  }

  @override
  Future<List<MemberAttendanceHistoryEntry>> getMemberAttendanceHistory(
    String memberId,
  ) async {
    final cacheKey = 'offline_member_attendance_history_$memberId';

    if (isOfflineId(memberId)) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return [];
        return decoded
            .map(
              (row) => MemberAttendanceHistoryEntry.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
      } on FormatException {
        return [];
      } on TypeError {
        return [];
      }
    }

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
      final cacheKey = '${OfflineCache.attendanceRecordsPrefix}$sessionId';
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
    final unsynced =
        prefs.getStringList(OfflineCache.unsyncedSessionsKey) ?? [];
    if (unsynced.contains(sessionId)) {
      unsynced.remove(sessionId);
      await prefs.setStringList(OfflineCache.unsyncedSessionsKey, unsynced);
    }
    await _writeOfflineAttendanceCache(sessionId, statusesByMemberId);
    return true;
  }

  @override
  Future<bool> saveAttendanceRecords({
    required String sessionId,
    required Map<String, AttendanceStatus> statusesByMemberId,
  }) async {
    Future<bool> saveLocally() async {
      final prefs = await SharedPreferences.getInstance();
      await _writeOfflineAttendanceCache(sessionId, statusesByMemberId);
      final unsynced =
          prefs.getStringList(OfflineCache.unsyncedSessionsKey) ?? [];
      if (!unsynced.contains(sessionId)) {
        unsynced.add(sessionId);
        await prefs.setStringList(OfflineCache.unsyncedSessionsKey, unsynced);
      }
      _notifyDataChanged({AppDataArea.attendance});
      return false;
    }

    try {
      await OfflineNetworkPolicy.ensureReady();
      final resolvedSessionId = await _writeQueue.resolveId(sessionId);
      // Session (or its parent chain) is still local-only — don't hit Supabase.
      if (OfflineNetworkPolicy.isConnectivityOffline ||
          isOfflineId(resolvedSessionId)) {
        return saveLocally();
      }
      final remappedStatuses = <String, AttendanceStatus>{};
      for (final entry in statusesByMemberId.entries) {
        remappedStatuses[await _writeQueue.resolveId(entry.key)] = entry.value;
      }
      // Still-local member ids cannot be upserted until memberCreate syncs.
      if (remappedStatuses.keys.any(isOfflineId)) {
        return saveLocally();
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
        return await saveLocally();
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
    final cacheKey = '${OfflineCache.attendanceRecordsPrefix}$sessionId';
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
