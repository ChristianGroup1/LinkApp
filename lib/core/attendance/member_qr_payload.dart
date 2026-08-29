class MemberQrPayload {
  static const scheme = 'linkapp';
  static const host = 'attendance';
  static const version = '1';

  final String memberId;
  final String churchId;

  const MemberQrPayload({required this.memberId, required this.churchId});

  String encode() {
    return Uri(
      scheme: scheme,
      host: host,
      pathSegments: ['member', memberId],
      queryParameters: {'church': churchId, 'v': version},
    ).toString();
  }

  static MemberQrPayload? tryParse(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != scheme ||
        uri.host != host ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'member' ||
        uri.queryParameters['v'] != version) {
      return null;
    }

    final memberId = uri.pathSegments[1].trim();
    final churchId = uri.queryParameters['church']?.trim() ?? '';
    if (memberId.isEmpty || churchId.isEmpty) return null;

    return MemberQrPayload(memberId: memberId, churchId: churchId);
  }
}
