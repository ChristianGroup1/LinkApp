part of 'offline_write_handler.dart';

mixin _OfflineChurchMeetingWrites on _OfflineWriteHandlerBase {
  Future<bool> updateChurch(
    String churchId,
    String nameAr,
    String? phone,
    String? address,
  ) async {
    try {
      await _throwIfKnownOffline();
      await client
          .from('churches')
          .update({'name_ar': nameAr, 'phone': phone, 'address': address})
          .eq('id', churchId);
      final existing = await cache.readChurch(churchId);
      if (existing != null) {
        await cache.saveChurch(
          churchId,
          churchToJson(
            Church(
              id: existing.id,
              name: existing.name,
              nameAr: nameAr,
              slug: existing.slug,
              phone: phone,
              address: address,
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final existing = await cache.readChurch(churchId);
      if (existing != null) {
        await cache.saveChurch(
          churchId,
          churchToJson(
            Church(
              id: existing.id,
              name: existing.name,
              nameAr: nameAr,
              slug: existing.slug,
              phone: phone,
              address: address,
            ),
          ),
        );
      }
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.churchUpdate,
          payload: {
            'church_id': churchId,
            'name_ar': nameAr,
            'phone': phone,
            'address': address,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }

  Future<OfflineSaveResult<MeetingEntity>> createMeeting({
    required String churchId,
    required String createdBy,
    required String name,
    required String nameAr,
    required MeetingKind kind,
    required int weekday,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('meetings')
          .insert({
            'church_id': churchId,
            'name': name,
            'name_ar': nameAr,
            'kind': kind.value,
            'weekday': weekday,
            'attendance_reminder_minutes': attendanceReminderMinutes,
            'description': description,
            'is_active': true,
            'created_by': createdBy,
          })
          .select()
          .single();
      final meeting = MeetingEntity.fromJson(row);
      await cache.upsertMeeting(churchId, meeting);
      return OfflineSaveResult(data: meeting, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final localId = await queue.generateId('meeting');
      final meeting = MeetingEntity(
        id: localId,
        churchId: churchId,
        name: name,
        nameAr: nameAr,
        kind: kind,
        weekday: weekday,
        isActive: true,
        description: description,
        attendanceReminderMinutes: attendanceReminderMinutes,
      );
      await cache.upsertMeeting(churchId, meeting);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.meetingCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'created_by': createdBy,
            'name': name,
            'name_ar': nameAr,
            'kind': kind.value,
            'weekday': weekday,
            'attendance_reminder_minutes': attendanceReminderMinutes,
            'description': description,
            'is_active': true,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: meeting, syncedToServer: false);
    }
  }

  Future<OfflineSaveResult<MeetingEntity>> updateMeeting({
    required String churchId,
    required String id,
    required String name,
    required String nameAr,
    required int weekday,
    required bool isActive,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final resolvedId = await queue.resolveId(id);
    if (isOfflineId(id) && resolvedId == id) {
      final meetings = await cache.readMeetings(churchId) ?? [];
      final existing = meetings
          .where((item) => item.id == id || item.id == resolvedId)
          .firstOrNull;
      final meeting = MeetingEntity(
        id: id,
        churchId: churchId,
        name: name,
        nameAr: nameAr,
        kind: existing?.kind ?? MeetingKind.normal,
        weekday: weekday,
        isActive: isActive,
        description: description,
        attendanceReminderMinutes: attendanceReminderMinutes,
      );
      await cache.upsertMeeting(churchId, meeting);
      await queue.removeByEntityId(id);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.meetingCreate,
          payload: {
            'local_id': id,
            'church_id': churchId,
            'created_by': (await _requireProfile()).id,
            'name': name,
            'name_ar': nameAr,
            'kind': meeting.kind.value,
            'weekday': weekday,
            'attendance_reminder_minutes': attendanceReminderMinutes,
            'description': description,
            'is_active': isActive,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: meeting, syncedToServer: false);
    }

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('meetings')
          .update({
            'name': name,
            'name_ar': nameAr,
            'weekday': weekday,
            'attendance_reminder_minutes': attendanceReminderMinutes,
            'is_active': isActive,
            'description': description,
          })
          .eq('id', resolvedId)
          .select()
          .single();
      final meeting = MeetingEntity.fromJson(row);
      if (resolvedId != id) await cache.removeMeeting(churchId, id);
      await cache.upsertMeeting(churchId, meeting);
      return OfflineSaveResult(data: meeting, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final existing = (await cache.readMeetings(churchId) ?? [])
          .where((item) => item.id == id || item.id == resolvedId)
          .firstOrNull;
      final meeting = MeetingEntity(
        id: resolvedId,
        churchId: churchId,
        name: name,
        nameAr: nameAr,
        kind: existing?.kind ?? MeetingKind.normal,
        weekday: weekday,
        isActive: isActive,
        description: description,
        attendanceReminderMinutes: attendanceReminderMinutes,
      );
      if (resolvedId != id) await cache.removeMeeting(churchId, id);
      await cache.upsertMeeting(churchId, meeting);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.meetingUpdate,
          payload: {
            'id': resolvedId,
            'name': name,
            'name_ar': nameAr,
            'weekday': weekday,
            'attendance_reminder_minutes': attendanceReminderMinutes,
            'is_active': isActive,
            'description': description,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: meeting, syncedToServer: false);
    }
  }

  Future<bool> deleteMeeting(String churchId, String id) async {
    final resolvedId = await queue.resolveId(id);
    if (isOfflineId(id) && resolvedId == id) {
      await cache.removeMeeting(churchId, id);
      await queue.removeByEntityId(id);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.meetingDelete,
        id: resolvedId,
        removeFromCache: () async {
          await cache.removeMeeting(churchId, id);
          if (resolvedId != id) {
            await cache.removeMeeting(churchId, resolvedId);
          }
        },
      );
      return false;
    }

    try {
      await client.rpc(
        'delete_meeting_cascade',
        params: {'target_meeting_id': resolvedId},
      );
      await cache.removeMeeting(churchId, id);
      if (resolvedId != id) await cache.removeMeeting(churchId, resolvedId);
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeMeeting(churchId, id);
      if (resolvedId != id) await cache.removeMeeting(churchId, resolvedId);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.meetingDelete,
          payload: {'id': resolvedId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
