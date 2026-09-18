import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/auth/account_deletion_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('shows the server reason when Auth cleanup is incomplete', () {
    final error = FunctionException(
      status: 500,
      details: const {
        'error':
            'تم حذف بيانات الكنيسة، لكن تعذر إنهاء حذف بعض حسابات الدخول. تواصل مع الدعم.',
      },
      reasonPhrase: 'Internal Server Error',
    );

    expect(
      accountDeletionErrorMessage(error),
      'تم حذف بيانات الكنيسة، لكن تعذر إنهاء حذف بعض حسابات الدخول. تواصل مع الدعم.',
    );
  });

  test('explains an expired account session', () {
    final error = FunctionException(
      status: 401,
      details: null,
      reasonPhrase: 'Unauthorized',
    );

    expect(accountDeletionErrorMessage(error), contains('سجّل الدخول'));
  });

  test('English FunctionException payloads are not shown raw', () {
    final error = FunctionException(
      status: 500,
      details: const {'error': 'Internal cleanup failed unexpectedly'},
      reasonPhrase: 'Internal Server Error',
    );

    final message = accountDeletionErrorMessage(error);
    expect(message, matches(RegExp(r'[\u0600-\u06FF]')));
    expect(message, isNot(contains('Internal cleanup')));
  });
}
