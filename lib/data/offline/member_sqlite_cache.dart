import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../shared/data/app_models.dart';
import 'member_local_store.dart';
import 'offline_entity_json.dart';

/// Indexed SQLite storage for member scopes opened on this device.
///
/// Pending edits stay in the write queue. This database is only a read cache
/// plus optimistic local rows.
class MemberSqliteCache extends GeneratedDatabase implements MemberLocalStore {
  MemberSqliteCache({QueryExecutor? executor})
    : super(executor ?? _defaultExecutor());

  static QueryExecutor _defaultExecutor() {
    return driftDatabase(name: 'link_members');
  }

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  Future<void>? _init;

  Future<void> _ready() => _init ??= _createSchema();

  Future<void> _createSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS members_cache (
        id TEXT PRIMARY KEY,
        church_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        code TEXT,
        phone TEXT,
        meeting_id TEXT,
        class_id TEXT,
        scope TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await _ensureColumn(
      table: 'members_cache',
      column: 'scope',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS member_meetings_cache (
        member_id TEXT NOT NULL,
        meeting_id TEXT NOT NULL,
        PRIMARY KEY (member_id, meeting_id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_name '
      'ON members_cache(church_id, full_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_code '
      'ON members_cache(church_id, code)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_phone '
      'ON members_cache(church_id, phone)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_meeting '
      'ON members_cache(church_id, meeting_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_class '
      'ON members_cache(church_id, class_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS members_church_scope '
      'ON members_cache(church_id, scope, is_active)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS member_meetings_meeting '
      'ON member_meetings_cache(meeting_id)',
    );
  }

  Future<void> _ensureColumn({
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.read<String>('name') == column);
    if (exists) {
      return;
    }
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  @override
  Future<void> upsert(String churchId, MemberEntity member) async {
    await _ready();
    await transaction(() => _upsertRow(churchId, member));
  }

  @override
  Future<void> upsertMany(
    String churchId,
    Iterable<MemberEntity> members,
  ) async {
    await _ready();
    final snapshot = members.toList(growable: false);
    if (snapshot.isEmpty) {
      return;
    }
    await transaction(() async {
      for (final member in snapshot) {
        await _upsertRow(churchId, member);
      }
    });
  }

  Future<void> _upsertRow(String churchId, MemberEntity member) async {
    await customUpdate(
      '''INSERT INTO members_cache
         (id, church_id, full_name, code, phone, meeting_id, class_id, scope,
          is_active, payload)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
         church_id=excluded.church_id, full_name=excluded.full_name,
         code=excluded.code, phone=excluded.phone,
         meeting_id=excluded.meeting_id, class_id=excluded.class_id,
         scope=excluded.scope, is_active=excluded.is_active,
         payload=excluded.payload''',
      variables: [
        Variable.withString(member.id),
        Variable.withString(churchId),
        Variable.withString(member.fullName),
        Variable.withString(member.code ?? ''),
        Variable.withString(member.phone ?? ''),
        Variable.withString(member.meetingId ?? ''),
        Variable.withString(member.sundaySchoolClassId ?? ''),
        Variable.withString(member.scope.value),
        Variable.withInt(member.isActive ? 1 : 0),
        Variable.withString(jsonEncode(memberToJson(member))),
      ],
    );
    await customUpdate(
      'DELETE FROM member_meetings_cache WHERE member_id = ?',
      variables: [Variable.withString(member.id)],
    );
    for (final meetingId in member.meetingIds) {
      if (meetingId.isEmpty) {
        continue;
      }
      await customUpdate(
        '''INSERT OR IGNORE INTO member_meetings_cache (member_id, meeting_id)
           VALUES (?, ?)''',
        variables: [
          Variable.withString(member.id),
          Variable.withString(meetingId),
        ],
      );
    }
  }

  @override
  Future<void> deleteMember(String churchId, String id) async {
    await _ready();
    await transaction(() async {
      await customUpdate(
        'DELETE FROM member_meetings_cache WHERE member_id = ?',
        variables: [Variable.withString(id)],
      );
      await customUpdate(
        'DELETE FROM members_cache WHERE church_id = ? AND id = ?',
        variables: [Variable.withString(churchId), Variable.withString(id)],
      );
    });
  }

  @override
  Future<List<MemberEntity>> readAll(String churchId) async {
    await _ready();
    final rows = await customSelect(
      'SELECT payload FROM members_cache WHERE church_id = ? '
      'ORDER BY full_name COLLATE NOCASE',
      variables: [Variable.withString(churchId)],
    ).get();
    return _membersFromRows(rows);
  }

  @override
  Future<List<MemberEntity>> readByIds(
    String churchId,
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) {
      return const [];
    }
    await _ready();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await customSelect(
      'SELECT payload FROM members_cache '
      'WHERE church_id = ? AND id IN ($placeholders)',
      variables: [
        Variable.withString(churchId),
        for (final id in uniqueIds) Variable.withString(id),
      ],
    ).get();
    return _membersFromRows(rows);
  }

  @override
  Future<MemberEntity?> readById(String churchId, String id) async {
    await _ready();
    final row = await customSelect(
      'SELECT payload FROM members_cache WHERE church_id = ? AND id = ? LIMIT 1',
      variables: [Variable.withString(churchId), Variable.withString(id)],
    ).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return MemberEntity.fromJson(
      Map<String, dynamic>.from(jsonDecode(row.read<String>('payload')) as Map),
    );
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
    await _ready();
    final safePage = page < 0 ? 0 : page;
    final safeSize = pageSize < 1 ? 50 : pageSize;
    final normalizedQuery = query.trim();
    final like = _likePattern(normalizedQuery);
    final scopeFilter = (scope == null || scope == 'all') ? '' : scope;
    final classFilter = classId ?? '';
    final meetingFilter = meetingId ?? '';
    final rows = await customSelect(
      '''SELECT payload FROM members_cache
         WHERE church_id = ?
           AND (? = 0 OR is_active = 1)
           AND (? = '' OR scope = ?)
           AND (? = '' OR class_id = ?)
           AND (
             ? = ''
             OR meeting_id = ?
             OR id IN (
               SELECT member_id FROM member_meetings_cache
               WHERE meeting_id = ?
             )
           )
           AND (
             ? = ''
             OR full_name LIKE ? ESCAPE '\\'
             OR code LIKE ? ESCAPE '\\'
             OR phone LIKE ? ESCAPE '\\'
           )
         ORDER BY full_name COLLATE NOCASE
         LIMIT ? OFFSET ?''',
      variables: [
        Variable.withString(churchId),
        Variable.withInt(activeOnly ? 1 : 0),
        Variable.withString(scopeFilter),
        Variable.withString(scopeFilter),
        Variable.withString(classFilter),
        Variable.withString(classFilter),
        Variable.withString(meetingFilter),
        Variable.withString(meetingFilter),
        Variable.withString(meetingFilter),
        Variable.withString(normalizedQuery),
        Variable.withString(like),
        Variable.withString(like),
        Variable.withString(like),
        Variable.withInt(safeSize + 1),
        Variable.withInt(safePage * safeSize),
      ],
    ).get();
    final members = _membersFromRows(rows);
    final hasMore = members.length > safeSize;
    return MemberQueryPage(
      items: hasMore ? members.sublist(0, safeSize) : members,
      hasMore: hasMore,
    );
  }

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
    var page = 0;
    while (true) {
      final result = await queryPage(
        churchId: churchId,
        page: page,
        pageSize: pageSize,
        query: query,
        meetingId: meetingId,
        classId: classId,
        scope: scope,
        activeOnly: activeOnly,
      );
      items.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) {
        return items;
      }
      page += 1;
    }
  }

  @override
  Future<MembersListCounts> counts({
    required String churchId,
    bool activeOnly = true,
  }) async {
    await _ready();
    final row = await customSelect(
      '''SELECT
           COUNT(*) AS total,
           COALESCE(SUM(CASE WHEN scope = 'sunday_school_class' THEN 1 ELSE 0 END), 0)
             AS sunday_school,
           COALESCE(SUM(CASE WHEN scope = 'meeting' THEN 1 ELSE 0 END), 0)
             AS meetings
         FROM members_cache
         WHERE church_id = ?
           AND (? = 0 OR is_active = 1)''',
      variables: [
        Variable.withString(churchId),
        Variable.withInt(activeOnly ? 1 : 0),
      ],
    ).getSingle();
    return MembersListCounts(
      total: row.read<int>('total'),
      sundaySchool: row.read<int>('sunday_school'),
      meetings: row.read<int>('meetings'),
    );
  }

  @override
  Future<void> clear() async {
    await _ready();
    await customStatement('DELETE FROM member_meetings_cache');
    await customStatement('DELETE FROM members_cache');
  }

  List<MemberEntity> _membersFromRows(List<QueryRow> rows) {
    return [
      for (final row in rows)
        MemberEntity.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          ),
        ),
    ];
  }

  String _likePattern(String query) {
    if (query.isEmpty) {
      return '%';
    }
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }
}
