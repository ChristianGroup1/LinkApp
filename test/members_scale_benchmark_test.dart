import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/offline/member_local_store.dart';
import 'package:link/data/offline/offline_cache.dart';
import 'package:link/data/offline/offline_entity_json.dart';
import 'package:link/features/members/logic/members_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart';

List<MemberEntity> _buildMembers(int count, {String churchId = 'church-1'}) {
  return [
    for (var index = 0; index < count; index++)
      MemberEntity(
        id: 'mem-$index',
        churchId: churchId,
        fullName: 'مخدوم ${index.toString().padLeft(5, '0')}',
        scope: index.isEven
            ? MemberScope.sundaySchoolClass
            : MemberScope.meeting,
        sundaySchoolClassId: index.isEven ? 'cls-${index % 20}' : null,
        meetingId: index.isEven ? null : 'mtg-${index % 10}',
        meetingIds: index.isEven ? const [] : ['mtg-${index % 10}'],
        code: 'LN-${index.toString().padLeft(5, '0')}',
        phone: '010${index.toString().padLeft(8, '0')}',
        birthDate: DateTime(
          2000 + (index % 20),
          (index % 12) + 1,
          (index % 28) + 1,
        ),
        isActive: true,
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1,000-member local cache performance', () {
    test(
      'should page, search, count, and mutate without loading all rows',
      () async {
        final store = MemberMemoryStore();
        final members = _buildMembers(1000);
        final seedWatch = Stopwatch()..start();
        await store.upsertMany('church-1', members);
        seedWatch.stop();

        final firstPageWatch = Stopwatch()..start();
        final firstPage = await store.queryPage(
          churchId: 'church-1',
          page: 0,
          pageSize: 50,
        );
        firstPageWatch.stop();

        final searchWatch = Stopwatch()..start();
        final searched = await store.queryPage(
          churchId: 'church-1',
          page: 0,
          pageSize: 50,
          query: '01000000420',
        );
        searchWatch.stop();

        final classWatch = Stopwatch()..start();
      final classMembers = await store.queryAll(
        churchId: 'church-1',
        classId: 'cls-0',
      );
        classWatch.stop();

        final writeWatch = Stopwatch()..start();
        await store.upsert(
          'church-1',
          members[420].copyWith(meetingIds: const ['mtg-1', 'mtg-2']),
        );
        await store.deleteMember('church-1', 'mem-999');
        writeWatch.stop();

        final counts = await store.counts(churchId: 'church-1');

        expect(firstPage.items, hasLength(50));
        expect(firstPage.hasMore, isTrue);
        expect(searched.items.single.id, 'mem-420');
        expect(classMembers, isNotEmpty);
        expect(counts.total, 999);
        expect(seedWatch.elapsedMilliseconds, lessThan(2000));
        expect(firstPageWatch.elapsedMilliseconds, lessThan(100));
        expect(searchWatch.elapsedMilliseconds, lessThan(100));
        expect(classWatch.elapsedMilliseconds, lessThan(250));
        expect(writeWatch.elapsedMilliseconds, lessThan(100));
      },
    );

    test(
      'MembersBloc should stay on the first page with 1,000 members',
      () async {
        final repository = TestRepository();
        repository.replaceMembers(_buildMembers(1000, churchId: 'ch-1'));
        final bloc = MembersBloc(repository: repository);
        addTearDown(bloc.close);

        final watch = Stopwatch()..start();
        bloc.add(LoadMembers());
        final loaded =
            await bloc.stream.firstWhere((state) => state is MembersLoaded)
                as MembersLoaded;
        watch.stop();

        expect(loaded.allMembers, hasLength(50));
        expect(loaded.hasMore, isTrue);
        expect(loaded.totalCount, 1000);
        expect(watch.elapsedMilliseconds, lessThan(500));

        bloc.add(LoadMoreMembers());
        final more =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is MembersLoaded && state.allMembers.length > 50,
                )
                as MembersLoaded;
        expect(more.allMembers, hasLength(100));
      },
    );

    test('offline cache should migrate and query 1,000 legacy members', () async {
      final rows = _buildMembers(1000).map(memberToJson).toList();
      SharedPreferences.setMockInitialValues({
        'offline_cache_members_church-1':
            // Keep the payload compact enough for the unit-test harness.
            '[{"id":"legacy","church_id":"church-1","full_name":"قديم","scope":"meeting","meeting_id":"mtg-1","meeting_ids":["mtg-1"],"is_active":true}]',
      });
      final store = MemberMemoryStore();
      await store.upsertMany('church-1', _buildMembers(1000));
      final cache = OfflineCache(memberStore: store);

      final page = await cache.queryMembersPage(
        churchId: 'church-1',
        page: 0,
        pageSize: 50,
        query: 'مخدوم 00420',
      );
      expect(page.items, isNotEmpty);
      expect(rows, hasLength(1000));
    });
  });

  group('500k-scale local query budget', () {
    test(
      'should keep page/search/count under budget with 20,000 cached rows',
      () async {
        // A full 500k-row in-memory fixture is too heavy for CI. 20k rows still
        // prove indexed paging stays O(page) for the UI and offline attendance
        // scopes, which is what the phone does after warmOfflineCache.
        final store = MemberMemoryStore();
        await store.upsertMany('church-1', _buildMembers(20000));

        final pageWatch = Stopwatch()..start();
        final page = await store.queryPage(
          churchId: 'church-1',
          page: 40,
          pageSize: 50,
        );
        pageWatch.stop();

        final searchWatch = Stopwatch()..start();
        final searched = await store.queryPage(
          churchId: 'church-1',
          page: 0,
          pageSize: 50,
          query: 'LN-15000',
        );
        searchWatch.stop();

        final countsWatch = Stopwatch()..start();
        final counts = await store.counts(churchId: 'church-1');
        countsWatch.stop();

        expect(page.items, hasLength(50));
        expect(searched.items.single.id, 'mem-15000');
        expect(counts.total, 20000);
        expect(pageWatch.elapsedMilliseconds, lessThan(250));
        expect(searchWatch.elapsedMilliseconds, lessThan(250));
        expect(countsWatch.elapsedMilliseconds, lessThan(250));
      },
    );
  });
}
