import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/auth/auth_flow_capabilities.dart';

void main() {
  test('native auth deep links are enabled outside web builds', () {
    expect(supportsNativeAuthDeepLinks, isTrue);
    expect(supportsPasswordResetEmail, isTrue);
    expect(supportsInvitations, isTrue);
  });
}
