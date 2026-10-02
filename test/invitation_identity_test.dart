import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/invitations/invitation_identity.dart';

void main() {
  group('invitation email identity', () {
    test('treats an omitted email as an invitation without email', () {
      expect(isNoEmailInvitationAddress(null), isTrue);
      expect(isNoEmailInvitationAddress('  '), isTrue);
      expect(isNoEmailInvitationAddress('no-email@linkapp.local'), isTrue);
      expect(isNoEmailInvitationAddress('helper@example.com'), isFalse);
    });

    test('matches the invited account ignoring case and outer spaces', () {
      expect(
        invitationEmailMatchesAccount(
          invitationEmail: ' User@Example.com ',
          accountEmail: 'user@example.com',
        ),
        isTrue,
      );
    });

    test('blocks a different signed-in account', () {
      expect(
        invitationEmailMatchesAccount(
          invitationEmail: 'y@example.com',
          accountEmail: 'x@example.com',
        ),
        isFalse,
      );
    });

    test('does not accept a missing invitation email', () {
      expect(
        invitationEmailMatchesAccount(
          invitationEmail: null,
          accountEmail: 'x@example.com',
        ),
        isFalse,
      );
    });
  });
}
