import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link/data/models/models.dart';
import 'package:link/features/church/presentation/widgets/servants_widgets.dart';

void main() {
  testWidgets('pending invitation stays readable and exposes edit action', (
    tester,
  ) async {
    dotenv.loadFromString(
      envString: 'INVITE_LINK_BASE_URL=https://example.com',
    );
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var editTapped = false;

    final invitation = HelperInvitation(
      id: 'inv-1',
      churchId: 'church-1',
      fullName: 'اسم خادم طويل للاختبار',
      email: 'very.long.pending.invitation@example.com',
      role: AppRole.attendanceOfficer,
      code: 'ACT-TEST1',
      inviteToken: 'a-very-long-invitation-token-that-must-not-break-the-card',
      isUsed: false,
      createdAt: DateTime(2026, 8, 22),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ServantsPendingInvitationsSection(
                  invitations: [invitation],
                  onEdit: (_) async => editTapped = true,
                  onDelete: (_) async {},
                  onResendEmail: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('بانتظار القبول'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('نسخ الرابط'), findsOneWidget);
    expect(find.text('إعادة الإرسال'), findsOneWidget);

    await tester.tap(find.text('تعديل'));
    await tester.pump();
    expect(editTapped, isTrue);
  });
}
