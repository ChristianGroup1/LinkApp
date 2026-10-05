import 'member_local_store.dart';
import 'member_sqlite_cache.dart';

MemberLocalStore createMemberLocalStore() => MemberSqliteCache();

Future<void> restorePendingMembers(
  String churchId,
  MemberLocalStore store,
) async {}

void resetMemberStoreMigration() {}
