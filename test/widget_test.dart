import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:link/core/invitations/invitation_preview.dart';
import 'package:link/data/offline/invitation_create_result.dart';
import 'package:link/data/offline/offline_save_result.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/repositories/database_repository.dart';
import 'package:link/logic/auth/auth_bloc.dart';
import 'package:link/main.dart';
import 'package:link/presentation/screens/app_tour_screen.dart';
import 'package:link/presentation/screens/invitation_link_screen.dart';
import 'package:link/presentation/screens/my_invitations_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('signs out the recovery session after updating the password', () async {
    final repository = TestRepository();
    final bloc = AuthBloc(repository: repository);
    addTearDown(bloc.close);

    final states = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthPasswordUpdateLoading>(),
        isA<AuthPasswordUpdated>(),
      ]),
    );

    bloc.add(PasswordUpdateRequested(password: 'new-password'));
    await states;

    expect(repository.hasActiveSession(), isFalse);
  });

  test('shows a useful message when the device clock breaks TLS', () async {
    final repository = LoginFailureRepository(
      errorMessage:
          'AuthRetryableFetchException: CERTIFICATE_VERIFY_FAILED: certificate is not yet valid',
    );
    final bloc = AuthBloc(repository: repository);
    addTearDown(bloc.close);

    final states = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoginLoading>(),
        isA<AuthError>().having(
          (state) => state.message,
          'message',
          contains('فعّل التاريخ والوقت التلقائيين'),
        ),
      ]),
    );

    bloc.add(LoginRequested(email: 'admin@example.com', password: 'secret'));
    await states;
  });

  test(
    'tracks spotlight tour completion separately for each account',
    () async {
      SharedPreferences.setMockInitialValues({});

      await AppTourScreen.setTourCompleted(userId: 'user-a');

      expect(await AppTourScreen.isTourCompleted(userId: 'user-a'), isTrue);
      expect(await AppTourScreen.isTourCompleted(userId: 'user-b'), isFalse);
    },
  );

  testWidgets('keeps login credentials while a failed login is processed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = LoginFailureRepository();
    await repository.signOut();

    await tester.pumpWidget(
      RepositoryProvider<DatabaseRepository>.value(
        value: repository,
        child: BlocProvider<AuthBloc>(
          create: (_) =>
              AuthBloc(repository: repository)..add(AuthCheckRequested()),
          child: const MyApp(),
        ),
      ),
    );
    await _settle(tester);

    final emailField = find.byType(TextField).at(0);
    final passwordField = find.byType(TextField).at(1);
    await tester.enterText(emailField, 'admin@example.com');
    await tester.enterText(passwordField, 'password123  ');
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pump();

    expect(repository.submittedPassword, 'password123');

    expect(
      tester.widget<TextField>(emailField).controller!.text,
      'admin@example.com',
    );
    expect(
      tester.widget<TextField>(passwordField).controller!.text,
      'password123  ',
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _settle(tester);

    expect(
      tester.widget<TextField>(emailField).controller!.text,
      'admin@example.com',
    );
    expect(
      tester.widget<TextField>(passwordField).controller!.text,
      'password123  ',
    );
    expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
  });

  testWidgets(
    'signs out account x before opening signup for invitation account y',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = InvitationMismatchRepository();
      final bloc = AuthBloc(repository: repository)..add(AuthCheckRequested());
      addTearDown(bloc.close);

      await tester.pumpWidget(
        RepositoryProvider<DatabaseRepository>.value(
          value: repository,
          child: BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const MaterialApp(
              home: InvitationLinkScreen(inviteToken: 'invite-y'),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.textContaining('y@example.com'), findsAtLeastNWidgets(1));
      expect(find.text('تسجيل الخروج وإنشاء حساب المدعو'), findsOneWidget);

      await tester.tap(find.text('تسجيل الخروج وإنشاء حساب المدعو'));
      await _settle(tester);

      expect(repository.hasActiveSession(), isFalse);
      expect(find.text('إكمال الانضمام'), findsOneWidget);
      final emailField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(emailField.controller!.text, 'y@example.com');
      expect(emailField.readOnly, isTrue);
    },
  );

  testWidgets('reject button only declines and never accepts an invitation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InvitationActionRepository();
    final bloc = AuthBloc(repository: repository)..add(AuthCheckRequested());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      RepositoryProvider<DatabaseRepository>.value(
        value: repository,
        child: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const MaterialApp(home: MyInvitationsScreen()),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رفض الدعوة'));
    await _settle(tester);

    expect(repository.declineCalls, 1);
    expect(repository.acceptCalls, 0);
  });

  testWidgets('renders login and navigates to dashboard', (tester) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestRepository();
    await repository.signOut();
    SharedPreferences.setMockInitialValues({});
    await AppTourScreen.setTourCompleted(userId: 'prof-1');

    await tester.pumpWidget(
      RepositoryProvider<DatabaseRepository>.value(
        value: repository,
        child: BlocProvider<AuthBloc>(
          create: (_) =>
              AuthBloc(repository: repository)..add(AuthCheckRequested()),
          child: const MyApp(),
        ),
      ),
    );

    await _settle(tester);

    expect(
      find.text('أدخل البريد الإلكتروني وكلمة المرور للبدء'),
      findsOneWidget,
    );
    expect(find.text('تسجيل الدخول'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('تسجيل الدخول').last);
    await _settle(tester);

    // Verify dashboard displays
    expect(find.text('أهلاً بك، مينا سمير'), findsOneWidget);
    expect(find.text('إجمالي الأعضاء'), findsOneWidget);
    expect(find.text('أعياد الميلاد القادمة'), findsOneWidget);
    expect(find.text('اليوم 🎉'), findsOneWidget);

    // Open meetings from dashboard entry
    await tester.ensureVisible(find.text('الاجتماعات').last);
    await _settle(tester);
    await tester.tap(find.text('الاجتماعات').last);
    await _settle(tester);
    expect(find.text('الاجتماعات'), findsAtLeastNWidgets(1));
    await tester.binding.handlePopRoute();
    await _settle(tester);

    // Tap Attendance tab (inactive tabs show icon only in bubble nav)
    await tester.tap(find.byIcon(Icons.checklist_rtl_outlined));
    await _settle(tester);
    expect(find.text('تسجيل الحضور الأسبوعي'), findsOneWidget);

    // Open records from dashboard entry
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _settle(tester);
    expect(find.text('السجلات'), findsNothing);
    await tester.tap(find.text('سجلات الحضور'));
    await _settle(tester);
    expect(find.text('السجلات'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);

    // Tap Members tab
    await tester.tap(find.byIcon(Icons.groups_outlined));
    await _settle(tester);
    expect(find.text('الأعضاء'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('استيراد وتصدير Excel'), findsOneWidget);
    expect(find.byTooltip('تعديل مريم جرجس'), findsOneWidget);
    expect(find.byTooltip('حذف مريم جرجس'), findsOneWidget);

    // Opening a member uses a dedicated details screen, not a popup menu.
    await tester.tap(find.text('مريم جرجس'));
    await _settle(tester);
    expect(find.text('بيانات العضو'), findsOneWidget);
    expect(find.text('البيانات الأساسية'), findsOneWidget);
    expect(find.text('الحضور والغياب'), findsOneWidget);
    expect(find.text('حضر'), findsOneWidget);
    expect(find.text('غاب'), findsOneWidget);
    expect(find.text('50٪'), findsOneWidget);
    expect(find.text('حاضر'), findsOneWidget);
    expect(find.text('غائب'), findsOneWidget);
    expect(find.text('التواصل والعائلة'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settle(tester);
    expect(find.text('الأعضاء'), findsAtLeastNWidgets(1));

    // Tap Settings tab
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await _settle(tester);
    expect(find.text('إعدادات الحساب والخدمة'), findsOneWidget);
  });
}

class LoginFailureRepository extends TestRepository {
  final String errorMessage;
  String? submittedPassword;

  LoginFailureRepository({this.errorMessage = 'بيانات الدخول غير صحيحة'});

  @override
  Future<AppProfile?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    submittedPassword = password;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    throw Exception(errorMessage);
  }
}

class TestRepository implements DatabaseRepository {
  AppProfile? _profile = const AppProfile(
    id: 'prof-1',
    churchId: 'ch-1',
    fullName: 'مينا سمير',
    role: AppRole.superAdmin,
    email: 'admin@example.com',
    phone: '+201234567890',
  );

  @override
  bool hasActiveSession() => _profile != null;

  final List<MeetingEntity> _meetings = [
    const MeetingEntity(
      id: 'mtg-1',
      churchId: 'ch-1',
      name: 'Kids Meeting',
      nameAr: 'اجتماع الأطفال',
      kind: MeetingKind.sundaySchool,
      weekday: 7,
      isActive: true,
    ),
  ];

  final List<SundaySchoolClassEntity> _classes = [
    const SundaySchoolClassEntity(
      id: 'cls-1',
      churchId: 'ch-1',
      meetingId: 'mtg-1',
      name: 'Primary 1',
      nameAr: 'أولى ابتدائي',
      displayOrder: 1,
      isActive: true,
    ),
  ];

  final List<MemberEntity> _members = [
    MemberEntity(
      id: 'mem-1',
      churchId: 'ch-1',
      fullName: 'مريم جرجس',
      scope: MemberScope.sundaySchoolClass,
      sundaySchoolClassId: 'cls-1',
      code: 'LN-0047',
      phone: '+201224567890',
      birthDate: DateTime(
        DateTime.now().year - 12,
        DateTime.now().month,
        DateTime.now().day,
      ),
      isActive: true,
    ),
  ];

  final List<AttendanceSessionEntity> _sessions = [];
  final List<AttendanceRecordEntity> _records = [];
  final List<FollowUpEntity> _followUps = [];

  @override
  Future<AppProfile?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    _profile = AppProfile(
      id: 'prof-1',
      churchId: 'ch-1',
      fullName: 'مينا سمير',
      role: AppRole.superAdmin,
      email: email,
      phone: '+201234567890',
    );
    return _profile;
  }

  @override
  Future<AppProfile?> signUpWithEmailAndPassword({
    required String name,
    required String churchName,
    required String email,
    required String password,
    String? phone,
  }) async {
    _profile = AppProfile(
      id: 'prof-1',
      churchId: 'ch-1',
      fullName: name,
      role: AppRole.classLeader,
      email: email,
      phone: phone,
    );
    return _profile;
  }

  @override
  Future<void> signOut() async {
    _profile = null;
  }

  @override
  Future<void> deleteCurrentAccount() async {
    _profile = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<List<MemberAttendanceHistoryEntry>> getMemberAttendanceHistory(
    String memberId,
  ) async => [
    MemberAttendanceHistoryEntry(
      recordId: 'record-1',
      sessionId: 'session-1',
      meetingId: 'mtg-1',
      classId: 'cls-1',
      sessionDate: DateTime(2026, 8, 1),
      sessionTitle: 'الأسبوع الأول',
      status: AttendanceStatus.present,
    ),
    MemberAttendanceHistoryEntry(
      recordId: 'record-2',
      sessionId: 'session-2',
      meetingId: 'mtg-1',
      classId: 'cls-1',
      sessionDate: DateTime(2026, 7, 25),
      sessionTitle: 'الأسبوع الرابع',
      status: AttendanceStatus.absent,
    ),
  ];

  @override
  Future<AppProfile> updateCurrentProfile({
    required String fullName,
    String? phone,
  }) async {
    final current = _profile!;
    _profile = AppProfile(
      id: current.id,
      churchId: current.churchId,
      fullName: fullName,
      role: current.role,
      email: current.email,
      phone: phone,
    );
    return _profile!;
  }

  @override
  Future<AppProfile?> getCurrentProfile() async => _profile;

  @override
  Future<List<AppProfile>> getProfiles() async =>
      _profile != null ? [_profile!] : [];

  @override
  Future<void> updateProfileRole(String userId, AppRole role) async {}

  @override
  Future<void> updateProfileStatus(String userId, bool isActive) async {}

  @override
  Future<Church?> getChurch(String id) async => const Church(
    id: 'ch-1',
    name: 'St. Mary Church',
    nameAr: 'كنيسة العذراء مريم',
    slug: 'st-mary',
  );

  @override
  Future<List<Church>> getAllChurches() async => [
    const Church(
      id: 'ch-1',
      name: 'St. Mary Church',
      nameAr: 'كنيسة العذراء مريم',
      slug: 'st-mary',
    ),
  ];

  @override
  Future<bool> updateChurch(
    String id,
    String nameAr,
    String? phone,
    String? address,
  ) async => true;

  @override
  Future<List<MeetingEntity>> getMeetings() async => _meetings;

  @override
  Future<OfflineSaveResult<MeetingEntity>> createMeeting({
    required String name,
    required String nameAr,
    required MeetingKind kind,
    required int weekday,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final m = MeetingEntity(
      id: 'mtg-${_meetings.length + 1}',
      churchId: 'ch-1',
      name: name,
      nameAr: nameAr,
      kind: kind,
      weekday: weekday,
      isActive: true,
      attendanceReminderMinutes: attendanceReminderMinutes,
      description: description,
    );
    _meetings.add(m);
    return OfflineSaveResult(data: m, syncedToServer: true);
  }

  @override
  Future<OfflineSaveResult<MeetingEntity>> updateMeeting({
    required String id,
    required String name,
    required String nameAr,
    required int weekday,
    required bool isActive,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final m = MeetingEntity(
      id: id,
      churchId: 'ch-1',
      name: name,
      nameAr: nameAr,
      kind: MeetingKind.normal,
      weekday: weekday,
      isActive: isActive,
      attendanceReminderMinutes: attendanceReminderMinutes,
      description: description,
    );
    return OfflineSaveResult(data: m, syncedToServer: true);
  }

  @override
  Future<bool> deleteMeeting(String id) async {
    _meetings.removeWhere((m) => m.id == id);
    return true;
  }

  @override
  Future<List<SundaySchoolClassEntity>> getSundaySchoolClasses(
    String meetingId,
  ) async => _classes.where((c) => c.meetingId == meetingId).toList();

  @override
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses() async =>
      _classes;

  @override
  Future<OfflineSaveResult<SundaySchoolClassEntity>> createSundaySchoolClass({
    required String meetingId,
    required String name,
    required String nameAr,
    required int displayOrder,
  }) async {
    final c = SundaySchoolClassEntity(
      id: 'cls-${_classes.length + 1}',
      churchId: 'ch-1',
      meetingId: meetingId,
      name: name,
      nameAr: nameAr,
      displayOrder: displayOrder,
      isActive: true,
    );
    _classes.add(c);
    return OfflineSaveResult(data: c, syncedToServer: true);
  }

  @override
  Future<OfflineSaveResult<SundaySchoolClassEntity>> updateSundaySchoolClass({
    required String id,
    required String name,
    required String nameAr,
    required int displayOrder,
    required bool isActive,
  }) async {
    final c = SundaySchoolClassEntity(
      id: id,
      churchId: 'ch-1',
      meetingId: 'mtg-1',
      name: name,
      nameAr: nameAr,
      displayOrder: displayOrder,
      isActive: isActive,
    );
    return OfflineSaveResult(data: c, syncedToServer: true);
  }

  @override
  Future<bool> deleteSundaySchoolClass(String id) async {
    _classes.removeWhere((c) => c.id == id);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getClassAssignments(
    String classId,
  ) async => [];

  @override
  Future<void> assignClassLeader(
    String classId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {}

  @override
  Future<void> assignAllMeetingClasses(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {}

  @override
  Future<void> removeClassAssignment(String assignmentId) async {}

  @override
  Future<List<Map<String, dynamic>>> getMeetingAssignments(
    String meetingId,
  ) async => [];

  @override
  Future<void> assignMeetingOfficer(
    String meetingId,
    String userId, {
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {}

  @override
  Future<void> removeMeetingAssignment(String assignmentId) async {}

  @override
  Future<List<MemberEntity>> getAllMembers() async => _members;

  @override
  Future<List<MemberEntity>> getClassMembers(String classId) async =>
      _members.where((m) => m.sundaySchoolClassId == classId).toList();

  @override
  Future<List<MemberEntity>> getMeetingMembers(String meetingId) async =>
      _members.where((m) => m.meetingId == meetingId).toList();

  @override
  Future<MemberEntity?> getMemberDetails(String memberId) async {
    final list = _members.where((m) => m.id == memberId).toList();
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> createMember({
    DateTime? birthDate,
    String? code,
    required String fullName,
    String? meetingId,
    String? parentName,
    String? parentPhone,
    String? phone,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? notes,
  }) async {
    final m = MemberEntity(
      id: 'mem-${_members.length + 1}',
      churchId: 'ch-1',
      fullName: fullName,
      scope: scope,
      sundaySchoolClassId: sundaySchoolClassId,
      meetingId: meetingId,
      code: code,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      birthDate: birthDate,
      notes: notes,
      isActive: true,
    );
    _members.add(m);
    return OfflineSaveResult(data: m, syncedToServer: true);
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> updateMember({
    required String id,
    DateTime? birthDate,
    String? code,
    required String fullName,
    String? meetingId,
    String? parentName,
    String? parentPhone,
    String? phone,
    required MemberScope scope,
    String? sundaySchoolClassId,
    required bool isActive,
    String? notes,
  }) async {
    final m = MemberEntity(
      id: id,
      churchId: 'ch-1',
      fullName: fullName,
      scope: scope,
      sundaySchoolClassId: sundaySchoolClassId,
      meetingId: meetingId,
      code: code,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      birthDate: birthDate,
      notes: notes,
      isActive: isActive,
    );
    return OfflineSaveResult(data: m, syncedToServer: true);
  }

  @override
  Future<bool> deleteMember(String id) async {
    _members.removeWhere((m) => m.id == id);
    return true;
  }

  @override
  Future<List<AttendanceSessionEntity>> getSessions(
    String meetingId, {
    String? classId,
  }) async => _sessions;

  @override
  Future<OfflineSaveResult<AttendanceSessionEntity>> createWeeklySession({
    required String meetingId,
    String? classId,
    required DateTime sessionDate,
    required int weekNumber,
    String? title,
  }) async {
    final s = AttendanceSessionEntity(
      id: 'sess-${_sessions.length + 1}',
      churchId: 'ch-1',
      meetingId: meetingId,
      classId: classId,
      sessionDate: sessionDate,
      weekNumber: weekNumber,
      title: title,
    );
    _sessions.add(s);
    return OfflineSaveResult(data: s, syncedToServer: true);
  }

  @override
  Future<bool> deleteWeeklySession(
    String sessionId, {
    String? meetingId,
    String? classId,
  }) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    return true;
  }

  @override
  Future<List<AttendanceRecordEntity>> getAttendanceRecords(
    String sessionId,
  ) async => _records;

  @override
  Future<bool> validateInvitationCode(String code) async => code.isNotEmpty;

  @override
  Future<InvitationPreview> getInvitationPreview(String inviteToken) async {
    return const InvitationPreview(valid: true, churchName: 'كنيسة الاختبار');
  }

  @override
  Future<void> declineInvitationByToken(String inviteToken) async {}

  @override
  Future<void> acceptInvitationLink(String inviteToken) async {}

  @override
  Future<List<Map<String, dynamic>>> getUserReceivedInvitations() async => [];

  @override
  Future<AppProfile?> signUpWithInvitationToken({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String inviteToken,
  }) async => signUpWithActivationCode(
    name: name,
    email: email,
    password: password,
    phone: phone,
    code: inviteToken,
  );

  @override
  Future<bool> saveAttendanceRecords({
    required String sessionId,
    required Map<String, AttendanceStatus> statusesByMemberId,
  }) async {
    statusesByMemberId.forEach((memberId, status) {
      _records.removeWhere(
        (r) => r.sessionId == sessionId && r.memberId == memberId,
      );
      _records.add(
        AttendanceRecordEntity(
          id: 'rec-${_records.length + 1}',
          sessionId: sessionId,
          memberId: memberId,
          status: status,
        ),
      );
    });
    return true;
  }

  @override
  Future<List<FollowUpEntity>> getMemberFollowUps(String memberId) async =>
      _followUps.where((f) => f.memberId == memberId).toList();

  @override
  Future<List<FollowUpEntity>> getAllFollowUps() async => _followUps;

  @override
  Future<bool> addFollowUp({
    required String memberId,
    String? sessionId,
    String? reason,
    required String contactStatus,
    String? result,
    String? responsibleUserId,
    required DateTime followUpDate,
  }) async {
    final f = FollowUpEntity(
      id: 'f-${_followUps.length + 1}',
      churchId: 'ch-1',
      memberId: memberId,
      sessionId: sessionId,
      reason: reason,
      contactStatus: contactStatus,
      result: result,
      responsibleUserId: responsibleUserId,
      followUpDate: followUpDate,
    );
    _followUps.add(f);
    return true;
  }

  @override
  Future<bool> deleteFollowUp(String id) async {
    _followUps.removeWhere((f) => f.id == id);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceReportStats() async {
    return _members
        .map(
          (m) => {
            'member_id': m.id,
            'recorded_weeks': 10,
            'present_weeks': 8,
            'absent_weeks': 2,
            'excused_weeks': 0,
            'attendance_percentage': 80.0,
          },
        )
        .toList();
  }

  @override
  Future<AppProfile?> signUpWithActivationCode({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String code,
  }) async {
    _profile = AppProfile(
      id: 'prof-invited-1',
      churchId: 'ch-1',
      fullName: name,
      role: AppRole.classLeader,
      email: email,
      phone: phone,
    );
    return _profile;
  }

  @override
  Future<OfflineSaveResult<InvitationCreateResult>> createInvitation({
    required String fullName,
    String? email,
    String? phone,
    required AppRole role,
    String? targetId,
    String? assignmentScope,
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    return OfflineSaveResult(
      data: const InvitationCreateResult(
        code: 'ACT-TEST1',
        invitationId: 'inv-test-1',
        inviteToken: 'token-test-1',
        inviteLink: 'https://example.com/invite/token-test-1',
      ),
      syncedToServer: true,
    );
  }

  @override
  Future<void> sendInvitationEmail(String invitationId) async {}

  @override
  Future<List<HelperInvitation>> getInvitations() async {
    return [];
  }

  @override
  Future<bool> updateInvitation({
    required HelperInvitation invitation,
    required String fullName,
    String? email,
  }) async => true;

  @override
  Future<bool> deleteInvitation(String id) async => true;

  @override
  Future<List<Map<String, dynamic>>> getUserClassAssignments(
    String userId,
  ) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getUserMeetingAssignments(
    String userId,
  ) async {
    return [];
  }

  @override
  Stream<List<AttendanceRecordEntity>> subscribeToAttendanceRecords(
    String sessionId,
  ) {
    return Stream.value([]);
  }

  @override
  Future<void> syncPendingOfflineData() async {}

  @override
  Future<bool> hasPendingOfflineData() async => false;

  @override
  Future<void> warmOfflineCache() async {}
}

class InvitationMismatchRepository extends TestRepository {
  @override
  Future<InvitationPreview> getInvitationPreview(String inviteToken) async {
    return const InvitationPreview(
      valid: true,
      status: 'pending',
      churchName: 'كنيسة الاختبار',
      inviteeName: 'User Y',
      email: 'y@example.com',
    );
  }
}

class InvitationActionRepository extends TestRepository {
  int acceptCalls = 0;
  int declineCalls = 0;
  bool declined = false;

  @override
  Future<List<Map<String, dynamic>>> getUserReceivedInvitations() async => [
    {
      'id': 'invite-1',
      'church_id': 'ch-1',
      'full_name': 'مينا سمير',
      'email': 'admin@example.com',
      'role': 'attendance_officer',
      'assignment_scope': 'meeting',
      'invite_token': 'token-1',
      'is_used': false,
      'declined_at': declined ? '2026-08-24T00:00:00Z' : null,
      'target_exists': false,
      'churches': {'name': 'Test Church', 'name_ar': 'كنيسة الاختبار'},
    },
  ];

  @override
  Future<void> acceptInvitationLink(String inviteToken) async {
    acceptCalls++;
  }

  @override
  Future<void> declineInvitationByToken(String inviteToken) async {
    declineCalls++;
    declined = true;
  }
}
