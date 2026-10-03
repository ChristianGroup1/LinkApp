part of 'offline_write_handler.dart';

mixin _OfflineFollowUpWrites on _OfflineWriteHandlerBase {
  Future<bool> addFollowUp({
    required String churchId,
    required String createdBy,
    required String memberId,
    String? sessionId,
    String? reason,
    required String contactStatus,
    String? result,
    String? responsibleUserId,
    required DateTime followUpDate,
    String activityType = 'absence_follow_up',
  }) async {
    final resolvedMemberId = await queue.resolveId(memberId);
    final resolvedSessionId = sessionId == null
        ? null
        : await queue.resolveId(sessionId);
    try {
      await _throwIfKnownOffline();
      await client.from('follow_ups').insert({
        'church_id': churchId,
        'member_id': resolvedMemberId,
        'session_id': resolvedSessionId,
        'reason': emptyToNull(reason),
        'contact_status': contactStatus,
        'result': emptyToNull(result),
        'responsible_user_id': responsibleUserId,
        'follow_up_date': followUpDate.toIso8601String().split('T').first,
        'activity_type': activityType,
        'created_by': createdBy,
      });
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final localId = await queue.generateId('followup');
      final followUp = FollowUpEntity(
        id: localId,
        churchId: churchId,
        memberId: memberId,
        sessionId: sessionId,
        reason: emptyToNull(reason),
        contactStatus: contactStatus,
        result: emptyToNull(result),
        responsibleUserId: responsibleUserId,
        followUpDate: followUpDate,
        activityType: activityType,
      );
      await cache.upsertFollowUp(churchId, followUp);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.followUpCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'created_by': createdBy,
            'member_id': memberId,
            'session_id': sessionId,
            'reason': emptyToNull(reason),
            'contact_status': contactStatus,
            'result': emptyToNull(result),
            'responsible_user_id': responsibleUserId,
            'follow_up_date': followUpDate.toIso8601String().split('T').first,
            'activity_type': activityType,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }

  Future<bool> updateFollowUp(FollowUpEntity followUp) async {
    final payload = {
      'id': followUp.id,
      'church_id': followUp.churchId,
      'member_id': followUp.memberId,
      'session_id': followUp.sessionId,
      'reason': emptyToNull(followUp.reason),
      'contact_status': followUp.contactStatus,
      'result': emptyToNull(followUp.result),
      'responsible_user_id': followUp.responsibleUserId,
      'follow_up_date': followUp.followUpDate
          .toIso8601String()
          .split('T')
          .first,
      'activity_type': followUp.activityType,
    };
    final resolvedId = await queue.resolveId(followUp.id);
    final pending = await queue.all();
    final mustQueue =
        (isOfflineId(resolvedId)) ||
        pending.any(
          (op) =>
              op.type == OfflineOpType.followUpUpdate &&
              op.payload['id'] == followUp.id,
        );
    if (!mustQueue) {
      try {
        await _throwIfKnownOffline();
        final update = Map<String, dynamic>.from(payload)..remove('id');
        update['member_id'] = await queue.resolveId(followUp.memberId);
        if (followUp.sessionId != null) {
          update['session_id'] = await queue.resolveId(followUp.sessionId!);
        }
        final row = await client
            .from('follow_ups')
            .update(update)
            .eq('id', resolvedId)
            .eq('church_id', followUp.churchId)
            .select()
            .single();
        await cache.upsertFollowUp(
          followUp.churchId,
          FollowUpEntity.fromJson(row),
        );
        return true;
      } catch (error) {
        if (!isRecoverableOfflineError(error)) rethrow;
      }
    }
    await queue.enqueue(
      QueuedOperation(
        id: await queue.generateId('op'),
        type: OfflineOpType.followUpUpdate,
        payload: payload,
        queuedAt: DateTime.now(),
      ),
    );
    await cache.upsertFollowUp(followUp.churchId, followUp);
    return false;
  }

  Future<bool> deleteFollowUp(String churchId, String id) async {
    final resolvedId = await queue.resolveId(id);
    if (isOfflineId(id) && resolvedId == id) {
      await cache.removeFollowUp(churchId, id);
      await queue.removeByEntityId(id);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.followUpDelete,
        id: resolvedId,
        removeFromCache: () async {
          await cache.removeFollowUp(churchId, id);
          if (resolvedId != id) {
            await cache.removeFollowUp(churchId, resolvedId);
          }
        },
      );
      return false;
    }

    try {
      final deleted = await client
          .from('follow_ups')
          .delete()
          .eq('id', resolvedId)
          .eq('church_id', churchId)
          .select('id');
      if (deleted.isEmpty) {
        throw StateError('تعذر الحذف: تحقق من الصلاحيات أو حدّث القائمة');
      }
      await cache.removeFollowUp(churchId, id);
      if (resolvedId != id) await cache.removeFollowUp(churchId, resolvedId);
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeFollowUp(churchId, id);
      if (resolvedId != id) await cache.removeFollowUp(churchId, resolvedId);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.followUpDelete,
          payload: {'id': resolvedId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
