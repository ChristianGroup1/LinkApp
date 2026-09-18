import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/invitations/invitation_link.dart';
import '../../shared/data/app_models.dart';
import 'invitation_create_result.dart';
import 'member_create_draft.dart';
import 'offline_cache.dart';
import 'offline_entity_json.dart';
import 'offline_network_policy.dart';
import 'offline_save_result.dart';
import 'offline_write_queue.dart';

part 'offline_attendance_writes.dart';
part 'offline_church_meeting_writes.dart';
part 'offline_class_writes.dart';
part 'offline_followup_writes.dart';
part 'offline_invitation_writes.dart';
part 'offline_member_writes.dart';
part 'offline_write_sync.dart';

typedef ProfileLoader = Future<AppProfile?> Function();
typedef AttendanceSaver =
    Future<bool> Function({
      required String sessionId,
      required Map<String, AttendanceStatus> statusesByMemberId,
    });

String? _dateOnly(DateTime? value) => value?.toIso8601String().split('T').first;

abstract class _OfflineWriteHandlerBase {
  final SupabaseClient client;
  final OfflineCache cache;
  final OfflineWriteQueue queue;
  final ProfileLoader loadProfile;
  final AttendanceSaver saveAttendanceOnline;
  final String? Function(String?) emptyToNull;
  Future<void>? _syncInFlight;

  _OfflineWriteHandlerBase({
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
    final unsynced =
        prefs.getStringList(OfflineCache.unsyncedSessionsKey) ?? [];
    return unsynced.isNotEmpty || !(await queue.isEmpty());
  }

  /// Changes the server refused for good, so the interface can say so instead of
  /// letting them sit invisible on the device.
  Future<int> rejectedDataCount() => queue.rejectedCount();

  /// Forgets the refused changes after the user has acknowledged the warning.
  Future<void> clearRejectedData() => queue.clearRejected();

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

  Future<void> _syncWriteQueue();

  Future<void> _syncAttendanceWithRemapping();

  Future<void> _performSync() async {
    await _syncWriteQueue();
    await _syncAttendanceWithRemapping();
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
}

class OfflineWriteHandler extends _OfflineWriteHandlerBase
    with
        _OfflineMemberWrites,
        _OfflineChurchMeetingWrites,
        _OfflineClassWrites,
        _OfflineAttendanceWrites,
        _OfflineFollowUpWrites,
        _OfflineInvitationWrites,
        _OfflineWriteSync {
  OfflineWriteHandler({
    required super.client,
    required super.cache,
    required super.queue,
    required super.loadProfile,
    required super.saveAttendanceOnline,
    required super.emptyToNull,
  });
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
