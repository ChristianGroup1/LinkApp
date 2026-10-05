import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../shared/data/app_models.dart';
import 'member_local_store.dart';
import 'offline_entity_json.dart';

/// Browser storage with no SQLite runtime or worker downloads.
/// Keys and indexes include the church so tabs cannot mix tenant caches.
class MemberIndexedDbCache implements MemberLocalStore {
  MemberIndexedDbCache({this.databaseName = 'link_members_browser'});

  final String databaseName;
  static const _storeName = 'members';
  Future<web.IDBDatabase>? _database;

  Future<web.IDBDatabase> _open() => _database ??= _openDatabase();

  Future<web.IDBDatabase> _openDatabase() async {
    try {
      final request = web.window.indexedDB.open(databaseName, 1);
      request.onupgradeneeded = ((web.Event event) {
        final db = request.result as web.IDBDatabase;
        final store = db.createObjectStore(
          _storeName,
          web.IDBObjectStoreParameters(keyPath: 'key'.toJS),
        );
        for (final index in ['churchName', 'className', 'scopeName']) {
          store.createIndex(index, index.toJS, web.IDBIndexParameters());
        }
        store.createIndex(
          'meetingName',
          'meetingName'.toJS,
          web.IDBIndexParameters(multiEntry: true),
        );
      }).toJS;
      request.onblocked = ((web.Event event) {
        // Other connections close on versionchange; the open deadline covers
        // browsers where a stale tab still holds the connection.
      }).toJS;
      final db = (await _request(request)) as web.IDBDatabase;
      db.onversionchange = ((web.Event event) {
        db.close();
        _database = null;
      }).toJS;
      return db;
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final result = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      if (!result.isCompleted) result.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!result.isCompleted) {
        result.completeError(
          StateError(
            request.error?.message ?? 'Browser storage request failed',
          ),
        );
      }
    }).toJS;
    return result.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _committed(web.IDBTransaction transaction) {
    final result = Completer<void>();
    transaction.oncomplete = ((web.Event event) {
      if (!result.isCompleted) result.complete();
    }).toJS;
    transaction.onabort = ((web.Event event) {
      if (!result.isCompleted) {
        result.completeError(
          StateError(
            transaction.error?.message ?? 'Browser storage transaction aborted',
          ),
        );
      }
    }).toJS;
    return result.future.timeout(const Duration(seconds: 20));
  }

  JSAny _key(String churchId, String id) => [churchId, id].jsify()!;

  JSObject _row(String churchId, MemberEntity member) {
    final name = member.fullName.toLowerCase();
    final meetings = {
      if (member.meetingId?.isNotEmpty == true) member.meetingId!,
      ...member.meetingIds.where((id) => id.isNotEmpty),
    };
    return {
          'key': [churchId, member.id],
          'churchName': [churchId, name, member.id],
          'className': [
            churchId,
            member.sundaySchoolClassId ?? '',
            name,
            member.id,
          ],
          'scopeName': [churchId, member.scope.value, name, member.id],
          'meetingName': [
            for (final id in meetings) [churchId, id, name, member.id],
          ],
          'name': name,
          'code': (member.code ?? '').toLowerCase(),
          'phone': (member.phone ?? '').toLowerCase(),
          'classId': member.sundaySchoolClassId ?? '',
          'scope': member.scope.value,
          'meetings': meetings.toList(),
          'active': member.isActive,
          'payload': jsonEncode(memberToJson(member)),
        }.jsify()!
        as JSObject;
  }

  MemberEntity _member(Map<String, dynamic> row) => MemberEntity.fromJson(
    Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map),
  );

  Map<String, dynamic> _dartRow(JSAny value) =>
      Map<String, dynamic>.from(value.dartify()! as Map);

  @override
  Future<void> upsert(String churchId, MemberEntity member) =>
      upsertMany(churchId, [member]);

  @override
  Future<void> upsertMany(
    String churchId,
    Iterable<MemberEntity> members,
  ) async {
    // Prepare before opening the transaction. IndexedDB commits automatically
    // when its requests finish, so all puts must be queued synchronously.
    final rows = [for (final member in members) _row(churchId, member)];
    if (rows.isEmpty) return;
    final db = await _open();
    final transaction = db.transaction(_storeName.toJS, 'readwrite');
    final committed = _committed(transaction);
    final store = transaction.objectStore(_storeName);
    for (final row in rows) {
      store.put(row);
    }
    await committed;
  }

  @override
  Future<void> deleteMember(String churchId, String id) async {
    final db = await _open();
    final transaction = db.transaction(_storeName.toJS, 'readwrite');
    final committed = _committed(transaction);
    transaction.objectStore(_storeName).delete(_key(churchId, id));
    await committed;
  }

  @override
  Future<MemberEntity?> readById(String churchId, String id) async {
    final rows = await readByIds(churchId, [id]);
    return rows.isEmpty ? null : rows.single;
  }

  @override
  Future<List<MemberEntity>> readByIds(
    String churchId,
    Iterable<String> ids,
  ) async {
    final keys = ids.where((id) => id.isNotEmpty).toSet();
    if (keys.isEmpty) return [];
    final db = await _open();
    final store = db.transaction(_storeName.toJS).objectStore(_storeName);
    final rows = await Future.wait([
      for (final id in keys) _request(store.get(_key(churchId, id))),
    ]);
    return [
      for (final row in rows)
        if (row != null) _member(_dartRow(row)),
    ];
  }

  /// Streams the selected index in name order. Page queries decode and retain
  /// only the requested page plus one row, rather than loading a church list.
  Future<void> _scan({
    required String churchId,
    String? meetingId,
    String? classId,
    String? scope,
    required bool Function(Map<String, dynamic>) visit,
  }) async {
    final db = await _open();
    final store = db.transaction(_storeName.toJS).objectStore(_storeName);
    var index = 'churchName';
    final prefix = <Object>[churchId];
    if (classId != null && classId.isNotEmpty) {
      index = 'className';
      prefix.add(classId);
    } else if (meetingId != null && meetingId.isNotEmpty) {
      index = 'meetingName';
      prefix.add(meetingId);
    } else if (scope != null && scope.isNotEmpty && scope != 'all') {
      index = 'scopeName';
      prefix.add(scope);
    }
    // Arrays sort after string keys, bounding every name under this prefix.
    final range = web.IDBKeyRange.bound(
      prefix.jsify(),
      [...prefix, []].jsify(),
    );
    final request = store.index(index).openCursor(range);
    final result = Completer<void>();
    request.onsuccess = ((web.Event event) {
      if (result.isCompleted) return;
      final value = request.result;
      if (value == null) {
        result.complete();
        return;
      }
      try {
        final cursor = value as web.IDBCursorWithValue;
        if (visit(_dartRow(cursor.value!))) {
          cursor.continue_();
        } else {
          result.complete();
        }
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!result.isCompleted) {
        result.completeError(
          StateError(request.error?.message ?? 'Browser storage query failed'),
        );
      }
    }).toJS;
    await result.future.timeout(const Duration(seconds: 20));
  }

  bool _matches(
    Map<String, dynamic> row, {
    required String query,
    String? meetingId,
    String? classId,
    String? scope,
    required bool activeOnly,
  }) {
    if (activeOnly && row['active'] != true) return false;
    if (classId != null && classId.isNotEmpty && row['classId'] != classId) {
      return false;
    }
    if (scope != null &&
        scope.isNotEmpty &&
        scope != 'all' &&
        row['scope'] != scope) {
      return false;
    }
    if (meetingId != null &&
        meetingId.isNotEmpty &&
        !(row['meetings'] as List).contains(meetingId)) {
      return false;
    }
    return query.isEmpty ||
        [
          'name',
          'code',
          'phone',
        ].any((field) => (row[field] as String).contains(query));
  }

  @override
  Future<MemberQueryPage> queryPage({
    required String churchId,
    required int page,
    required int pageSize,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
  }) async {
    final safeSize = pageSize < 1 ? 50 : pageSize;
    final offset = (page < 0 ? 0 : page) * safeSize;
    final normalized = query.trim().toLowerCase();
    var skipped = 0;
    final items = <MemberEntity>[];
    await _scan(
      churchId: churchId,
      meetingId: meetingId,
      classId: classId,
      scope: scope,
      visit: (row) {
        if (!_matches(
          row,
          query: normalized,
          meetingId: meetingId,
          classId: classId,
          scope: scope,
          activeOnly: activeOnly,
        )) {
          return true;
        }
        if (skipped < offset) {
          skipped++;
          return true;
        }
        items.add(_member(row));
        return items.length <= safeSize;
      },
    );
    return MemberQueryPage(
      items: items.take(safeSize).toList(),
      hasMore: items.length > safeSize,
    );
  }

  @override
  Future<List<MemberEntity>> readAll(String churchId) =>
      queryAll(churchId: churchId, activeOnly: false);

  @override
  Future<List<MemberEntity>> queryAll({
    required String churchId,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
    int pageSize = 500,
  }) async {
    final items = <MemberEntity>[];
    final normalized = query.trim().toLowerCase();
    await _scan(
      churchId: churchId,
      meetingId: meetingId,
      classId: classId,
      scope: scope,
      visit: (row) {
        if (_matches(
          row,
          query: normalized,
          meetingId: meetingId,
          classId: classId,
          scope: scope,
          activeOnly: activeOnly,
        )) {
          items.add(_member(row));
        }
        return true;
      },
    );
    return items;
  }

  @override
  Future<MembersListCounts> counts({
    required String churchId,
    bool activeOnly = true,
  }) async {
    var total = 0;
    var sundaySchool = 0;
    var meetings = 0;
    await _scan(
      churchId: churchId,
      visit: (row) {
        if (activeOnly && row['active'] != true) return true;
        total++;
        if (row['scope'] == MemberScope.sundaySchoolClass.value) sundaySchool++;
        if (row['scope'] == MemberScope.meeting.value) meetings++;
        return true;
      },
    );
    return MembersListCounts(
      total: total,
      sundaySchool: sundaySchool,
      meetings: meetings,
    );
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    final transaction = db.transaction(_storeName.toJS, 'readwrite');
    final committed = _committed(transaction);
    transaction.objectStore(_storeName).clear();
    await committed;
  }
}
