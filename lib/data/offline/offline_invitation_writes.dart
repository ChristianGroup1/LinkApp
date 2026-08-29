part of 'offline_write_handler.dart';

mixin _OfflineInvitationWrites on _OfflineWriteHandlerBase {
  Future<OfflineSaveResult<InvitationCreateResult>> createInvitation({
    required String churchId,
    required String fullName,
    String? email,
    String? phone,
    required AppRole role,
    String? targetId,
    String? assignmentScope,
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final code = _generateActivationCode();
    final inviteToken = _generateInviteToken();
    final resolvedTargetId = targetId == null
        ? null
        : await queue.resolveId(targetId);
    final normalizedEmail = emptyToNull(email?.trim());
    final inviteLink = buildInvitationLink(
      inviteToken: inviteToken,
      supabaseUrl: dotenv.env['SUPABASE_URL'],
    );

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('invitations')
          .insert({
            'church_id': churchId,
            'full_name': fullName.trim(),
            'email': normalizedEmail,
            'phone': emptyToNull(phone),
            'role': role.value,
            'target_id': resolvedTargetId,
            'assignment_scope': assignmentScope,
            'can_take_attendance': canTakeAttendance,
            'can_view_reports': canViewReports,
            'code': code,
            'invite_token': inviteToken,
            'is_used': false,
          })
          .select()
          .single();

      final invitation = HelperInvitation.fromJson(row);
      await cache.upsertInvitation(churchId, invitation);
      return OfflineSaveResult(
        data: InvitationCreateResult(
          code: code,
          invitationId: invitation.id,
          inviteToken: inviteToken,
          inviteLink: inviteLink,
        ),
        syncedToServer: true,
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('assignment_scope') ||
          message.contains('can_take_attendance') ||
          message.contains('can_view_reports') ||
          message.contains('invite_token')) {
        throw Exception(
          'قاعدة البيانات تحتاج تحديث الدعوات. شغّل supabase_invitation_link_migration.sql.',
        );
      }
      if (!isRecoverableOfflineError(error)) rethrow;

      final localId = await queue.generateId('invitation');
      final invitation = HelperInvitation(
        id: localId,
        churchId: churchId,
        fullName: fullName.trim(),
        email: normalizedEmail,
        phone: emptyToNull(phone),
        role: role,
        targetId: resolvedTargetId,
        assignmentScope: assignmentScope,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
        code: code,
        inviteToken: inviteToken,
        isUsed: false,
        createdAt: DateTime.now(),
      );
      await cache.upsertInvitation(churchId, invitation);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.invitationCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'full_name': fullName.trim(),
            'email': normalizedEmail,
            'phone': emptyToNull(phone),
            'role': role.value,
            'target_id': targetId,
            'assignment_scope': assignmentScope,
            'can_take_attendance': canTakeAttendance,
            'can_view_reports': canViewReports,
            'code': code,
            'invite_token': inviteToken,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(
        data: InvitationCreateResult(
          code: code,
          invitationId: localId,
          inviteToken: inviteToken,
          inviteLink: inviteLink,
        ),
        syncedToServer: false,
      );
    }
  }

  Future<bool> deleteInvitation(String churchId, String id) async {
    final resolvedId = await queue.resolveId(id);
    if (isOfflineId(id) && resolvedId == id) {
      await cache.removeInvitation(churchId, id);
      await queue.removeByEntityId(id);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.invitationDelete,
        id: resolvedId,
        removeFromCache: () async {
          await cache.removeInvitation(churchId, id);
          if (resolvedId != id) {
            await cache.removeInvitation(churchId, resolvedId);
          }
        },
      );
      return false;
    }

    try {
      await client.from('invitations').delete().eq('id', resolvedId);
      await cache.removeInvitation(churchId, id);
      if (resolvedId != id) {
        await cache.removeInvitation(churchId, resolvedId);
      }
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeInvitation(churchId, id);
      if (resolvedId != id) {
        await cache.removeInvitation(churchId, resolvedId);
      }
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.invitationDelete,
          payload: {'id': resolvedId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }

  Future<bool> updateInvitation({
    required HelperInvitation invitation,
    required String fullName,
    String? email,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = emptyToNull(email?.trim());
    final resolvedId = await queue.resolveId(invitation.id);
    final updated = invitation.copyWith(
      fullName: normalizedName,
      email: normalizedEmail,
    );

    if (isOfflineId(invitation.id) && resolvedId == invitation.id) {
      await cache.upsertInvitation(invitation.churchId, updated);
      await queue.removeByEntityId(invitation.id);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.invitationCreate,
          payload: {
            'local_id': invitation.id,
            'church_id': invitation.churchId,
            'full_name': normalizedName,
            'email': normalizedEmail,
            'phone': invitation.phone,
            'role': invitation.role.value,
            'target_id': invitation.targetId,
            'assignment_scope': invitation.assignmentScope,
            'can_take_attendance': invitation.canTakeAttendance,
            'can_view_reports': invitation.canViewReports,
            'code': invitation.code,
            'invite_token': invitation.inviteToken,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('invitations')
          .update({'full_name': normalizedName, 'email': normalizedEmail})
          .eq('id', resolvedId)
          .eq('church_id', invitation.churchId)
          .eq('is_used', false)
          .select()
          .single();
      await cache.upsertInvitation(
        invitation.churchId,
        HelperInvitation.fromJson(row),
      );
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.upsertInvitation(invitation.churchId, updated);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.invitationUpdate,
          payload: {
            'id': resolvedId,
            'church_id': invitation.churchId,
            'full_name': normalizedName,
            'email': normalizedEmail,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
