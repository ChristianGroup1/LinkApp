import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/offline/member_import_history.dart';
import 'package:link/data/offline/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

MemberImportHistoryEntry _entry(String id, {String fileName = 'members.xlsx'}) {
  return MemberImportHistoryEntry(
    id: id,
    date: DateTime.utc(2026, 9, 4, 21, 31),
    fileName: fileName,
    created: 3,
    updated: 1,
    skipped: 0,
    failed: 1,
  );
}

String _legacyPayload() => jsonEncode([
  {
    'id': 'other-church-run',
    'date': DateTime.utc(2026, 9, 4, 20, 32).toIso8601String(),
    'file_name': 'مف (1).xlsx',
    'created': 0,
    'updated': 0,
    'skipped': 0,
    'failed': 1,
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('each church keeps its own import log', () async {
    final firstChurch = MemberImportHistoryStore(churchId: 'church-a');
    final secondChurch = MemberImportHistoryStore(churchId: 'church-b');

    await firstChurch.add(_entry('run-a', fileName: 'اعضاء_a.xlsx'));
    await secondChurch.add(_entry('run-b', fileName: 'اعضاء_b.xlsx'));

    final firstEntries = await firstChurch.load();
    final secondEntries = await secondChurch.load();

    expect(firstEntries.map((entry) => entry.id), ['run-a']);
    expect(firstEntries.single.fileName, 'اعضاء_a.xlsx');
    expect(secondEntries.map((entry) => entry.id), ['run-b']);
    expect(secondEntries.single.fileName, 'اعضاء_b.xlsx');
  });

  test('a church without runs never sees another church log', () async {
    await MemberImportHistoryStore(churchId: 'church-a').add(_entry('run-a'));

    expect(
      await MemberImportHistoryStore(churchId: 'church-b').load(),
      isEmpty,
    );
  });

  test('the unscoped log from older builds is discarded, not shown', () async {
    SharedPreferences.setMockInitialValues({
      MemberImportHistoryStore.legacyKey: _legacyPayload(),
    });

    final entries = await MemberImportHistoryStore(churchId: 'church-a').load();

    expect(entries, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(MemberImportHistoryStore.legacyKey), isFalse);
  });

  test('an account without a church never reads or writes a log', () async {
    const store = MemberImportHistoryStore(churchId: null);

    await store.add(_entry('run-a'));

    expect(await store.load(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where(
        (key) => key.startsWith(MemberImportHistoryStore.keyPrefix),
      ),
      isEmpty,
    );
  });

  test('only the thirty most recent runs of a church are kept', () async {
    final store = MemberImportHistoryStore(churchId: 'church-a');
    for (var index = 0; index < 35; index++) {
      await store.add(_entry('run-$index'));
    }

    final entries = await store.load();
    expect(entries, hasLength(30));
    expect(entries.first.id, 'run-34');
    expect(entries.last.id, 'run-5');
  });

  test('corrupt store content is ignored instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      '${MemberImportHistoryStore.keyPrefix}church-a': '{incomplete-json',
    });

    expect(
      await MemberImportHistoryStore(churchId: 'church-a').load(),
      isEmpty,
    );
  });

  test('signing out wipes every church log and cached attendance', () async {
    SharedPreferences.setMockInitialValues({
      MemberImportHistoryStore.legacyKey: _legacyPayload(),
      '${MemberImportHistoryStore.keyPrefix}church-a': '[]',
      '${MemberImportHistoryStore.keyPrefix}church-b': '[]',
      '${OfflineCache.attendanceRecordsPrefix}session-1': '{}',
      OfflineCache.unsyncedSessionsKey: <String>['session-1'],
      'offline_cache_members_church-a': '[]',
    });

    await OfflineCache().clearAll();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
