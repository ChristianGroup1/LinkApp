import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:link/core/auth/account_deletion_errors.dart';

void main() {
  test('shows the server reason for a rejected account deletion', () {
    final error = FunctionException(
      status: 409,
      details: const {
        'error':
            'لا يمكن حذف آخر مدير للكنيسة. عيّن مديرًا آخر أولًا ثم أعد المحاولة.',
      },
      reasonPhrase: 'Conflict',
    );

    expect(
      accountDeletionErrorMessage(error),
      'لا يمكن حذف آخر مدير للكنيسة. عيّن مديرًا آخر أولًا ثم أعد المحاولة.',
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
