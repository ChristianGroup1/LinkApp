import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/attendance/camera_permission_guidance.dart';

void main() {
  test('native mobile camera denial directs the user to app settings', () {
    expect(
      supportsCameraAppSettings(isWeb: false, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      supportsCameraAppSettings(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(cameraPermissionDeniedMessage(isWeb: false), contains('إعدادات'));
  });

  test('web camera denial explains browser permission recovery', () {
    expect(
      supportsCameraAppSettings(isWeb: true, platform: TargetPlatform.android),
      isFalse,
    );
    expect(cameraPermissionDeniedMessage(isWeb: true), contains('رمز القفل'));
  });

  test('unsupported desktop does not offer app camera settings', () {
    expect(
      supportsCameraAppSettings(isWeb: false, platform: TargetPlatform.windows),
      isFalse,
    );
  });
}
