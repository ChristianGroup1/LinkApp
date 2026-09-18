import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a write to church data was rejected, in terms a servant can act on.
enum StorageWriteFailure {
  /// Row-level security refused the write: the target is not part of the
  /// signed-in account's church, or the account has no permission over it.
  notAllowed,

  /// Another record inside the same church already uses the unique value.
  conflict,

  /// A required value was missing, or a check constraint failed.
  invalid,

  /// The device could not reach the server.
  offline,

  /// Anything else, reported with a short trimmed detail.
  unknown,
}

/// Explains a Supabase/Postgres write failure in Arabic, without dumping raw
/// exception text, SQL, or policy names into the interface.
///
/// Tenant isolation is enforced by row-level security. When a policy refuses a
/// row, the server answers with SQLSTATE 42501, which carries no explanation a
/// servant can read; this class turns that code into a message saying the
/// target is not this church's data, or that the account lacks permission.
class StorageWriteError {
  static const notAllowedCode = '42501';
  static const uniqueViolationCode = '23505';
  static const missingValueCode = '23502';
  static const checkViolationCode = '23514';
  static const foreignKeyViolationCode = '23503';

  static const _maxDetailLength = 140;

  static const _offlineNeedles = [
    'socketexception',
    'clientexception',
    'timeout',
    'timed out',
    'failed host lookup',
    'network',
    'connection',
  ];

  static const _refusalNeedles = [
    'row-level security',
    'permission denied',
    'forbidden',
  ];

  /// Wrapper prefixes that carry no meaning for a servant. Some failures arrive
  /// nested (`Exception: PostgrestException(message: …)`), so stripping repeats
  /// until none match.
  static const _exceptionPrefixes = [
    'PostgrestException(message: ',
    'PostgrestException(',
    'Exception: ',
    'Bad state: ',
  ];

  static final _codePattern = RegExp(r'code:\s*"?([0-9A-Z]{5})"?');
  static final _whitespacePattern = RegExp(r'\s+');

  final StorageWriteFailure failure;

  /// Postgres SQLSTATE returned by the server, when there was one.
  final String? code;

  /// Short server detail, kept only for [StorageWriteFailure.unknown].
  final String? detail;

  const StorageWriteError({required this.failure, this.code, this.detail});

  factory StorageWriteError.from(Object error) {
    final postgrest = error is PostgrestException ? error : null;
    final code = postgrest?.code ?? _codeFromText(error);
    final failure = _classify(code: code, error: error);
    return StorageWriteError(
      failure: failure,
      code: code,
      detail: failure == StorageWriteFailure.unknown
          ? _trimDetail(postgrest?.message ?? error.toString())
          : null,
    );
  }

  /// True when the write was refused because the row is not this account's
  /// church data, or the account has no permission over it.
  bool get isNotAllowed => failure == StorageWriteFailure.notAllowed;

  /// A full, actionable sentence naming the action that failed.
  String message({required String action}) => switch (failure) {
    StorageWriteFailure.notAllowed =>
      'تعذر $action: التبعية المختارة ليست من بيانات كنيسة حسابك، '
          'أو أن حسابك لا يملك صلاحية التعديل عليها. '
          'راجع الاجتماع أو الفصل، أو اطلب من مسؤول الكنيسة منحك الصلاحية.',
    StorageWriteFailure.conflict =>
      'تعذر $action: يوجد سجل آخر بنفس الكود التعريفي داخل نفس الكنيسة.',
    StorageWriteFailure.invalid =>
      'تعذر $action: بعض البيانات المطلوبة ناقصة أو غير صحيحة.',
    StorageWriteFailure.offline =>
      'تعذر $action: لا يمكن الوصول إلى الخادم. تحقق من الاتصال وأعد المحاولة.',
    StorageWriteFailure.unknown =>
      detail == null ? 'تعذر $action، حاول مرة أخرى.' : 'تعذر $action: $detail',
  };

  /// The bare reason, for callers that already wrote their own sentence.
  String get summary => switch (failure) {
    StorageWriteFailure.notAllowed =>
      'التبعية ليست من بيانات كنيسة حسابك أو لا تملك صلاحيتها',
    StorageWriteFailure.conflict => 'الكود التعريفي مستخدم داخل نفس الكنيسة',
    StorageWriteFailure.invalid => 'بيانات ناقصة أو غير صحيحة',
    StorageWriteFailure.offline => 'تعذر الوصول إلى الخادم',
    StorageWriteFailure.unknown => detail ?? 'خطأ غير متوقع',
  };

  static StorageWriteFailure _classify({
    required String? code,
    required Object error,
  }) {
    switch (code) {
      case notAllowedCode:
        return StorageWriteFailure.notAllowed;
      case uniqueViolationCode:
        return StorageWriteFailure.conflict;
      case missingValueCode:
      case checkViolationCode:
      case foreignKeyViolationCode:
        return StorageWriteFailure.invalid;
    }

    final text = error.toString().toLowerCase();
    for (final needle in _refusalNeedles) {
      if (text.contains(needle)) return StorageWriteFailure.notAllowed;
    }
    for (final needle in _offlineNeedles) {
      if (text.contains(needle)) return StorageWriteFailure.offline;
    }
    return StorageWriteFailure.unknown;
  }

  static String? _codeFromText(Object error) =>
      _codePattern.firstMatch(error.toString())?.group(1);

  static String? _trimDetail(String raw) {
    var detail = raw.replaceAll(_whitespacePattern, ' ').trim();
    var stripped = true;
    while (stripped) {
      stripped = false;
      for (final prefix in _exceptionPrefixes) {
        if (detail.startsWith(prefix)) {
          detail = detail.substring(prefix.length).trim();
          stripped = true;
        }
      }
    }
    final technicalTail = detail.indexOf(', code:');
    if (technicalTail > 0) {
      detail = detail.substring(0, technicalTail);
    }
    detail = detail.trim();
    if (detail.isEmpty) return null;
    return detail.length <= _maxDetailLength
        ? detail
        : '${detail.substring(0, _maxDetailLength)}…';
  }
}
