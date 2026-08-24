String normalizeInvitationEmail(String? email) =>
    (email ?? '').trim().toLowerCase();

bool invitationEmailMatchesAccount({
  required String? invitationEmail,
  required String? accountEmail,
}) {
  final expected = normalizeInvitationEmail(invitationEmail);
  final actual = normalizeInvitationEmail(accountEmail);
  return expected.isNotEmpty && actual.isNotEmpty && expected == actual;
}

String invitationAccountMismatchMessage(String? invitationEmail) {
  final expected = (invitationEmail ?? '').trim();
  if (expected.isEmpty) {
    return 'لا يمكن تنفيذ الدعوة بالحساب المفتوح حالياً.';
  }
  return 'هذه الدعوة موجهة إلى $expected. سيتم تسجيل الخروج من الحساب الحالي للمتابعة بالحساب المدعو.';
}
