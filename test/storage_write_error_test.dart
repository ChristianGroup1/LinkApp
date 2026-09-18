import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/diagnostics/storage_write_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The exact payload the server returned in the reported import failure.
const _reportedRowLevelSecurityError =
    'PostgrestException(message: new row violates row-level security policy '
    'for table "members", code: 42501, details: Forbidden, hint: null)';

void main() {
  test(
    'a refused row is explained as another-church or missing permission',
    () {
      final error = StorageWriteError.from(
        Exception(_reportedRowLevelSecurityError),
      );

      expect(error.failure, StorageWriteFailure.notAllowed);
      expect(error.code, '42501');
      expect(error.isNotAllowed, isTrue);

      final message = error.message(action: 'إضافة العضو');
      expect(message, contains('إضافة العضو'));
      expect(message, contains('كنيسة حسابك'));
      expect(message, contains('صلاحية'));
    },
  );

  test('raw SQL, codes and policy names never reach the interface', () {
    final message = StorageWriteError.from(
      Exception(_reportedRowLevelSecurityError),
    ).message(action: 'حفظ صف العضو');

    for (final leak in const [
      'PostgrestException',
      '42501',
      'row-level security',
      'details:',
      'hint:',
      '"members"',
    ]) {
      expect(message, isNot(contains(leak)), reason: 'leaked: $leak');
    }
  });

  test('a PostgrestException object is classified from its code', () {
    final error = StorageWriteError.from(
      const PostgrestException(
        message:
            'new row violates row-level security policy for table "members"',
        code: '42501',
        details: 'Forbidden',
      ),
    );

    expect(error.failure, StorageWriteFailure.notAllowed);
    expect(error.isNotAllowed, isTrue);
  });

  test('a refusal without a code is still recognised', () {
    final error = StorageWriteError.from(
      Exception(
        'new row violates row-level security policy for table "members"',
      ),
    );

    expect(error.failure, StorageWriteFailure.notAllowed);
    expect(error.summary, contains('كنيسة حسابك'));
  });

  test('a duplicate code inside the same church is reported as a conflict', () {
    final error = StorageWriteError.from(
      Exception(
        'PostgrestException(message: duplicate key value violates unique '
        'constraint "members_unique_code", code: 23505)',
      ),
    );

    expect(error.failure, StorageWriteFailure.conflict);
    final message = error.message(action: 'إضافة العضو');
    expect(message, contains('الكود التعريفي'));
    expect(message, isNot(contains('23505')));
    expect(message, isNot(contains('constraint')));
  });

  test('missing or invalid values are reported without server text', () {
    for (final code in const ['23502', '23514', '23503']) {
      final error = StorageWriteError.from(
        Exception('PostgrestException(message: broken, code: $code)'),
      );
      expect(error.failure, StorageWriteFailure.invalid, reason: code);
      final message = error.message(action: 'إضافة العضو');
      expect(message, contains('ناقصة أو غير صحيحة'));
      expect(message, isNot(contains(code)));
    }
  });

  test('a connection failure is reported as offline', () {
    final error = StorageWriteError.from(
      const SocketException('Failed host lookup: project.supabase.co'),
    );

    expect(error.failure, StorageWriteFailure.offline);
    final message = error.message(action: 'إضافة العضو');
    expect(message, contains('الخادم'));
    expect(message, contains('الاتصال'));
    expect(message, isNot(contains('SocketException')));
  });

  test('an unknown failure keeps only a short trimmed reason', () {
    final error = StorageWriteError.from(
      Exception(
        'PostgrestException(message: something unexpected happened on the '
        'server side, code: 42P01, details: relation does not exist)',
      ),
    );

    expect(error.failure, StorageWriteFailure.unknown);
    final message = error.message(action: 'إضافة العضو');
    expect(message, contains('something unexpected happened'));
    expect(message, isNot(contains('PostgrestException')));
    expect(message, isNot(contains('details')));
    expect(message.length, lessThan(200));
  });
}
