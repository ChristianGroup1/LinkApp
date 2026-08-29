import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/invitations/invitation_link.dart';
import '../../shared/data/app_models.dart';
import 'member_create_draft.dart';
import 'offline_cache.dart';
import 'offline_entity_json.dart';
import 'invitation_create_result.dart';
import 'offline_network_policy.dart';
import 'offline_save_result.dart';
import 'offline_write_queue.dart';

typedef ProfileLoader = Future<AppProfile?> Function();
typedef AttendanceSaver =
    Future<bool> Function({
      required String sessionId,
      required Map<String, AttendanceStatus> statusesByMemberId,
    });

String? _dateOnly(DateTime? value) => value?.toIso8601String().split('T').first;

class OfflineWriteHandler {
  final SupabaseClient client;
  final OfflineCache cache;
  final OfflineWriteQueue queue;
  final ProfileLoader loadProfile;
  final AttendanceSaver saveAttendanceOnline;
  final String? Function(String?) emptyToNull;
  Future<void>? _syncInFlight;

  OfflineWriteHandler({
    required this.client,
    required this.cache,
    required this.queue,
    required this.loadProfile,
    required this.saveAttendanceOnline,
    required this.emptyToNull,
  });

  bool isRecoverableOfflineError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('clientexception') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('host lookup') ||
        message.contains('failed host') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('offline') ||
        message.contains('internet');
  }

  Future<void> _throwIfKnownOffline() async {
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      throw const SocketException('offline');
    }
  }

  Future<bool> _shouldQueueDeleteInsteadOfServerCall() async {
    await OfflineNetworkPolicy.ensureReady();
    return OfflineNetworkPolicy.isConnectivityOffline;
  }

  Future<void> _queueEntityDelete({
    required String type,
    required String id,
    required Future<void> Function() removeFromCache,
  }) async {
    await removeFromCache();
    await queue.enqueue(
      QueuedOperation(
        id: await queue.generateId('op'),
        type: type,
        payload: {'id': id},
        queuedAt: DateTime.now(),
      ),
    );
  }

  Future<bool> hasPendingData() async {
    final prefs = await SharedPreferences.getInstance();
    final unsynced = prefs.getStringList('offline_unsynced_sessions') ?? [];
    return unsynced.isNotEmpty || !(await queue.isEmpty());
  }

  Future<void> clear() => queue.clear();

  Future<void> syncAll() {
    final active = _syncInFlight;
    if (active != null) return active;

    final sync = _performSync();
    _syncInFlight = sync;
    return sync.whenComplete(() {
      if (identical(_syncInFlight, sync)) _syncInFlight = null;
    });
  }

  Future<void> _performSync() async {
    await _syncWriteQueue();
    await _syncAttendanceWithRemapping();
  }

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
          .select()
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
      final rows = await client.from('members').insert(payload).select();
      final members = [
        for (final row in rows) MemberEntity.fromJson(row),
      ];
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

    if (isOfflineId(id) && resolvedId == id) {
      final member = MemberEntity(
        id: id,
        churchId: churchId,
        fullName: fullName.trim(),
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
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
          .select()
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

  String _generateActivationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final suffix = List.generate(
      8,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    return 'ACT-$suffix';
  }

  String _generateInviteToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<AppProfile> _requireProfile() async {
    final profile = await loadProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم الحالي غير مرتبط بكنيسة');
    }
    return profile!;
  }

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

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
