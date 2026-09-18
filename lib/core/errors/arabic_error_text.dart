import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns any thrown error into a sentence the user can read in Arabic.
///
/// The app talks to Supabase, whose failures arrive as English technical text
/// (`AuthException`, `PostgrestException`, `SocketException`…). Nothing of that
/// text is shown: known failures are mapped to a specific Arabic explanation,
/// and anything unrecognized falls back to a generic Arabic message. Errors the
/// app itself throws with an Arabic message pass through unchanged.
String arabicErrorText(
  Object error, {
  String fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.',
}) {
  final raw = _stripWrappers(error.toString());

  // Messages the app raised itself are already written for the user.
  if (_arabicLetters.hasMatch(raw)) return raw;

  final lower = raw.toLowerCase();

  if (error is AuthException) {
    final mapped = _authMessage(error.message.toLowerCase(), error.code);
    if (mapped != null) return mapped;
  }

  final postgrestCode = error is PostgrestException
      ? error.code
      : _codePattern.firstMatch(raw)?.group(1);
  final mappedDatabase = _databaseMessage(postgrestCode, lower);
  if (mappedDatabase != null) return mappedDatabase;

  if (_containsAny(lower, _clockNeedles)) {
    return 'تعذر إنشاء اتصال آمن لأن تاريخ أو وقت الجهاز غير صحيح. '
        'فعّل التاريخ والوقت التلقائيين ثم حاول مرة أخرى.';
  }

  if (_containsAny(lower, _networkNeedles)) {
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.';
  }

  final authFallback = _authMessage(lower, null);
  if (authFallback != null) return authFallback;

  return fallback;
}

final _arabicLetters = RegExp(r'[\u0600-\u06FF]');
final _codePattern = RegExp(r'code:\s*"?([0-9A-Z]{5})"?');

const _networkNeedles = [
  'socketexception',
  'clientexception',
  'failed host lookup',
  'host lookup',
  'network',
  'connection',
  'timed out',
  'timeout',
  'offline',
  'internet',
  'handshake',
];

const _clockNeedles = ['certificate is not yet valid', 'not yet valid'];

String _stripWrappers(String text) {
  var message = text.trim();
  const prefixes = [
    'Exception: ',
    'Bad state: ',
    'Invalid argument(s): ',
    'FormatException: ',
  ];
  var stripped = true;
  while (stripped) {
    stripped = false;
    for (final prefix in prefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
        stripped = true;
      }
    }
  }
  return message;
}

bool _containsAny(String text, List<String> needles) =>
    needles.any(text.contains);

/// Supabase Auth failures: sign-in, sign-up, recovery, and session refresh.
String? _authMessage(String lower, String? code) {
  bool has(String needle) => lower.contains(needle) || code == needle;

  if (has('invalid login credentials') || has('invalid_credentials')) {
    return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
  }
  if (has('email not confirmed') || has('email_not_confirmed')) {
    return 'البريد الإلكتروني لم يتم تأكيده بعد. افتح رسالة التأكيد في بريدك '
        'ثم حاول مرة أخرى.';
  }
  if (has('already registered') ||
      has('user_already_exists') ||
      has('email_exists')) {
    return 'هذا البريد الإلكتروني مسجل بالفعل. جرّب تسجيل الدخول بدلاً من '
        'إنشاء حساب جديد.';
  }
  if (has('password should be') ||
      has('weak_password') ||
      has('weak password')) {
    return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
  }
  if (has('rate limit') ||
      has('too many requests') ||
      has('over_email_send_rate_limit') ||
      has('over_request_rate_limit')) {
    return 'محاولات كثيرة خلال وقت قصير. انتظر قليلاً ثم أعد المحاولة.';
  }
  if (has('otp_expired') ||
      has('token has expired') ||
      has('link is invalid or has expired') ||
      has('invite link')) {
    return 'انتهت صلاحية الرابط أو الكود. اطلب رابطًا جديدًا وحاول مرة أخرى.';
  }
  if (has('refresh_token') ||
      has('session_not_found') ||
      has('jwt expired') ||
      has('session expired')) {
    return 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.';
  }
  if (has('user not found') || has('user_not_found')) {
    return 'لا يوجد حساب بهذا البريد الإلكتروني.';
  }
  if (has('invalid email') || has('validation_failed')) {
    return 'البريد الإلكتروني غير صالح. راجع كتابته ثم أعد المحاولة.';
  }
  return null;
}

/// PostgreSQL failures, identified by SQLSTATE when the request reached the
/// database, or by the policy wording when only the text is available.
String? _databaseMessage(String? code, String lower) {
  switch (code) {
    case '42501':
      return _notAllowed;
    case '23505':
      return 'توجد بيانات مسجلة بنفس القيمة بالفعل (كود أو اسم مكرر). '
          'غيّر القيمة ثم أعد المحاولة.';
    case '23503':
      return 'لا يمكن تنفيذ الإجراء لأن البيانات مرتبطة بسجلات أخرى.';
    case '23502':
    case '23514':
      return 'بعض البيانات المطلوبة ناقصة أو غير صحيحة. راجعها ثم أعد المحاولة.';
    case 'PGRST301':
      return 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى.';
  }
  if (code != null && (code.startsWith('22') || code.startsWith('23'))) {
    return 'بعض البيانات المطلوبة ناقصة أو غير صحيحة. راجعها ثم أعد المحاولة.';
  }
  if (lower.contains('row-level security') ||
      lower.contains('permission denied') ||
      lower.contains('forbidden') ||
      lower.contains('not authorized') ||
      lower.contains('unauthorized')) {
    return _notAllowed;
  }
  return null;
}

const _notAllowed =
    'ليست لديك صلاحية لتنفيذ هذا الإجراء. اطلب من مدير الكنيسة منحك الصلاحية '
    'المطلوبة.';
