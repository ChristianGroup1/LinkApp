import 'package:flutter/foundation.dart';

enum QrAttendanceInputMode { camera, desktopReader, unsupported }

QrAttendanceInputMode resolveQrAttendanceInputMode({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (isWeb ?? kIsWeb) return QrAttendanceInputMode.camera;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => QrAttendanceInputMode.camera,
    TargetPlatform.windows ||
    TargetPlatform.linux => QrAttendanceInputMode.desktopReader,
    TargetPlatform.fuchsia => QrAttendanceInputMode.unsupported,
  };
}
