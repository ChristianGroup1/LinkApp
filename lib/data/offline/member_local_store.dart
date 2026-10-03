import '../../shared/data/app_models.dart';
import 'offline_entity_json.dart';

/// Combines a server roster with members that only exist locally (`offline_*`)
/// so attendance sheets stay usable before the write queue syncs.
List<MemberEntity> mergeRosterWithPendingOfflineMembers({
  required List<MemberEntity> remote,
  required List<MemberEntity> local,
  Set<String> pendingDeletes = const {},
}) {
  final byId = <String, MemberEntity>{
    for (final member in remote)
      if (!pendingDeletes.contains(member.id)) member.id: member,
  };
  for (final member in local) {
    if (!isOfflineId(member.id) || pendingDeletes.contains(member.id)) {
      continue;
    }
    byId.putIfAbsent(member.id, () => member);
  }
  return byId.values.toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));
}

/// Indexed local store for members that have been opened on this device.
abstract class MemberLocalStore {
  Future<void> upsert(String churchId, MemberEntity member);

  Future<void> upsertMany(String churchId, Iterable<MemberEntity> members);

  Future<void> deleteMember(String churchId, String id);

  Future<List<MemberEntity>> readAll(String churchId);

  Future<List<MemberEntity>> readByIds(String churchId, Iterable<String> ids);

  Future<MemberEntity?> readById(String churchId, String id);

  Future<MemberQueryPage> queryPage({
    required String churchId,
    required int page,
    required int pageSize,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
  });

  /// Reads every matching local row by paging the indexed query.
  /// Used for offline attendance scopes, not for whole-church dumps.
  Future<List<MemberEntity>> queryAll({
    required String churchId,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
    int pageSize = 500,
  });

  Future<MembersListCounts> counts({
    required String churchId,
    bool activeOnly = true,
  });

  Future<void> clear();
}

class MemberQueryPage {
  final List<MemberEntity> items;
  final bool hasMore;

  const MemberQueryPage({required this.items, required this.hasMore});
}

class MembersListCounts {
  final int total;
  final int sundaySchool;
  final int meetings;

  const MembersListCounts({
    this.total = 0,
    this.sundaySchool = 0,
    this.meetings = 0,
  });
}

class MemberRealtimeDelta {
  final List<MemberEntity> upserts;
  final List<String> deletedIds;

  const MemberRealtimeDelta({
    this.upserts = const [],
    this.deletedIds = const [],
  });
}

/// Shared filter used by the in-memory store and tests. SQLite implements the
/// same rules with indexed columns so large churches are not loaded into RAM.
bool memberMatchesLocalQuery(
  MemberEntity member, {
  required String query,
  String? meetingId,
  String? classId,
  String? scope,
  bool activeOnly = true,
}) {
  if (activeOnly && !member.isActive) {
    return false;
  }
  if (scope != null &&
      scope.isNotEmpty &&
      scope != 'all' &&
      member.scope.value != scope) {
    return false;
  }
  if (classId != null &&
      classId.isNotEmpty &&
      member.sundaySchoolClassId != classId) {
    return false;
  }
  if (meetingId != null &&
      meetingId.isNotEmpty &&
      member.meetingId != meetingId &&
      !member.meetingIds.contains(meetingId)) {
    return false;
  }
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return member.fullName.toLowerCase().contains(normalized) ||
      (member.code ?? '').toLowerCase().contains(normalized) ||
      (member.phone ?? '').toLowerCase().contains(normalized);
}

/// In-memory store used by tests and as the query-semantics reference.
class MemberMemoryStore implements MemberLocalStore {
  final Map<String, Map<String, MemberEntity>> _byChurch = {};

  Map<String, MemberEntity> _church(String churchId) =>
      _byChurch.putIfAbsent(churchId, () => {});

  @override
  Future<void> upsert(String churchId, MemberEntity member) async {
    _church(churchId)[member.id] = member;
  }

  @override
  Future<void> upsertMany(
    String churchId,
    Iterable<MemberEntity> members,
  ) async {
    final church = _church(churchId);
    for (final member in members) {
      church[member.id] = member;
    }
  }

  @override
  Future<void> deleteMember(String churchId, String id) async {
    _church(churchId).remove(id);
  }

  @override
  Future<List<MemberEntity>> readAll(String churchId) async {
    return _church(churchId).values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<List<MemberEntity>> readByIds(
    String churchId,
    Iterable<String> ids,
  ) async {
    final church = _church(churchId);
    return [
      for (final id in ids)
        if (church[id] != null) church[id]!,
    ];
  }

  @override
  Future<MemberEntity?> readById(String churchId, String id) async {
    return _church(churchId)[id];
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
    final filtered =
        _church(churchId).values
            .where(
              (member) => memberMatchesLocalQuery(
                member,
                query: query,
                meetingId: meetingId,
                classId: classId,
                scope: scope,
                activeOnly: activeOnly,
              ),
            )
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final safePage = page < 0 ? 0 : page;
    final start = safePage * pageSize;
    final items = start >= filtered.length
        ? <MemberEntity>[]
        : filtered.sublist(start, (start + pageSize).clamp(0, filtered.length));
    return MemberQueryPage(
      items: items,
      hasMore: start + items.length < filtered.length,
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
    final members = _church(churchId).values.where((member) {
      return !activeOnly || member.isActive;
    });
    var sundaySchool = 0;
    var meetings = 0;
    var total = 0;
    for (final member in members) {
      total += 1;
      if (member.scope == MemberScope.sundaySchoolClass) {
        sundaySchool += 1;
      } else if (member.scope == MemberScope.meeting) {
        meetings += 1;
      }
    }
    return MembersListCounts(
      total: total,
      sundaySchool: sundaySchool,
      meetings: meetings,
    );
  }

  @override
  Future<void> clear() async {
    _byChurch.clear();
  }
}
