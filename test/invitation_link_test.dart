import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/invitations/invitation_link.dart';

void main() {
  group('extractInvitationToken', () {
    test('reads native and web invitation links', () {
      expect(
        extractInvitationToken(
          Uri.parse('io.supabase.link://invite?t=servant-token'),
        ),
        'servant-token',
      );
      expect(
        extractInvitationToken(
          Uri.parse(
            'https://link-church-app.vercel.app/invite?t=servant-token',
          ),
        ),
        'servant-token',
      );
    });

    test('does not treat reset-password as a servant invitation', () {
      expect(
        extractInvitationToken(
          Uri.parse(
            'io.supabase.link://reset-password?t=auth-token&type=recovery',
          ),
        ),
        isNull,
      );
    });

    test('does not treat login callbacks as servant invitations', () {
      expect(
        extractInvitationToken(
          Uri.parse(
            'io.supabase.link://login-callback?t=auth-token&type=recovery',
          ),
        ),
        isNull,
      );
    });
  });
}
