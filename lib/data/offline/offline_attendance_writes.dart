part of 'offline_write_handler.dart';

mixin _OfflineAttendanceWrites on _OfflineWriteHandlerBase {
  Future<OfflineSaveResult<AttendanceSessionEntity>> createWeeklySession({
    required String churchId,
    required String meetingId,
    String? classId,
    required DateTime sessionDate,
    required int weekNumber,
    String? title,
  }) async {
    final resolvedMeetingId = await queue.resolveId(meetingId);
    final resolvedClassId = classId == null
        ? null
        : await queue.resolveId(classId);
    try {
      await _throwIfKnownOffline();
      final row = await client.rpc(
        'create_attendance_session',
        params: {
          'target_meeting_id': resolvedMeetingId,
          'target_class_id': resolvedClassId,
          'target_session_date': sessionDate.toIso8601String().split('T').first,
          'target_week_number': weekNumber,
          'target_title': emptyToNull(title),
        },
      );
      final session = AttendanceSessionEntity.fromJson(row);
      await cache.upsertSession(meetingId, classId, session);
      return OfflineSaveResult(data: session, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final localId = await queue.generateId('session');
      final session = AttendanceSessionEntity(
        id: localId,
        churchId: churchId,
        meetingId: meetingId,
        classId: classId,
        sessionDate: sessionDate,
        weekNumber: weekNumber,
        title: emptyToNull(title),
      );
      await cache.upsertSession(meetingId, classId, session);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.sessionCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'meeting_id': meetingId,
            'class_id': classId,
            'session_date': sessionDate.toIso8601String().split('T').first,
            'week_number': weekNumber,
            'title': emptyToNull(title),
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: session, syncedToServer: false);
    }
  }

  Future<bool> deleteWeeklySession({
    required String meetingId,
    String? classId,
    required String sessionId,
  }) async {
    final resolvedSessionId = await queue.resolveId(sessionId);
    if (isOfflineId(sessionId) && resolvedSessionId == sessionId) {
      await cache.removeSession(meetingId, classId, sessionId);
      await queue.removeByEntityId(sessionId);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.sessionDelete,
        id: resolvedSessionId,
        removeFromCache: () async {
          await cache.removeSession(meetingId, classId, sessionId);
          if (resolvedSessionId != sessionId) {
            await cache.removeSession(meetingId, classId, resolvedSessionId);
          }
        },
      );
      return false;
    }

    try {
      await client
          .from('attendance_sessions')
          .delete()
          .eq('id', resolvedSessionId);
      await cache.removeSession(meetingId, classId, sessionId);
      if (resolvedSessionId != sessionId) {
        await cache.removeSession(meetingId, classId, resolvedSessionId);
      }
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeSession(meetingId, classId, sessionId);
      if (resolvedSessionId != sessionId) {
        await cache.removeSession(meetingId, classId, resolvedSessionId);
      }
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.sessionDelete,
          payload: {'id': resolvedSessionId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
