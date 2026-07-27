/// Matches Postgres enum `follow_up_contact_status`.
class FollowUpContactStatus {
  FollowUpContactStatus._();

  static const pending = 'pending';
  static const contacted = 'contacted';
  static const noResponse = 'no_response';
  static const resolved = 'resolved';

  static const all = [pending, contacted, noResponse, resolved];

  static String labelAr(String status) {
    switch (status) {
      case contacted:
        return 'تم التواصل بنجاح';
      case noResponse:
        return 'لم يرد على الهاتف';
      case resolved:
        return 'تم الحل';
      case pending:
      default:
        return 'لم يتم الاتصال بعد';
    }
  }
}
