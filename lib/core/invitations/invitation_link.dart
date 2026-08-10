import 'package:flutter_dotenv/flutter_dotenv.dart';

const _appInviteScheme = 'io.supabase.link://invite';

String? extractInvitationToken(Uri uri) {
  if (uri.scheme == 'io.supabase.link' && uri.host == 'invite') {
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first.trim();
    }
    return uri.queryParameters['t']?.trim();
  }

  // Only explicit web invitation paths belong to the invitation flow.
  // Password recovery links must remain available for Supabase Auth to
  // process instead of being mistaken for servant invitations.
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    final segments = uri.pathSegments
        .map((segment) => segment.trim().toLowerCase())
        .where((segment) => segment.isNotEmpty)
        .toList();
    final isInvitationPath =
        segments.isNotEmpty &&
        (segments.last == 'invite' || segments.contains('invite-redirect'));
    if (isInvitationPath) {
      return uri.queryParameters['t']?.trim();
    }
  }

  return null;
}

String buildInvitationLink({required String inviteToken, String? supabaseUrl}) {
  final webBase =
      dotenv.env['INVITE_LINK_BASE_URL']?.trim() ??
      'https://link-church-app.vercel.app';
  final normalized = webBase.endsWith('/')
      ? webBase.substring(0, webBase.length - 1)
      : webBase;
  return '$normalized/invite?t=${Uri.encodeComponent(inviteToken)}';
}

String buildInvitationAppDeepLink(String inviteToken) {
  return '$_appInviteScheme?t=${Uri.encodeComponent(inviteToken)}';
}
