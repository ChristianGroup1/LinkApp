part of 'offline_write_handler.dart';

mixin _OfflineMemberWrites on _OfflineWriteHandlerBase {
  Future<OfflineSaveResult<MemberEntity>> createMember({
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    String? notes,
  }) async {
    final profile = await _requireProfile();
    final churchId = profile.churchId!;

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('members')
          .insert({
            'church_id': churchId,
            'full_name': fullName.trim(),
            'scope': scope.value,
            'sunday_school_class_id': scope == MemberScope.sundaySchoolClass
                ? (sundaySchoolClassId == null
                      ? null
                      : await queue.resolveId(sundaySchoolClassId))
                : null,
            'meeting_id': scope == MemberScope.meeting
                ? (meetingId == null ? null : await queue.resolveId(meetingId))
                : null,
            'phone': emptyToNull(phone),
            'parent_name': emptyToNull(parentName),
            'parent_phone': emptyToNull(parentPhone),
            'code': emptyToNull(code),
            'birth_date': _dateOnly(birthDate),
            'notes': emptyToNull(notes),
            'is_active': true,
            'joined_on': DateTime.now().toIso8601String().split('T').first,
          })
          .select(
            '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
          )
          .single();
      final member = MemberEntity.fromJson(row);
      await cache.upsertMember(churchId, member);
      return OfflineSaveResult(data: member, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;

      final localId = await queue.generateId('member');
      final member = MemberEntity(
        id: localId,
        churchId: churchId,
        fullName: fullName.trim(),
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        meetingIds: scope == MemberScope.meeting && meetingId != null
            ? [meetingId]
            : const [],
        phone: emptyToNull(phone),
        parentName: emptyToNull(parentName),
        parentPhone: emptyToNull(parentPhone),
        code: emptyToNull(code),
        birthDate: birthDate,
        notes: emptyToNull(notes),
        isActive: true,
      );
      await cache.upsertMember(churchId, member);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.memberCreate,
          payload: {
            'local_id': localId,
            'church_id': churchId,
            'full_name': fullName.trim(),
            'scope': scope.value,
            'sunday_school_class_id': sundaySchoolClassId,
            'meeting_id': meetingId,
            'phone': emptyToNull(phone),
            'parent_name': emptyToNull(parentName),
            'parent_phone': emptyToNull(parentPhone),
            'code': emptyToNull(code),
            'birth_date': _dateOnly(birthDate),
            'notes': emptyToNull(notes),
            'is_active': true,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: member, syncedToServer: false);
    }
  }

  /// Inserts many members in one server request. Falls back to per-member
  /// queued creates when the device is offline. Throws when the server
  /// rejects the batch, so callers can retry rows individually.
  Future<List<OfflineSaveResult<MemberEntity>>> createMembers(
    List<MemberCreateDraft> drafts,
  ) async {
    if (drafts.isEmpty) return const [];
    final profile = await _requireProfile();
    final churchId = profile.churchId!;

    try {
      await _throwIfKnownOffline();
      final joinedOn = DateTime.now().toIso8601String().split('T').first;
      final payload = <Map<String, dynamic>>[];
      for (final draft in drafts) {
        payload.add({
          'church_id': churchId,
          'full_name': draft.fullName.trim(),
          'scope': draft.scope.value,
          'sunday_school_class_id': draft.scope == MemberScope.sundaySchoolClass
              ? (draft.sundaySchoolClassId == null
                    ? null
                    : await queue.resolveId(draft.sundaySchoolClassId!))
              : null,
          'meeting_id': draft.scope == MemberScope.meeting
              ? (draft.meetingId == null
                    ? null
                    : await queue.resolveId(draft.meetingId!))
              : null,
          'phone': emptyToNull(draft.phone),
          'parent_name': emptyToNull(draft.parentName),
          'parent_phone': emptyToNull(draft.parentPhone),
          'code': emptyToNull(draft.code),
          'birth_date': _dateOnly(draft.birthDate),
          'notes': emptyToNull(draft.notes),
          'is_active': true,
          'joined_on': joinedOn,
        });
      }
      final rows = await client
          .from('members')
          .insert(payload)
          .select(
            '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
          );
      final members = [for (final row in rows) MemberEntity.fromJson(row)];
      for (final member in members) {
        await cache.upsertMember(churchId, member);
      }
      return [
        for (final member in members)
          OfflineSaveResult(data: member, syncedToServer: true),
      ];
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      final results = <OfflineSaveResult<MemberEntity>>[];
      for (final draft in drafts) {
        results.add(
          await createMember(
            fullName: draft.fullName,
            scope: draft.scope,
            sundaySchoolClassId: draft.sundaySchoolClassId,
            meetingId: draft.meetingId,
            phone: draft.phone,
            parentName: draft.parentName,
            parentPhone: draft.parentPhone,
            code: draft.code,
            birthDate: draft.birthDate,
            notes: draft.notes,
          ),
        );
      }
      return results;
    }
  }

  Future<OfflineSaveResult<int>> copyMembersToMeeting({
    required List<String> memberIds,
    required String meetingId,
  }) async {
    final uniqueMemberIds = memberIds.toSet().toList(growable: false);
    if (uniqueMemberIds.isEmpty) {
      return const OfflineSaveResult(data: 0, syncedToServer: true);
    }
    final profile = await _requireProfile();
    final churchId = profile.churchId!;

    Future<void> updateCachedMemberships(String targetMeetingId) async {
      final cachedMembers = await cache.readMembers(churchId) ?? const [];
      final selectedIds = uniqueMemberIds.toSet();
      final updatedMembers = cachedMembers.map((member) {
        if (!selectedIds.contains(member.id) ||
            member.meetingIds.contains(targetMeetingId)) {
          return member;
        }
        return member.copyWith(
          meetingIds: [...member.meetingIds, targetMeetingId],
        );
      }).toList();
      await cache.saveMembers(
        churchId,
        updatedMembers.map(memberToJson).toList(),
      );
    }

    Future<OfflineSaveResult<int>> queueCopy() async {
      await updateCachedMemberships(meetingId);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.memberMeetingCopy,
          payload: {
            'church_id': churchId,
            'meeting_id': meetingId,
            'member_ids': uniqueMemberIds,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(
        data: uniqueMemberIds.length,
        syncedToServer: false,
      );
    }

    try {
      await _throwIfKnownOffline();
      final resolvedMeetingId = await queue.resolveId(meetingId);
      final resolvedMemberIds = <String>[];
      for (final memberId in uniqueMemberIds) {
        final resolvedMemberId = await queue.resolveId(memberId);
        if (isOfflineId(resolvedMemberId)) return queueCopy();
        resolvedMemberIds.add(resolvedMemberId);
      }
      if (isOfflineId(resolvedMeetingId)) return queueCopy();

      await client
          .from('member_meeting_assignments')
          .upsert(
            [
              for (final memberId in resolvedMemberIds)
                {
                  'church_id': churchId,
                  'member_id': memberId,
                  'meeting_id': resolvedMeetingId,
                  'sunday_school_class_id': null,
                  'is_primary': false,
                },
            ],
            onConflict: 'member_id,meeting_id',
            ignoreDuplicates: true,
          );
      await updateCachedMemberships(resolvedMeetingId);
      return OfflineSaveResult(
        data: uniqueMemberIds.length,
        syncedToServer: true,
      );
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      return queueCopy();
    }
  }

  Future<OfflineSaveResult<MemberEntity>> updateMember({
    required String id,
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    required bool isActive,
    String? notes,
  }) async {
    final profile = await _requireProfile();
    final churchId = profile.churchId!;
    final resolvedId = await queue.resolveId(id);
    final resolvedClassId = sundaySchoolClassId == null
        ? null
        : await queue.resolveId(sundaySchoolClassId);
    final resolvedMeetingId = meetingId == null
        ? null
        : await queue.resolveId(meetingId);
    final cachedMembers = await cache.readMembers(churchId) ?? const [];
    final existingMember = cachedMembers
        .where((member) => member.id == resolvedId || member.id == id)
        .firstOrNull;
    final existingMeetingIds = {...?existingMember?.meetingIds};
    if (existingMember?.scope == MemberScope.meeting &&
        existingMember?.meetingId != meetingId) {
      existingMeetingIds.remove(existingMember!.meetingId);
    }
    if (scope == MemberScope.meeting && meetingId != null) {
      existingMeetingIds.add(meetingId);
    }

    if (isOfflineId(id) && resolvedId == id) {
      final member = MemberEntity(
        id: id,
        churchId: churchId,
        fullName: fullName.trim(),
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        meetingIds: existingMeetingIds.toList(growable: false),
        phone: emptyToNull(phone),
        parentName: emptyToNull(parentName),
        parentPhone: emptyToNull(parentPhone),
        code: emptyToNull(code),
        birthDate: birthDate,
        notes: emptyToNull(notes),
        isActive: isActive,
      );
      await cache.upsertMember(churchId, member);
      await queue.removeByEntityId(id);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.memberCreate,
          payload: {
            'local_id': id,
            'church_id': churchId,
            'full_name': fullName.trim(),
            'scope': scope.value,
            'sunday_school_class_id': sundaySchoolClassId,
            'meeting_id': meetingId,
            'phone': emptyToNull(phone),
            'parent_name': emptyToNull(parentName),
            'parent_phone': emptyToNull(parentPhone),
            'code': emptyToNull(code),
            'birth_date': _dateOnly(birthDate),
            'notes': emptyToNull(notes),
            'is_active': isActive,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: member, syncedToServer: false);
    }

    try {
      await _throwIfKnownOffline();
      final row = await client
          .from('members')
          .update({
            'full_name': fullName.trim(),
            'scope': scope.value,
            'sunday_school_class_id': scope == MemberScope.sundaySchoolClass
                ? resolvedClassId
                : null,
            'meeting_id': scope == MemberScope.meeting
                ? resolvedMeetingId
                : null,
            'phone': emptyToNull(phone),
            'parent_name': emptyToNull(parentName),
            'parent_phone': emptyToNull(parentPhone),
            'code': emptyToNull(code),
            'birth_date': _dateOnly(birthDate),
            'notes': emptyToNull(notes),
            'is_active': isActive,
          })
          .eq('id', resolvedId)
          .select(
            '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
          )
          .single();
      final member = MemberEntity.fromJson(row);
      if (resolvedId != id) await cache.removeMember(churchId, id);
      await cache.upsertMember(churchId, member);
      return OfflineSaveResult(data: member, syncedToServer: true);
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;

      final member = MemberEntity(
        id: resolvedId,
        churchId: churchId,
        fullName: fullName.trim(),
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        meetingIds: existingMeetingIds.toList(growable: false),
        phone: emptyToNull(phone),
        parentName: emptyToNull(parentName),
        parentPhone: emptyToNull(parentPhone),
        code: emptyToNull(code),
        birthDate: birthDate,
        notes: emptyToNull(notes),
        isActive: isActive,
      );
      if (resolvedId != id) await cache.removeMember(churchId, id);
      await cache.upsertMember(churchId, member);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.memberUpdate,
          payload: {
            'id': resolvedId,
            'full_name': fullName.trim(),
            'scope': scope.value,
            'sunday_school_class_id': sundaySchoolClassId,
            'meeting_id': meetingId,
            'phone': emptyToNull(phone),
            'parent_name': emptyToNull(parentName),
            'parent_phone': emptyToNull(parentPhone),
            'code': emptyToNull(code),
            'birth_date': _dateOnly(birthDate),
            'notes': emptyToNull(notes),
            'is_active': isActive,
          },
          queuedAt: DateTime.now(),
        ),
      );
      return OfflineSaveResult(data: member, syncedToServer: false);
    }
  }

  Future<bool> deleteMember(String id) async {
    final profile = await _requireProfile();
    final churchId = profile.churchId!;
    final resolvedId = await queue.resolveId(id);

    if (isOfflineId(id) && resolvedId == id) {
      await cache.removeMember(churchId, id);
      await queue.removeByEntityId(id);
      return false;
    }

    if (await _shouldQueueDeleteInsteadOfServerCall()) {
      await _queueEntityDelete(
        type: OfflineOpType.memberDelete,
        id: resolvedId,
        removeFromCache: () => cache.removeMember(churchId, id),
      );
      return false;
    }

    try {
      await client.from('members').delete().eq('id', resolvedId);
      await cache.removeMember(churchId, id);
      if (resolvedId != id) await cache.removeMember(churchId, resolvedId);
      return true;
    } catch (error) {
      if (!isRecoverableOfflineError(error)) rethrow;
      await cache.removeMember(churchId, id);
      await queue.enqueue(
        QueuedOperation(
          id: await queue.generateId('op'),
          type: OfflineOpType.memberDelete,
          payload: {'id': resolvedId},
          queuedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
