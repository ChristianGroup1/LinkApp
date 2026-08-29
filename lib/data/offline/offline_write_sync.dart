part of 'offline_write_handler.dart';

mixin _OfflineWriteSync on _OfflineWriteHandlerBase {
  @override
  Future<void> _syncWriteQueue() async {
    final operations = await queue.all();
    if (operations.isEmpty) return;

    final sorted = [...operations]
      ..sort((a, b) {
        final typeCompare = OfflineOpType.syncOrder
            .indexOf(a.type)
            .compareTo(OfflineOpType.syncOrder.indexOf(b.type));
        if (typeCompare != 0) return typeCompare;
        return a.queuedAt.compareTo(b.queuedAt);
      });

    for (final operation in sorted) {
      try {
        final done = await _processOperation(operation);
        if (done) {
          await queue.remove(operation.id);
        }
      } catch (_) {
        // Keep remaining operations for the next sync attempt.
        break;
      }
    }
  }

  Future<bool> _processOperation(QueuedOperation operation) async {
    switch (operation.type) {
      case OfflineOpType.churchUpdate:
        await client
            .from('churches')
            .update({
              'name_ar': operation.payload['name_ar'],
              'phone': operation.payload['phone'],
              'address': operation.payload['address'],
            })
            .eq('id', operation.payload['church_id']);
        return true;
      case OfflineOpType.meetingCreate:
        final row = await client
            .from('meetings')
            .insert({
              'church_id': operation.payload['church_id'],
              'name': operation.payload['name'],
              'name_ar': operation.payload['name_ar'],
              'kind': operation.payload['kind'],
              'weekday': operation.payload['weekday'],
              'attendance_reminder_minutes':
                  operation.payload['attendance_reminder_minutes'],
              'description': operation.payload['description'],
              'created_by': operation.payload['created_by'],
              'is_active': operation.payload['is_active'] ?? true,
            })
            .select()
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        await cache.removeMeeting(
          operation.payload['church_id'] as String,
          operation.payload['local_id'] as String,
        );
        await cache.upsertMeeting(
          operation.payload['church_id'] as String,
          MeetingEntity.fromJson(row),
        );
        return true;
      case OfflineOpType.meetingUpdate:
        await client
            .from('meetings')
            .update({
              'name': operation.payload['name'],
              'name_ar': operation.payload['name_ar'],
              'weekday': operation.payload['weekday'],
              'attendance_reminder_minutes':
                  operation.payload['attendance_reminder_minutes'],
              'is_active': operation.payload['is_active'],
              'description': operation.payload['description'],
            })
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.meetingDelete:
        await client.rpc(
          'delete_meeting_cascade',
          params: {'target_meeting_id': operation.payload['id']},
        );
        return true;
      case OfflineOpType.classCreate:
        final meetingId = await queue.resolveId(
          operation.payload['meeting_id'] as String,
        );
        final row = await client
            .from('sunday_school_classes')
            .insert({
              'church_id': operation.payload['church_id'],
              'meeting_id': meetingId,
              'name': operation.payload['name'],
              'name_ar': operation.payload['name_ar'],
              'display_order': operation.payload['display_order'],
              'is_active': operation.payload['is_active'] ?? true,
            })
            .select()
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        await cache.removeClass(
          operation.payload['church_id'] as String,
          operation.payload['local_id'] as String,
        );
        await cache.upsertClass(
          operation.payload['church_id'] as String,
          SundaySchoolClassEntity.fromJson(row),
        );
        return true;
      case OfflineOpType.classUpdate:
        await client
            .from('sunday_school_classes')
            .update({
              'name': operation.payload['name'],
              'name_ar': operation.payload['name_ar'],
              'display_order': operation.payload['display_order'],
              'is_active': operation.payload['is_active'],
            })
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.classDelete:
        await client.rpc(
          'delete_sunday_school_class_cascade',
          params: {'target_class_id': operation.payload['id']},
        );
        return true;
      case OfflineOpType.memberCreate:
        final classId = operation.payload['sunday_school_class_id'] as String?;
        final meetingId = operation.payload['meeting_id'] as String?;
        final row = await client
            .from('members')
            .insert({
              'church_id': operation.payload['church_id'],
              'full_name': operation.payload['full_name'],
              'scope': operation.payload['scope'],
              'sunday_school_class_id': classId == null
                  ? null
                  : await queue.resolveId(classId),
              'meeting_id': meetingId == null
                  ? null
                  : await queue.resolveId(meetingId),
              'phone': operation.payload['phone'],
              'parent_name': operation.payload['parent_name'],
              'parent_phone': operation.payload['parent_phone'],
              'code': operation.payload['code'],
              'birth_date': operation.payload['birth_date'],
              'is_active': operation.payload['is_active'] ?? true,
              'joined_on': DateTime.now().toIso8601String().split('T').first,
            })
            .select()
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        await cache.removeMember(
          operation.payload['church_id'] as String,
          operation.payload['local_id'] as String,
        );
        await cache.upsertMember(
          operation.payload['church_id'] as String,
          MemberEntity.fromJson(row),
        );
        return true;
      case OfflineOpType.memberUpdate:
        final classId = operation.payload['sunday_school_class_id'] as String?;
        final meetingId = operation.payload['meeting_id'] as String?;
        await client
            .from('members')
            .update({
              'full_name': operation.payload['full_name'],
              'scope': operation.payload['scope'],
              'sunday_school_class_id': classId == null
                  ? null
                  : await queue.resolveId(classId),
              'meeting_id': meetingId == null
                  ? null
                  : await queue.resolveId(meetingId),
              'phone': operation.payload['phone'],
              'parent_name': operation.payload['parent_name'],
              'parent_phone': operation.payload['parent_phone'],
              'code': operation.payload['code'],
              'birth_date': operation.payload['birth_date'],
              'is_active': operation.payload['is_active'],
            })
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.memberDelete:
        await client.from('members').delete().eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.sessionCreate:
        final classId = operation.payload['class_id'] as String?;
        final row = await client.rpc(
          'create_attendance_session',
          params: {
            'target_meeting_id': await queue.resolveId(
              operation.payload['meeting_id'] as String,
            ),
            'target_class_id': classId == null
                ? null
                : await queue.resolveId(classId),
            'target_session_date': operation.payload['session_date'],
            'target_week_number': operation.payload['week_number'],
            'target_title': operation.payload['title'],
          },
        );
        final localId = operation.payload['local_id'] as String;
        final serverId = row['id'] as String;
        await queue.mapId(localId, serverId);
        await _renameAttendanceCache(localId, serverId);
        await cache.removeSession(
          operation.payload['meeting_id'] as String,
          classId,
          localId,
        );
        await cache.upsertSession(
          operation.payload['meeting_id'] as String,
          classId,
          AttendanceSessionEntity.fromJson(row),
        );
        return true;
      case OfflineOpType.sessionDelete:
        await client
            .from('attendance_sessions')
            .delete()
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.followUpCreate:
        final memberId = await queue.resolveId(
          operation.payload['member_id'] as String,
        );
        final sessionId = operation.payload['session_id'] as String?;
        final row = await client
            .from('follow_ups')
            .insert({
              'church_id': operation.payload['church_id'],
              'member_id': memberId,
              'session_id': sessionId == null
                  ? null
                  : await queue.resolveId(sessionId),
              'reason': operation.payload['reason'],
              'contact_status': operation.payload['contact_status'],
              'result': operation.payload['result'],
              'responsible_user_id': operation.payload['responsible_user_id'],
              'follow_up_date': operation.payload['follow_up_date'],
              'created_by': operation.payload['created_by'],
            })
            .select()
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        await cache.removeFollowUp(
          operation.payload['church_id'] as String,
          operation.payload['local_id'] as String,
        );
        await cache.upsertFollowUp(
          operation.payload['church_id'] as String,
          FollowUpEntity.fromJson(row),
        );
        return true;
      case OfflineOpType.followUpDelete:
        await client
            .from('follow_ups')
            .delete()
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.invitationCreate:
        final targetId = operation.payload['target_id'] as String?;
        final row = await client
            .from('invitations')
            .insert({
              'church_id': operation.payload['church_id'],
              'full_name': operation.payload['full_name'],
              'email': operation.payload['email'],
              'phone': operation.payload['phone'],
              'role': operation.payload['role'],
              'target_id': targetId == null
                  ? null
                  : await queue.resolveId(targetId),
              'assignment_scope': operation.payload['assignment_scope'],
              'can_take_attendance': operation.payload['can_take_attendance'],
              'can_view_reports': operation.payload['can_view_reports'],
              'code': operation.payload['code'],
              'invite_token': operation.payload['invite_token'],
              'is_used': false,
            })
            .select()
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        await cache.removeInvitation(
          operation.payload['church_id'] as String,
          operation.payload['local_id'] as String,
        );
        await cache.upsertInvitation(
          operation.payload['church_id'] as String,
          HelperInvitation.fromJson(row),
        );
        return true;
      case OfflineOpType.invitationUpdate:
        await client
            .from('invitations')
            .update({
              'full_name': operation.payload['full_name'],
              'email': operation.payload['email'],
            })
            .eq('id', operation.payload['id'])
            .eq('church_id', operation.payload['church_id'])
            .eq('is_used', false);
        return true;
      case OfflineOpType.invitationDelete:
        await client
            .from('invitations')
            .delete()
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.currentProfileUpdate:
        await client
            .from('profiles')
            .update({
              'full_name': operation.payload['full_name'],
              'phone': operation.payload['phone'],
            })
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.profileRoleUpdate:
        await client.rpc(
          'admin_update_profile_role',
          params: {
            'target_user_id': operation.payload['user_id'],
            'new_role': operation.payload['role'],
          },
        );
        return true;
      case OfflineOpType.profileStatusUpdate:
        await client.rpc(
          'admin_update_profile_status',
          params: {
            'target_user_id': operation.payload['user_id'],
            'new_is_active': operation.payload['is_active'],
          },
        );
        return true;
      case OfflineOpType.classAssignmentUpsert:
        final row = await client
            .from('class_assignments')
            .upsert({
              'church_id': operation.payload['church_id'],
              'class_id': await queue.resolveId(
                operation.payload['class_id'] as String,
              ),
              'user_id': operation.payload['user_id'],
              'can_take_attendance': operation.payload['can_take_attendance'],
              'can_view_reports': operation.payload['can_view_reports'],
              'assigned_by': operation.payload['assigned_by'],
            }, onConflict: 'class_id,user_id')
            .select('id')
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        return true;
      case OfflineOpType.classAssignmentDelete:
        await client
            .from('class_assignments')
            .delete()
            .eq('id', operation.payload['id']);
        return true;
      case OfflineOpType.meetingAssignmentUpsert:
        final row = await client
            .from('meeting_assignments')
            .upsert({
              'church_id': operation.payload['church_id'],
              'meeting_id': await queue.resolveId(
                operation.payload['meeting_id'] as String,
              ),
              'user_id': operation.payload['user_id'],
              'can_take_attendance': operation.payload['can_take_attendance'],
              'can_view_reports': operation.payload['can_view_reports'],
              'assigned_by': operation.payload['assigned_by'],
            }, onConflict: 'meeting_id,user_id')
            .select('id')
            .single();
        await queue.mapId(
          operation.payload['local_id'] as String,
          row['id'] as String,
        );
        return true;
      case OfflineOpType.meetingAssignmentDelete:
        await client
            .from('meeting_assignments')
            .delete()
            .eq('id', operation.payload['id']);
        return true;
      default:
        return true;
    }
  }

  Future<void> _renameAttendanceCache(
    String oldSessionId,
    String newSessionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final oldKey = 'offline_attendance_records_$oldSessionId';
    final newKey = 'offline_attendance_records_$newSessionId';
    final raw = prefs.getString(oldKey);
    if (raw == null) return;
    await prefs.setString(newKey, raw);
    await prefs.remove(oldKey);
    final unsynced = prefs.getStringList('offline_unsynced_sessions') ?? [];
    if (unsynced.contains(oldSessionId)) {
      unsynced
        ..remove(oldSessionId)
        ..add(newSessionId);
      await prefs.setStringList('offline_unsynced_sessions', unsynced);
    }
  }

  @override
  Future<void> _syncAttendanceWithRemapping() async {
    final prefs = await SharedPreferences.getInstance();
    final unsynced = prefs.getStringList('offline_unsynced_sessions') ?? [];
    if (unsynced.isEmpty) return;

    final toRemove = <String>[];
    for (final sessionId in unsynced) {
      final resolvedSessionId = await queue.resolveId(sessionId);
      final cacheKey = 'offline_attendance_records_$sessionId';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) {
        toRemove.add(sessionId);
        continue;
      }

      final parsed = _parseOfflineAttendanceCache(cachedData);
      if (parsed == null) {
        toRemove.add(sessionId);
        continue;
      }

      final remappedStatuses = <String, AttendanceStatus>{};
      for (final entry in parsed.statuses.entries) {
        remappedStatuses[await queue.resolveId(entry.key)] = entry.value;
      }

      try {
        final synced = await saveAttendanceOnline(
          sessionId: resolvedSessionId,
          statusesByMemberId: remappedStatuses,
        );
        if (synced) {
          toRemove.add(sessionId);
          if (resolvedSessionId != sessionId) {
            await prefs.remove(cacheKey);
          }
        }
      } catch (_) {
        break;
      }
    }

    if (toRemove.isNotEmpty) {
      unsynced.removeWhere(toRemove.contains);
      await prefs.setStringList('offline_unsynced_sessions', unsynced);
    }
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
    return null;
  }
}
