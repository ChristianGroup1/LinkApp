@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/offline/member_indexeddb_cache.dart';
import 'package:link/data/offline/member_store_factory_web.dart';
import 'package:link/data/offline/offline_cache.dart';
import 'package:link/data/offline/offline_write_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browser migration restores pending edits and preserves queue', () async {
    SharedPreferences.setMockInitialValues({
      'offline_cache_profile': jsonEncode({'church_id': 'church-a'}),
      'offline_cache_members_church-a': jsonEncode([
        {
          'id': 'existing',
          'church_id': 'church-a',
          'full_name': 'قديم',
          'scope': 'meeting',
          'meeting_ids': ['copied-meeting'],
        },
        {
          'id': 'deleted',
          'church_id': 'church-a',
          'full_name': 'محذوف',
          'scope': 'meeting',
        },
      ]),
    });
    resetMemberStoreMigration();
    final store = MemberIndexedDbCache(databaseName: 'link_migration_test');
    await store.clear();
    final queue = OfflineWriteQueue();
    for (final entry in [
      (
        OfflineOpType.memberCreate,
        {
          'local_id': 'offline_member_1',
          'church_id': 'church-a',
          'full_name': 'مخدوم جديد',
          'scope': 'meeting',
        },
      ),
      (
        OfflineOpType.memberUpdate,
        {'id': 'existing', 'full_name': 'تم التعديل', 'scope': 'meeting'},
      ),
      (OfflineOpType.memberDelete, {'id': 'deleted'}),
      (
        OfflineOpType.memberCreate,
        {
          'local_id': 'offline_other',
          'church_id': 'church-b',
          'full_name': 'كنيسة أخرى',
          'scope': 'meeting',
        },
      ),
    ]) {
      await queue.enqueue(
        QueuedOperation(
          id: 'op-${entry.$2['local_id'] ?? entry.$2['id']}',
          type: entry.$1,
          payload: entry.$2,
          queuedAt: DateTime.now(),
        ),
      );
    }
    final cache = OfflineCache(memberStore: store);
    final rows = await Future.wait([
      cache.readMembers('church-a'),
      cache.readMembers('church-a'),
    ]);
    for (final members in rows) {
      expect(members!.map((m) => m.id).toSet(), {
        'offline_member_1',
        'existing',
      });
      final updated = members.singleWhere((m) => m.id == 'existing');
      expect(updated.fullName, 'تم التعديل');
      expect(updated.meetingIds, contains('copied-meeting'));
    }
    expect(await queue.all(), hasLength(4));
    expect(await store.readById('church-a', 'offline_other'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('offline_cache_members_church-a'), isNull);
    expect(
      prefs.getBool('offline_cache_members_indexeddb_migrated_church-a'),
      isTrue,
    );

    // A subsequent read must not reapply the queued edit over newer cache data.
    final updated = await store.readById('church-a', 'existing');
    await store.deleteMember('church-a', updated!.id);
    expect(await cache.readMemberById('church-a', updated.id), isNull);
    await cache.clearAll();
    expect(
      prefs.getBool('offline_cache_members_indexeddb_migrated_church-a'),
      isNull,
    );
    expect(await store.readAll('church-a'), isEmpty);
  });
}
