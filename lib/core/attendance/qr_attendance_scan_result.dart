class QrAttendanceScanResult {
  final Set<String> scannedMemberIds;
  final bool markUnscannedAbsent;

  QrAttendanceScanResult({
    required Set<String> scannedMemberIds,
    required this.markUnscannedAbsent,
  }) : scannedMemberIds = Set.unmodifiable(scannedMemberIds);
}
