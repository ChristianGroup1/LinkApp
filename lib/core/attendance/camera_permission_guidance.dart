import 'package:flutter/foundation.dart';

bool supportsCameraAppSettings({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return false;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

String cameraPermissionDeniedMessage({bool? isWeb}) {
  if (isWeb ?? kIsWeb) {
    return 'تم رفض استخدام الكاميرا. اسمح للكاميرا من رمز القفل بجوار عنوان الموقع، ثم أعد المحاولة.';
  }
  return 'تم رفض صلاحية الكاميرا. يمكنك طلب الإذن مرة أخرى، أو فتح إعدادات LinkApp وتفعيل الكاميرا إذا كان الرفض دائمًا.';
}
