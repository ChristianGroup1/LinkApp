import 'package:flutter/foundation.dart';

String get passwordResetRedirectUrl => kIsWeb
    ? 'https://linkchurch.space/reset-password'
    : 'io.supabase.link://reset-password';

class PasswordRecoveryLinkError {
  final String code;
  final String description;

  const PasswordRecoveryLinkError({
    required this.code,
    required this.description,
  });

  bool get isExpiredOrUsed {
    final normalized = '$code $description'.toLowerCase();
    return normalized.contains('otp_expired') ||
        normalized.contains('expired') ||
        normalized.contains('already been used') ||
        normalized.contains('invalid');
  }
}

PasswordRecoveryLinkError? extractPasswordRecoveryLinkError(Uri uri) {
  final isNativeRecoveryLink =
      uri.scheme == 'io.supabase.link' && uri.host == 'reset-password';
  final pathSegments = uri.pathSegments
      .map((segment) => segment.trim().toLowerCase())
      .where((segment) => segment.isNotEmpty);
  final isWebRecoveryLink =
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      (pathSegments.contains('reset-password') ||
          uri.queryParameters['password_recovery'] == '1');
  final isRecoveryLink = isNativeRecoveryLink || isWebRecoveryLink;
  if (!isRecoveryLink) return null;

  final parameters = <String, String>{...uri.queryParameters};
  if (uri.fragment.isNotEmpty) {
    parameters.addAll(Uri.splitQueryString(uri.fragment));
  }

  final error = parameters['error']?.trim() ?? '';
  final code = parameters['error_code']?.trim() ?? error;
  final description = parameters['error_description']?.trim() ?? '';
  if (error.isEmpty && code.isEmpty && description.isEmpty) return null;

  return PasswordRecoveryLinkError(code: code, description: description);
}
