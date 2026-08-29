import 'package:flutter_test/flutter_test.dart';

import 'package:link/core/diagnostics/diagnostics_visibility.dart';

void main() {
  test('Sentry verification is hidden outside debug builds', () {
    expect(shouldShowDeveloperDiagnostics(isDebugMode: false), isFalse);
    expect(shouldShowDeveloperDiagnostics(isDebugMode: true), isTrue);
  });
}
