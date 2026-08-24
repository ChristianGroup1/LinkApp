import 'package:supabase_flutter/supabase_flutter.dart';

String invitationEmailErrorMessage(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    final message = _extractErrorText(details).toLowerCase();

    if (message.contains('invitation not found') ||
        message.contains('invite_token')) {
      return 'تعذر قراءة الدعوة من السيرفر. شغّل supabase_invitation_link_migration.sql ثم أعد المحاولة.';
    }
    if (message.contains('invitation has no email')) {
      return 'الدعوة لا تحتوي على بريد إلكتروني.';
    }
    if (message.contains('failed to send invitation via supabase smtp') ||
        message.contains('smtp')) {
      return 'فشل إرسال الدعوة عبر Gmail SMTP في Supabase. راجع إعدادات SMTP وحد الإرسال، ثم افحص مجلد Spam.';
    }
    if (error.status == 401 || error.status == 403) {
      return 'غير مصرح بإرسال البريد. سجّل دخولك كمدير كنيسة وحاول مرة أخرى.';
    }

    final readable = _extractErrorText(details);
    if (readable.isNotEmpty) {
      return 'فشل إرسال البريد: $readable';
    }
    return 'فشل إرسال البريد (خطأ ${error.status}).';
  }

  return error.toString().replaceAll('Exception: ', '');
}

String _extractErrorText(Object? details) {
  if (details is Map) {
    final error = details['error'];
    final extra = details['details'];
    if (error is String && extra is String) {
      return '$error — $extra';
    }
    if (error is String) return error;
    if (extra is String) return extra;
  }
  if (details is String) return details;
  return details?.toString() ?? '';
}
