import '../../data/models/models.dart';

class QrAttendancePreview {
  final int totalMembers;
  final int scannedPresent;
  final int preservedExcused;
  final int willBeAbsent;

  const QrAttendancePreview({
    required this.totalMembers,
    required this.scannedPresent,
    required this.preservedExcused,
    required this.willBeAbsent,
  });

  factory QrAttendancePreview.calculate({
    required Iterable<MemberEntity> members,
    required Map<String, AttendanceStatus> initialStatuses,
    required Set<String> scannedIds,
    required bool markUnscannedAbsent,
  }) {
    final memberIds = members.map((member) => member.id).toSet();
    final validScannedIds = scannedIds.intersection(memberIds);
    final preservedExcused = memberIds.where(
      (id) =>
          !validScannedIds.contains(id) &&
          initialStatuses[id] == AttendanceStatus.excused,
    );
    final willBeAbsent = markUnscannedAbsent
        ? memberIds.length - validScannedIds.length - preservedExcused.length
        : 0;

    return QrAttendancePreview(
      totalMembers: memberIds.length,
      scannedPresent: validScannedIds.length,
      preservedExcused: preservedExcused.length,
      willBeAbsent: willBeAbsent,
    );
  }
}
