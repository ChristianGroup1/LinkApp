import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const nativePasswordResetRedirectUrl = 'io.supabase.link://reset-password';

/// Redirect target for password-reset emails.
///
/// Native apps use the custom scheme. The PWA/web build uses an HTTPS URL so
/// the email link opens back in the browser/installed web app instead of the
/// store app scheme.
String get passwordResetRedirectUrl {
  if (kIsWeb) return webPasswordResetRedirectUrl();
  return nativePasswordResetRedirectUrl;
}

String webPasswordResetRedirectUrl() {
  String? configured;
  try {
    configured =
        dotenv.env['PWA_BASE_URL']?.trim() ??
        dotenv.env['INVITE_LINK_BASE_URL']?.trim();
  } catch (_) {
    configured = null;
  }
  if (configured != null && configured.isNotEmpty) {
    final normalized = configured.endsWith('/')
        ? configured.substring(0, configured.length - 1)
        : configured;
    return '$normalized/app/';
  }

  final base = Uri.base;
  if (base.scheme == 'http' || base.scheme == 'https') {
    if (base.path.startsWith('/app')) {
      return '${base.origin}/app/';
    }
    return '${base.origin}/';
  }

  return 'https://linkchurch.space/app/';
}

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
  if (!_looksLikePasswordRecoveryUri(uri)) return null;

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

bool _looksLikePasswordRecoveryUri(Uri uri) {
  if (uri.scheme == 'io.supabase.link' && uri.host == 'reset-password') {
    return true;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final segments = uri.pathSegments
      .map((segment) => segment.trim().toLowerCase())
      .where((segment) => segment.isNotEmpty)
      .toList();

  // Invitation and other auth bridges must not be treated as recovery links.
  if (segments.contains('invite') || segments.contains('invite-redirect')) {
    return false;
  }

  // PWA is served under /app/. Also accept site root for local/web builds.
  if (segments.isEmpty) return true;
  return segments.first == 'app';
}
