import '../../data/models/models.dart';
import 'member_qr_payload.dart';

enum MemberQrScanStatus { accepted, duplicate, invalidPayload, notInSheet }

class MemberQrScanAttempt {
  final MemberQrScanStatus status;
  final MemberEntity? member;

  const MemberQrScanAttempt(this.status, {this.member});
}

class MemberQrScanSession {
  final Map<String, MemberEntity> _membersById;
  final Set<String> _scannedIds = {};
  final List<String> _scannedOrder = [];

  MemberQrScanSession(Iterable<MemberEntity> members)
    : _membersById = {for (final member in members) member.id: member};

  Set<String> get scannedIds => Set.unmodifiable(_scannedIds);
  List<String> get scannedOrder => List.unmodifiable(_scannedOrder);
  MemberEntity? memberById(String id) => _membersById[id];

  MemberQrScanAttempt scan(String rawValue) {
    final payload = MemberQrPayload.tryParse(rawValue);
    if (payload == null) {
      return const MemberQrScanAttempt(MemberQrScanStatus.invalidPayload);
    }

    final member = _membersById[payload.memberId];
    if (member == null || member.churchId != payload.churchId) {
      return const MemberQrScanAttempt(MemberQrScanStatus.notInSheet);
    }
    if (_scannedIds.contains(member.id)) {
      return MemberQrScanAttempt(MemberQrScanStatus.duplicate, member: member);
    }

    _scannedIds.add(member.id);
    _scannedOrder
      ..remove(member.id)
      ..add(member.id);
    return MemberQrScanAttempt(MemberQrScanStatus.accepted, member: member);
  }

  void remove(String memberId) {
    _scannedIds.remove(memberId);
    _scannedOrder.remove(memberId);
  }

  void clear() {
    _scannedIds.clear();
    _scannedOrder.clear();
  }
}
