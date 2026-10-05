import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/data/app_models.dart';
import 'member_indexeddb_cache.dart';
import 'member_local_store.dart';
import 'offline_write_queue.dart';

MemberLocalStore createMemberLocalStore() => MemberIndexedDbCache();

final _migrations = <String, Future<void>>{};

void resetMemberStoreMigration() => _migrations.clear();

/// The old SQLite read cache can be repopulated online. Pending member edits
/// are also stored in the durable write queue; recover them before first read
/// so switching browser stores does not hide unsynced local members.
Future<void> restorePendingMembers(String churchId, MemberLocalStore store) {
  if (store is! MemberIndexedDbCache) return Future.value();
  return _migrations.putIfAbsent(churchId, () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marker = 'offline_cache_members_indexeddb_migrated_$churchId';
      if (prefs.getBool(marker) == true) return;
      final profileJson = prefs.getString('offline_cache_profile');
      final profileChurch = profileJson == null
          ? null
          : (jsonDecode(profileJson) as Map)['church_id'];
      final queue = OfflineWriteQueue();
      for (final operation in await queue.all()) {
        final payload = operation.payload;
        final owner = payload['church_id'] ?? profileChurch;
        if (owner != churchId) continue;
        if (operation.type == OfflineOpType.memberCreate ||
            operation.type == OfflineOpType.memberUpdate) {
          final id = payload['local_id'] ?? payload['id'];
          if (id is! String) continue;
          final previous = await store.readById(churchId, id);
          await store.upsert(
            churchId,
            MemberEntity.fromJson({
              ...payload,
              'id': id,
              'church_id': churchId,
              'meeting_ids': previous?.meetingIds ?? const <String>[],
            }),
          );
        } else if (operation.type == OfflineOpType.memberDelete) {
          final id = payload['id'];
          if (id is String) await store.deleteMember(churchId, id);
        }
      }
      await prefs.setBool(marker, true);
    } catch (_) {
      _migrations.removeWhere((key, _) => key == churchId);
      rethrow;
    }
  });
}
