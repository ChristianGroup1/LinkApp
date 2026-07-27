import 'package:flutter_dotenv/flutter_dotenv.dart';

const _appInviteScheme = 'io.supabase.link://invite';

String? extractInvitationToken(Uri uri) {
  if (uri.scheme == 'io.supabase.link' && uri.host == 'invite') {
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first.trim();
    }
    return uri.queryParameters['t']?.trim();
  }

  if (uri.pathSegments.length >= 2 &&
      uri.pathSegments[uri.pathSegments.length - 2] == 'invite-redirect') {
    return uri.queryParameters['t']?.trim();
  }

  if (uri.pathSegments.isNotEmpty &&
      uri.pathSegments.last == 'invite-redirect') {
    return uri.queryParameters['t']?.trim();
  }

  return uri.queryParameters['t']?.trim();
}

String buildInvitationLink({
  required String inviteToken,
  String? supabaseUrl,
}) {
  final webBase = dotenv.env['INVITE_LINK_BASE_URL']?.trim();
  if (webBase != null && webBase.isNotEmpty) {
    final normalized = webBase.endsWith('/')
        ? webBase.substring(0, webBase.length - 1)
        : webBase;
    return '$normalized/invite/$inviteToken';
  }

  final projectUrl = supabaseUrl?.trim();
  if (projectUrl != null && projectUrl.isNotEmpty) {
    final normalized = projectUrl.endsWith('/')
        ? projectUrl.substring(0, projectUrl.length - 1)
        : projectUrl;
    return '$normalized/functions/v1/invite-redirect?t=$inviteToken';
  }

  return '$_appInviteScheme?t=${Uri.encodeComponent(inviteToken)}';
}

String buildInvitationAppDeepLink(String inviteToken) {
  return '$_appInviteScheme?t=${Uri.encodeComponent(inviteToken)}';
}
