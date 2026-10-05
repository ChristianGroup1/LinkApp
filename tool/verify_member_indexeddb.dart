// Compile with dart compile js and run in a browser. This checks actual
// IndexedDB persistence across a page reload, without a mocked database.
import 'package:link/data/offline/member_indexeddb_cache.dart';
import 'package:link/data/offline/member_local_store.dart';
import 'package:link/shared/data/app_models.dart';
import 'package:web/web.dart' as web;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

MemberEntity member(int index, {String church = 'church-a'}) => MemberEntity(
  id: 'member-$index',
  churchId: church,
  fullName: 'مخدوم ${index.toString().padLeft(4, '0')}',
  scope: index.isEven ? MemberScope.meeting : MemberScope.sundaySchoolClass,
  isActive: index % 5 != 0,
  meetingId: 'meeting-${index % 3}',
  meetingIds: index.isEven ? ['meeting-${index % 3}', 'copied-meeting'] : [],
  sundaySchoolClassId: index.isOdd ? 'class-${index % 3}' : null,
  code: 'CODE_$index%',
  phone: '012$index',
);

Future<void> main() async {
  try {
    final store = MemberIndexedDbCache(
      databaseName: 'link_members_verification',
    );
    if (web.window.location.search.contains('phase=reload')) {
      check(
        (await store.counts(churchId: 'church-a', activeOnly: false)).total ==
            1000,
        'committed rows survive page reload',
      );
      check(
        (await store.readById('church-b', 'member-1'))?.churchId == 'church-b',
        'tenant keys survive page reload',
      );
      await store.deleteMember('church-a', 'member-1');
      check(
        await store.readById('church-a', 'member-1') == null,
        'delete commits',
      );
      check(
        await store.readById('church-b', 'member-1') != null,
        'delete isolates tenant',
      );
      await store.clear();
      check(
        (await store.readAll('church-a')).isEmpty,
        'clear removes first tenant',
      );
      check(
        (await store.readAll('church-b')).isEmpty,
        'clear removes second tenant',
      );
      web.document.body!.textContent = 'PASS reload delete clear';
      return;
    }

    await store.clear();
    final members = List.generate(1000, member);
    await store.upsertMany('church-a', members);
    await store.upsert('church-b', member(1, church: 'church-b'));
    final counts = await store.counts(churchId: 'church-a');
    check(
      counts.total == 800 &&
          counts.meetings == 400 &&
          counts.sundaySchool == 400,
      'active counts and scope counts',
    );
    final reference = MemberMemoryStore();
    await reference.upsertMany('church-a', members);
    for (final meeting in [null, 'meeting-1', 'copied-meeting']) {
      for (final cls in [null, 'class-1']) {
        for (final scope in [null, 'meeting', 'sunday_school_class']) {
          for (final query in ['', 'مخدوم 00', 'code_1%', '0129']) {
            for (final page in [0, 1, 20]) {
              final actual = await store.queryPage(
                churchId: 'church-a',
                page: page,
                pageSize: 50,
                meetingId: meeting,
                classId: cls,
                scope: scope,
                query: query,
              );
              final expected = await reference.queryPage(
                churchId: 'church-a',
                page: page,
                pageSize: 50,
                meetingId: meeting,
                classId: cls,
                scope: scope,
                query: query,
              );
              check(
                actual.items.map((m) => m.id).join(',') ==
                        expected.items.map((m) => m.id).join(',') &&
                    actual.hasMore == expected.hasMore,
                'indexed filter pagination: $meeting/$cls/$scope/$query/$page',
              );
            }
          }
        }
      }
    }
    check(
      (await store.readByIds('church-a', [
            'member-1',
            'member-1',
            'missing',
          ])).length ==
          1,
      'id lookups deduplicate and ignore missing rows',
    );
    final second = MemberIndexedDbCache(
      databaseName: 'link_members_verification',
    );
    await Future.wait(
      List.generate(
        20,
        (i) => (i.isEven ? store : second).upsert('church-a', member(i)),
      ),
    );
    final updated = member(
      2,
    ).copyWith(meetingIds: ['new-meeting'], clearMeetingId: true);
    await store.upsert('church-a', updated);
    check(
      !(await store.queryAll(
        churchId: 'church-a',
        meetingId: 'copied-meeting',
      )).any((m) => m.id == updated.id),
      'updating meetings removes old index entries',
    );
    check(
      (await store.queryAll(
            churchId: 'church-a',
            meetingId: 'new-meeting',
          )).single.id ==
          updated.id,
      'updating meetings creates new index entries',
    );
    web.document.body!.textContent =
        'PASS save filters pages concurrent writes';
  } catch (error, stack) {
    web.document.body!.textContent = 'FAIL $error\n$stack';
  }
}
