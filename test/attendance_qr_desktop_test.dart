import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link/core/attendance/member_qr_payload.dart';
import 'package:link/core/theme/app_theme.dart';
import 'package:link/data/models/models.dart';
import 'package:link/features/attendance/presentation/attendance_qr_desktop_screen.dart';

void main() {
  testWidgets('native desktop dark theme renders with dark brightness', (
    tester,
  ) async {
    addTearDown(() => AppTheme.setBrightness(Brightness.light));
    AppTheme.setBrightness(Brightness.dark);

    expect(AppTheme.desktopDarkTheme.brightness, Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.desktopTheme,
        darkTheme: AppTheme.desktopDarkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Text('Desktop dark mode')),
      ),
    );

    expect(
      Theme.of(tester.element(find.text('Desktop dark mode'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('desktop QR reader accepts keyboard scanner input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const member = MemberEntity(
      id: 'member-1',
      churchId: 'church-1',
      fullName: 'مينا سمير',
      scope: MemberScope.meeting,
      meetingId: 'meeting-1',
      code: 'M-001',
      isActive: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AttendanceQrDesktopScreen(
          members: [member],
          initialStatuses: {},
        ),
      ),
    );

    expect(find.text('قارئ QR على الكمبيوتر'), findsOneWidget);
    expect(find.textContaining('قارئ QR عبر USB'), findsOneWidget);

    const payload = MemberQrPayload(memberId: 'member-1', churchId: 'church-1');
    await tester.enterText(find.byType(TextField), payload.encode());
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('تم تسجيل مينا سمير حاضر'), findsOneWidget);
    expect(find.text('الأعضاء الممسوحون (1)'), findsOneWidget);
    expect(find.text('مينا سمير'), findsOneWidget);
    expect(find.textContaining('1 حاضر بالـQR من 1'), findsOneWidget);
  });
}
