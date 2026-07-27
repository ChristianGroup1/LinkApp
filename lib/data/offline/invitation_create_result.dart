class InvitationCreateResult {
  final String code;
  final String invitationId;
  final String inviteToken;
  final String inviteLink;

  const InvitationCreateResult({
    required this.code,
    required this.invitationId,
    required this.inviteToken,
    required this.inviteLink,
  });
}
