import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/errors/arabic_error_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final arabic = RegExp(r'[\u0600-\u06FF]');
  final latinWords = RegExp(r'[A-Za-z]{3,}');

  test('messages the app raised in Arabic pass through unchanged', () {
    expect(
      arabicErrorText(Exception('كود التفعيل غير صالح أو تم استخدامه مسبقاً.')),
      'كود التفعيل غير صالح أو تم استخدامه مسبقاً.',
    );
    expect(arabicErrorText(StateError('تعذر الحفظ')), 'تعذر الحفظ');
  });

  test('wrong credentials become a clear Arabic sentence', () {
    final message = arabicErrorText(
      const AuthException('Invalid login credentials', statusCode: '400'),
    );
    expect(message, 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
  });

  test('common auth failures are all translated', () {
    const cases = {
      'Email not confirmed': 'تأكيده',
      'User already registered': 'مسجل بالفعل',
      'Password should be at least 6 characters': 'كلمة المرور ضعيفة',
      'over_email_send_rate_limit': 'محاولات كثيرة',
      'Email link is invalid or has expired': 'انتهت صلاحية',
    };
    cases.forEach((raw, expected) {
      final message = arabicErrorText(AuthException(raw));
      expect(message, contains(expected), reason: raw);
      expect(message, isNot(matches(latinWords)), reason: raw);
    });
  });

  test('database refusals are translated by SQLSTATE', () {
    expect(
      arabicErrorText(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      ),
      contains('صلاحية'),
    );
    expect(
      arabicErrorText(
        const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        ),
      ),
      contains('مكرر'),
    );
    expect(
      arabicErrorText(
        const PostgrestException(
          message: 'null value in column "full_name"',
          code: '23502',
        ),
      ),
      contains('ناقصة'),
    );
  });

  test('network failures point to the connection', () {
    for (final raw in [
      'SocketException: Failed host lookup: example.com',
      'TimeoutException after 0:00:15.000000',
      'ClientException: Connection reset by peer',
    ]) {
      final message = arabicErrorText(Exception(raw));
      expect(message, contains('تحقق من الإنترنت'), reason: raw);
    }
  });

  test('a wrong device clock gets its own explanation', () {
    final message = arabicErrorText(
      Exception(
        'HandshakeException: CERTIFICATE_VERIFY_FAILED: certificate is not yet valid',
      ),
    );
    expect(message, contains('تاريخ أو وقت الجهاز'));
  });

  test('unknown errors fall back to Arabic without leaking English', () {
    final message = arabicErrorText(Exception('Some obscure failure text'));
    expect(message, matches(arabic));
    expect(message, isNot(contains('obscure')));
  });
}
