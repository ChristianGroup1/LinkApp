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
          },
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
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
      await client.from('follow_ups').delete().eq('id', resolvedId);
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
