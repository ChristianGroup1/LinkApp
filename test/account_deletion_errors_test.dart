import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:link/core/auth/account_deletion_errors.dart';

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
}
