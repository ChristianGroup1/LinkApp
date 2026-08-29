import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS has the camera permission required by QR attendance', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('<key>NSCameraUsageDescription</key>'));
    expect(infoPlist, contains('لمسح رمز QR الخاص بالعضو'));
  });

  test('iOS CocoaPods include every recent native feature', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final lockfile = File('ios/Podfile.lock').readAsStringSync();

    expect(podfile, contains("platform :ios, '15.0'"));
    for (final pod in [
      'mobile_scanner',
      'app_settings',
      'printing',
      'sentry_flutter',
      'connectivity_plus',
      'shared_preferences_foundation',
      'file_picker',
    ]) {
      expect(lockfile, contains('  - $pod'), reason: '$pod is missing on iOS');
    }
  });
}
