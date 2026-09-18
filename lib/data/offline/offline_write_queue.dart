import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueuedOperation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const QueuedOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'queued_at': queuedAt.toIso8601String(),
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      queuedAt: DateTime.parse(json['queued_at'] as String),
    );
  }
}

/// True when the server refused an operation in a way that repeating it can
/// never fix, because the same payload will always be rejected.
///
/// PostgreSQL states the reason in the SQLSTATE the request fails with:
///
/// * `22xxx` — the value itself is unusable (too long, unparseable, out of range).
/// * `23xxx` — an integrity rule rejects it (required value missing, unique code
///   already used, parent row gone, check constraint failed).
/// * `42xxx` — the access rule rejects it (row-level security refused the row,
///   the account lost permission over the target).
///
/// Everything else — connection resets, timeouts, an expired session, a server
/// busy with another transaction — may succeed on a later attempt, so callers
/// keep those queued.
bool isPermanentServerRejection(Object error) {
  final code = error is PostgrestException ? error.code : null;
  if (code == null) return false;
  return code.startsWith('22') ||
      code.startsWith('23') ||
      code.startsWith('42');
}

abstract class OfflineOpType {
  static const churchUpdate = 'church.update';
  static const meetingCreate = 'meeting.create';
  static const meetingUpdate = 'meeting.update';
  static const meetingDelete = 'meeting.delete';
  static const classCreate = 'class.create';
  static const classUpdate = 'class.update';
  static const classDelete = 'class.delete';
  static const memberCreate = 'member.create';
  static const memberUpdate = 'member.update';
  static const memberDelete = 'member.delete';
  static const sessionCreate = 'session.create';
  static const sessionDelete = 'session.delete';
  static const followUpCreate = 'follow_up.create';
  static const followUpDelete = 'follow_up.delete';
  static const invitationCreate = 'invitation.create';
  static const invitationUpdate = 'invitation.update';
  static const invitationDelete = 'invitation.delete';
  static const currentProfileUpdate = 'profile.current_update';
  static const profileRoleUpdate = 'profile.role_update';
  static const profileStatusUpdate = 'profile.status_update';
  static const classAssignmentUpsert = 'assignment.class_upsert';
  static const classAssignmentDelete = 'assignment.class_delete';
  static const meetingAssignmentUpsert = 'assignment.meeting_upsert';
  static const meetingAssignmentDelete = 'assignment.meeting_delete';

  static const syncOrder = [
    churchUpdate,
    meetingCreate,
    meetingUpdate,
    meetingDelete,
    classCreate,
    classUpdate,
    classDelete,
    memberCreate,
    memberUpdate,
    memberDelete,
    sessionCreate,
    sessionDelete,
    followUpCreate,
    followUpDelete,
    invitationCreate,
    invitationUpdate,
    invitationDelete,
    currentProfileUpdate,
    profileRoleUpdate,
    profileStatusUpdate,
    classAssignmentUpsert,
    classAssignmentDelete,
    meetingAssignmentUpsert,
    meetingAssignmentDelete,
  ];
}

class OfflineWriteQueue {
  static const _queueKey = 'offline_write_queue';
  static const _idMapKey = 'offline_id_mappings';
  static const _rejectedKey = 'offline_write_rejected';

  /// How many refused operations are kept on the device so nothing the servant
  /// wrote is thrown away without a trace.
  static const _maxRejected = 20;

  // SharedPreferences has no atomic read/modify/write operation. Keep queue and
  // id-map mutations serialized across all queue instances so simultaneous UI
  // actions cannot overwrite each other.
  static Future<void> _mutationTail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _mutationTail.then((_) => action());
    _mutationTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<List<QueuedOperation>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map(
          (item) =>
              QueuedOperation.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<bool> isEmpty() async => (await all()).isEmpty;

  static const _deleteTypes = {
    OfflineOpType.meetingDelete,
    OfflineOpType.classDelete,
    OfflineOpType.memberDelete,
    OfflineOpType.sessionDelete,
    OfflineOpType.followUpDelete,
    OfflineOpType.invitationDelete,
    OfflineOpType.classAssignmentDelete,
    OfflineOpType.meetingAssignmentDelete,
  };

  /// Entity IDs with a delete queued but not yet synced to the server.
  Future<Set<String>> pendingDeletedEntityIds() async {
    final operations = await all();
    final ids = <String>{};
    for (final operation in operations) {
      if (!_deleteTypes.contains(operation.type)) continue;
      final id = operation.payload['id'] as String?;
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<void> enqueue(QueuedOperation operation) async {
    await _serialize(() async {
      final operations = await all();
      operations.add(operation);
      await _save(operations);
    });
  }

  Future<void> remove(String operationId) async {
    await _serialize(() async {
      final operations = await all();
      operations.removeWhere((op) => op.id == operationId);
      await _save(operations);
    });
  }

  Future<void> removeByEntityId(String entityId) async {
    await _serialize(() async {
      final operations = await all();
      operations.removeWhere((op) {
        final payloadId = op.payload['id'] as String?;
        final localId = op.payload['local_id'] as String?;
        return payloadId == entityId || localId == entityId;
      });
      await _save(operations);
    });
  }

  Future<void> clear() async {
    await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_idMapKey);
      await prefs.remove(_rejectedKey);
    });
  }

  /// Sets an operation aside when the server refused it for good.
  ///
  /// A refused operation can never succeed on a retry, and leaving it in the
  /// queue would block every later change behind it, so it is moved here. The
  /// payload is kept — it names a record the servant wrote — and the count is
  /// reported to the interface instead of disappearing silently.
  Future<void> reject(QueuedOperation operation, String reason) async {
    await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final rejected = [
        {...operation.toJson(), 'reason': reason},
        ..._decodeRejected(prefs.getString(_rejectedKey)),
      ];
      await prefs.setString(
        _rejectedKey,
        jsonEncode(rejected.take(_maxRejected).toList()),
      );
    });
  }

  /// How many accepted-then-refused operations this device is still holding.
  Future<int> rejectedCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeRejected(prefs.getString(_rejectedKey)).length;
  }

  /// Drops the refused operations once the user has acknowledged them, so the
  /// warning does not follow them forever after they re-entered the data.
  Future<void> clearRejected() async {
    await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rejectedKey);
    });
  }

  List<dynamic> _decodeRejected(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<String> generateId(String prefix) async {
    final rand = Random.secure();
    final suffix = List.generate(
      8,
      (_) => rand.nextInt(36),
    ).map((value) => 'abcdefghijklmnopqrstuvwxyz0123456789'[value]).join();
    return 'offline_${prefix}_$suffix';
  }

  Future<void> mapId(String offlineId, String serverId) async {
    await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_idMapKey);
      final map = raw == null
          ? <String, String>{}
          : Map<String, String>.from(jsonDecode(raw) as Map);
      map[offlineId] = serverId;
      await prefs.setString(_idMapKey, jsonEncode(map));
    });
  }

  Future<String> resolveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_idMapKey);
    if (raw == null) return id;
    final map = Map<String, String>.from(jsonDecode(raw) as Map);
    var current = id;
    while (map.containsKey(current)) {
      current = map[current]!;
    }
    return current;
  }

  Future<Map<String, String>> idMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_idMapKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> _save(List<QueuedOperation> operations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(operations.map((op) => op.toJson()).toList()),
    );
  }
}
