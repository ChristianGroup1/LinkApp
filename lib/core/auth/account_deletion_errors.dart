import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/arabic_error_text.dart';

String accountDeletionErrorMessage(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    final message = _extractErrorText(details);
    if (message.isNotEmpty) return message;
    if (error.status == 401) {
      return 'انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى ثم حاول حذف الحساب.';
    }
    return 'تعذر حذف الحساب الآن (خطأ ${error.status}).';
  }

  final message = arabicErrorText(error).trim();
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
