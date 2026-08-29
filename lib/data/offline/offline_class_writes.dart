part of 'offline_write_handler.dart';

mixin _OfflineClassWrites on _OfflineWriteHandlerBase {
  Future<OfflineSaveResult<SundaySchoolClassEntity>> createSundaySchoolClass({
    required String churchId,
    required String meetingId,
    required String name,
    required String nameAr,
    required int displayOrder,
  }) async {
    final resolvedMeetingId = await queue.resolveId(meetingId);
    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('sunday_school_classes')
          .insert({
            'church_id': churchId,
            'meeting_id': resolvedMeetingId,
            'name': name,
            'name_ar': nameAr,
            'display_order': displayOrder,
            'is_active': true,
          })
          .select()
          .single();
      final cls = SundaySchoolClassEntity.fromJson(row);
      await cache.upsertClass(churchId, cls);
      return OfflineSaveResult(data: cls, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final localId = await queue.generateId('class');
      final cls = SundaySchoolClassEntity(
        id: localId,
        churchId: churchId,
        meetingId: meetingId,
        name: name,
        nameAr: nameAr,
        displayOrder: displayOrder,
        isActive: true,
      );
      await cache.upsertClass(churchId, cls);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.classCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'meeting_id': meetingId,
            'name': name,
            'name_ar': nameAr,
            'display_order': displayOrder,
            'is_active': true,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: cls, syncedToServer: false);
    }
  }

  Future<OfflineSaveResult<SundaySchoolClassEntity>> updateSundaySchoolClass({
    required String churchId,
    required String id,
    required String name,
    required String nameAr,
    required int displayOrder,
    required bool isActive,
  }) async {
    final classes = await cache.readClasses(churchId) ?? [];
    final resolvedId = await queue.resolveId(id);
    final existing = classes
        .where((item) => item.id == id || item.id == resolvedId)
        .firstOrNull;

    if (isOfflineId(id) && resolvedId == id && existing != null) {
      final cls = SundaySchoolClassEntity(
        id: id,
        churchId: churchId,
        meetingId: existing.meetingId,
        name: name,
        nameAr: nameAr,
        displayOrder: displayOrder,
        isActive: isActive,
      );
      await cache.upsertClass(churchId, cls);
      await queue.removeByEntityId(id);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.classCreate,
          payload: {
            'local_id': id,
            'church_id': churchId,
            'meeting_id': existing.meetingId,
            'name': name,
            'name_ar': nameAr,
            'display_order': displayOrder,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: cls, syncedToServer: false);
    }

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('sunday_school_classes')
          .update({
            'name': name,
            'name_ar': nameAr,
            'display_order': displayOrder,
            'is_active': isActive,
          })
          .eq('id', resolvedId)
          .select()
          .single();
      final cls = SundaySchoolClassEntity.fromJson(row);
      if (resolvedId != id) await cache.removeClass(churchId, id);
      await cache.upsertClass(churchId, cls);
      return OfflineSaveResult(data: cls, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final cls = SundaySchoolClassEntity(
        id: resolvedId,
        churchId: churchId,
        meetingId: existing?.meetingId ?? '',
        name: name,
        nameAr: nameAr,
        displayOrder: displayOrder,
        isActive: isActive,
      );
      if (resolvedId != id) await cache.removeClass(churchId, id);
      await cache.upsertClass(churchId, cls);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.classUpdate,
          payload: {
            'id': resolvedId,
            'name': name,
            'name_ar': nameAr,
            'display_order': displayOrder,
            'is_active': isActive,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: cls, syncedToServer: false);
    }
  }

  Future<bool> deleteSundaySchoolClass(String churchId, String id) async {
    final resolvedId = await queue.resolveId(id);
    if (isOfflineId(id) && resolvedId == id) {
      await cache.removeClass(churchId, id);
      await queue.removeByEntityId(id);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.classDelete,
        id: resolvedId,
        removeFromCache: () async {
          await cache.removeClass(churchId, id);
          if (resolvedId != id) {
            await cache.removeClass(churchId, resolvedId);
          }
        },
      );
      return false;
    }

    try {
      await client.rpc(
        'delete_sunday_school_class_cascade',
        params: {'target_class_id': resolvedId},
      );
      await cache.removeClass(churchId, id);
      if (resolvedId != id) await cache.removeClass(churchId, resolvedId);
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeClass(churchId, id);
      if (resolvedId != id) await cache.removeClass(churchId, resolvedId);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.classDelete,
          payload: {'id': resolvedId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
