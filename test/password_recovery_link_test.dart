import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/auth/password_recovery_link.dart';
import 'package:link/presentation/screens/password_recovery_error_screen.dart';

void main() {
  test('uses the native app callback for password reset emails', () {
    expect(passwordResetRedirectUrl, 'io.supabase.link://reset-password');
  });

  group('extractPasswordRecoveryLinkError', () {
    test('reads an expired token error from query parameters', () {
      final error = extractPasswordRecoveryLinkError(
        Uri.parse(
          'io.supabase.link://reset-password?error=access_denied&error_code=otp_expired&error_description=Email%20link%20is%20invalid%20or%20has%20expired',
        ),
      );

      expect(error, isNotNull);
      expect(error!.code, 'otp_expired');
      expect(error.isExpiredOrUsed, isTrue);
    });

    test('reads recovery errors from the URL fragment', () {
      final error = extractPasswordRecoveryLinkError(
        Uri.parse(
          'io.supabase.link://reset-password#error=access_denied&error_description=Link%20already%20been%20used',
        ),
      );

      expect(error, isNotNull);
      expect(error!.isExpiredOrUsed, isTrue);
    });

    test('ignores valid reset links and invitation links', () {
      expect(
        extractPasswordRecoveryLinkError(
          Uri.parse('io.supabase.link://reset-password?code=valid-code'),
        ),
        isNull,
      );
      expect(
        extractPasswordRecoveryLinkError(
          Uri.parse('io.supabase.link://invite?error=access_denied'),
        ),
        isNull,
      );
    });
  });

  testWidgets('shows the expired recovery link error screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PasswordRecoveryErrorScreen(
          error: PasswordRecoveryLinkError(
            code: 'otp_expired',
            description: 'Email link is invalid or has expired',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('رابط إعادة التعيين غير صالح'), findsOneWidget);
    expect(find.textContaining('انتهت صلاحيته أو تم استخدامه'), findsOneWidget);
    expect(find.text('طلب رابط جديد'), findsOneWidget);
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
  });
}
