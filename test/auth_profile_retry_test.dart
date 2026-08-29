import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/auth/retry_nullable_load.dart';

void main() {
  test('retries a transient profile failure and returns the profile', () async {
    var calls = 0;

    final result = await retryNullableLoad<String>(
      load: () async {
        calls++;
        if (calls == 1) throw TimeoutException('temporary profile timeout');
        return 'profile-loaded';
      },
      delay: Duration.zero,
    );

    expect(result, 'profile-loaded');
    expect(calls, 2);
  });

  test('rethrows the last transient failure after all attempts', () async {
    var calls = 0;

    await expectLater(
      retryNullableLoad<String>(
        load: () async {
          calls++;
          throw TimeoutException('profile timeout');
        },
        attempts: 3,
        delay: Duration.zero,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 3);
  });
}
