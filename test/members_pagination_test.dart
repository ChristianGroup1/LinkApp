import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/offline/member_local_store.dart';
import 'package:link/features/members/logic/members_bloc.dart';

import 'widget_test.dart';

void main() {
  group('MembersBloc pagination', () {
    test('should load the first page instead of every member', () async {
      final repository = TestRepository();
      repository.replaceMembers([
        for (var index = 0; index < 80; index++)
          MemberEntity(
            id: 'mem-$index',
            churchId: 'ch-1',
            fullName: 'عضو ${index.toString().padLeft(2, '0')}',
            scope: MemberScope.meeting,
            meetingId: 'mtg-1',
            meetingIds: const ['mtg-1'],
            isActive: true,
          ),
      ]);
      final bloc = MembersBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(LoadMembers());
      final loaded =
          await bloc.stream.firstWhere((state) => state is MembersLoaded)
              as MembersLoaded;

      expect(loaded.allMembers, hasLength(50));
      expect(loaded.hasMore, isTrue);
      expect(loaded.totalCount, 80);
    });

    test(
      'should append the next page when more members are requested',
      () async {
        final repository = TestRepository();
        repository.replaceMembers([
          for (var index = 0; index < 80; index++)
            MemberEntity(
              id: 'mem-$index',
              churchId: 'ch-1',
              fullName: 'عضو ${index.toString().padLeft(2, '0')}',
              scope: MemberScope.meeting,
              meetingId: 'mtg-1',
              meetingIds: const ['mtg-1'],
              isActive: true,
            ),
        ]);
        final bloc = MembersBloc(repository: repository);
        addTearDown(bloc.close);

        bloc.add(LoadMembers());
        await bloc.stream.firstWhere((state) => state is MembersLoaded);
        bloc.add(LoadMoreMembers());
        final loaded =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is MembersLoaded && state.allMembers.length > 50,
                )
                as MembersLoaded;

        expect(loaded.allMembers, hasLength(80));
        expect(loaded.hasMore, isFalse);
      },
    );

    test(
      'should search through the repository instead of the loaded page',
      () async {
        final repository = TestRepository();
        repository.addSeedMember(
          const MemberEntity(
            id: 'mem-hidden',
            churchId: 'ch-1',
            fullName: 'أندراوس فرج',
            scope: MemberScope.meeting,
            meetingId: 'mtg-1',
            meetingIds: ['mtg-1'],
            isActive: true,
          ),
        );
        final bloc = MembersBloc(repository: repository);
        addTearDown(bloc.close);

        bloc.add(LoadMembers());
        await bloc.stream.firstWhere((state) => state is MembersLoaded);
      bloc.add(SearchAndFilterMembers(query: 'أندراوس'));
      final loaded =
          await bloc.stream.firstWhere(
                (state) =>
                    state is MembersLoaded &&
                    state.query == 'أندراوس' &&
                    state.filteredMembers.length == 1 &&
                    state.filteredMembers.single.id == 'mem-hidden',
              )
              as MembersLoaded;

      expect(loaded.filteredMembers.single.fullName, 'أندراوس فرج');
      },
    );

    test('should merge a realtime member without replacing the page', () async {
      final repository = TestRepository();
      final bloc = MembersBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(LoadMembers());
      final first =
          await bloc.stream.firstWhere((state) => state is MembersLoaded)
              as MembersLoaded;
      final originalIds = first.allMembers.map((member) => member.id).toSet();

      bloc.add(
        MembersRealtimeUpdated(
          const MemberRealtimeDelta(
            upserts: [
              MemberEntity(
                id: 'mem-live',
                churchId: 'ch-1',
                fullName: 'يوسف حنا',
                scope: MemberScope.sundaySchoolClass,
                sundaySchoolClassId: 'cls-1',
                isActive: true,
              ),
            ],
          ),
        ),
      );
      final updated =
          await bloc.stream.firstWhere(
                (state) =>
                    state is MembersLoaded &&
                    state.allMembers.any((member) => member.id == 'mem-live'),
              )
              as MembersLoaded;

      expect(
        updated.allMembers.map((member) => member.id).toSet(),
        containsAll({...originalIds, 'mem-live'}),
      );
    });
  });
}
