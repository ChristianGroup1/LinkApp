import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const invitationDelete = 'invitation.delete';

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
    invitationDelete,
  ];
}

class OfflineWriteQueue {
  static const _queueKey = 'offline_write_queue';
  static const _idMapKey = 'offline_id_mappings';

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
    });
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
