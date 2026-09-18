import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/arabic_error_text.dart';

String accountDeletionErrorMessage(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    final message = _extractErrorText(details);
    // Only keep server text when it is already Arabic; otherwise translate.
    if (message.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(message)) {
      return message;
    }
    if (error.status == 401) {
      return 'انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى ثم حاول حذف الحساب.';
    }
    return arabicErrorText(
      error,
      fallback: 'تعذر حذف الحساب الآن (خطأ ${error.status}).',
    );
  }

  final message = arabicErrorText(
    error,
    fallback: 'تعذر حذف الحساب الآن.',
  ).trim();
  return message.isEmpty ? 'تعذر حذف الحساب الآن.' : message;
}

String _extractErrorText(Object? details) {
  if (details is Map) {
    final error = details['error'];
    if (error is String) return error.trim();
  }
  if (details is String) return details.trim();
  return '';
}
