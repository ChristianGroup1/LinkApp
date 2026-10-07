import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/theme/app_theme.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/repositories/database_repository.dart';
import 'package:link/features/members/data/member_location.dart';
import 'package:link/features/members/logic/members_bloc.dart';
import 'package:link/features/members/presentation/add_edit_member_screen.dart';
import 'package:link/features/members/presentation/member_details_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.configureBundledFonts();

  group('MemberEntity address and location', () {
    test('reads address and numeric coordinates', () {
      final member = MemberEntity.fromJson({
        'id': 'mem-1',
        'church_id': 'church-1',
        'full_name': 'مينا سمير',
        'scope': 'meeting',
        'meeting_id': 'meeting-1',
        'is_active': true,
        'address': '  شارع الكنيسة  ',
        'latitude': 30,
        'longitude': '31.2357',
      });

      expect(member.address, 'شارع الكنيسة');
      expect(member.latitude, 30);
      expect(member.longitude, closeTo(31.2357, 0.000001));
    });

    test('keeps members without an address or pin', () {
      final member = MemberEntity.fromJson({
        'id': 'mem-1',
        'church_id': 'church-1',
        'full_name': 'مينا سمير',
        'scope': 'meeting',
        'meeting_id': 'meeting-1',
        'is_active': true,
      });

      expect(member.address, isNull);
      expect(member.latitude, isNull);
      expect(member.longitude, isNull);
    });

    test('drops a coordinate pair that is outside the valid range', () {
      final member = MemberEntity.fromJson({
        'id': 'mem-1',
        'church_id': 'church-1',
        'full_name': 'مينا سمير',
        'scope': 'meeting',
        'meeting_id': 'meeting-1',
        'is_active': true,
        'latitude': 120,
        'longitude': 31,
      });

      expect(member.latitude, isNull);
      expect(member.longitude, isNull);
    });
  });

  group('MemberLocation', () {
    test('treats an empty coordinate pair as no location', () {
      final result = MemberLocation.parseText(
        latitudeText: '',
        longitudeText: ' ',
      );

      expect(result.error, isNull);
      expect(result.location, isNull);
    });

    test('builds a Google Maps directions link', () {
      const location = MemberLocation(latitude: 30.0444, longitude: 31.2357);

      final uri = location.directionsUri;
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], contains('30.0444'));
      expect(uri.queryParameters['destination'], contains('31.2357'));
      expect(
        MemberLocation.tileUrlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(MemberLocation.userAgentPackageName, 'com.linkapp.church');
      expect(
        MemberLocation.copyrightUri.toString(),
        'https://www.openstreetmap.org/copyright',
      );
    });
  });

  testWidgets('edit form shows the saved address and location', (tester) async {
    final repository = _AddressRepository();
    final bloc = MembersBloc(repository: repository);
    const member = MemberEntity(
      id: 'mem-1',
      churchId: 'ch-1',
      fullName: 'مينا سمير',
      scope: MemberScope.meeting,
      meetingId: 'mtg-1',
      address: 'شارع الكنيسة، مدينة نصر',
      latitude: 30.0444,
      longitude: 31.2357,
      isActive: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<DatabaseRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: bloc,
            child: const AddEditMemberScreen(member: member),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('شارع الكنيسة، مدينة نصر'), findsOneWidget);
    expect(find.textContaining('تم تحديد الموقع'), findsOneWidget);
    expect(find.text('تحديد الموقع على الخريطة'), findsNothing);
    expect(find.text('تعديل الموقع على الخريطة'), findsOneWidget);
    expect(find.text('استخدام موقعي الحالي'), findsOneWidget);

    final editOnMap = find.text('تعديل الموقع على الخريطة');
    await tester.ensureVisible(editOnMap);
    await tester.pump();
    await tester.tap(editOnMap);
    await _settle(tester);

    expect(find.text('تحديد الموقع'), findsOneWidget);
    expect(find.byKey(const Key('member-location-map')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details show the address and a map for a saved pin', (
    tester,
  ) async {
    final repository = _AddressRepository();
    final bloc = MembersBloc(repository: repository);
    const member = MemberEntity(
      id: 'mem-1',
      churchId: 'ch-1',
      fullName: 'مينا سمير',
      scope: MemberScope.meeting,
      meetingId: 'mtg-1',
      address: 'شارع الكنيسة، مدينة نصر',
      latitude: 30.0444,
      longitude: 31.2357,
      isActive: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<DatabaseRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: bloc,
            child: const MemberDetailsScreen(
              member: member,
              classes: [],
              meetings: [
                MeetingEntity(
                  id: 'mtg-1',
                  churchId: 'ch-1',
                  name: 'Youth',
                  nameAr: 'اجتماع الشباب',
                  kind: MeetingKind.normal,
                  weekday: 5,
                  isActive: true,
                ),
              ],
              canManage: false,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('شارع الكنيسة، مدينة نصر'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('الموقع على الخريطة'), 400);
    expect(find.text('الموقع على الخريطة'), findsOneWidget);
    expect(find.text('فتح في خرائط جوجل'), findsOneWidget);
    expect(find.byKey(const Key('member-location-map')), findsOneWidget);
    expect(find.text('30.0444، 31.2357'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AddressRepository implements DatabaseRepository {
  @override
  Future<AppProfile?> getCurrentProfile() async => const AppProfile(
    id: 'prof-1',
    churchId: 'ch-1',
    fullName: 'مينا سمير',
    role: AppRole.superAdmin,
  );

  @override
  Future<List<MeetingEntity>> getMeetings() async => const [
    MeetingEntity(
      id: 'mtg-1',
      churchId: 'ch-1',
      name: 'Youth',
      nameAr: 'اجتماع الشباب',
      kind: MeetingKind.normal,
      weekday: 5,
      isActive: true,
    ),
  ];

  @override
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses() async =>
      const [];

  @override
  Future<List<MemberAttendanceHistoryEntry>> getMemberAttendanceHistory(
    String memberId,
  ) async => const [];

  @override
  Future<List<FollowUpEntity>> getMemberFollowUps(String memberId) async =>
      const [];

  @override
  Future<List<AppProfile>> getProfiles() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
