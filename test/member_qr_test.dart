import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/attendance/member_qr_payload.dart';
import 'package:link/core/attendance/member_qr_scan_session.dart';
import 'package:link/core/attendance/qr_attendance_platform.dart';
import 'package:link/core/attendance/qr_attendance_preview.dart';
import 'package:link/data/models/models.dart';
import 'package:link/features/members/data/member_qr_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('member QR round-trips church and member identity', () {
    const payload = MemberQrPayload(
      memberId: 'member-123',
      churchId: 'church-456',
    );

    final parsed = MemberQrPayload.tryParse(payload.encode());

    expect(parsed, isNotNull);
    expect(parsed!.memberId, 'member-123');
    expect(parsed.churchId, 'church-456');
  });

  test('rejects arbitrary and unsupported QR values', () {
    expect(MemberQrPayload.tryParse('https://example.com/member-123'), isNull);
    expect(
      MemberQrPayload.tryParse(
        'linkapp://attendance/member/member-123?church=church-456&v=2',
      ),
      isNull,
    );
    expect(MemberQrPayload.tryParse(''), isNull);
  });

  test('desktop and mobile use the correct QR input mode', () {
    expect(
      resolveQrAttendanceInputMode(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      QrAttendanceInputMode.desktopReader,
    );
    expect(
      resolveQrAttendanceInputMode(
        isWeb: false,
        platform: TargetPlatform.linux,
      ),
      QrAttendanceInputMode.desktopReader,
    );
    expect(
      resolveQrAttendanceInputMode(
        isWeb: false,
        platform: TargetPlatform.macOS,
      ),
      QrAttendanceInputMode.camera,
    );
    expect(
      resolveQrAttendanceInputMode(
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      QrAttendanceInputMode.camera,
    );
  });

  test('QR scan session rejects duplicates and members from another sheet', () {
    const member = MemberEntity(
      id: 'member-1',
      churchId: 'church-1',
      fullName: 'مينا سمير',
      scope: MemberScope.meeting,
      meetingId: 'meeting-1',
      isActive: true,
    );
    final session = MemberQrScanSession(const [member]);
    const validPayload = MemberQrPayload(
      memberId: 'member-1',
      churchId: 'church-1',
    );

    expect(
      session.scan(validPayload.encode()).status,
      MemberQrScanStatus.accepted,
    );
    expect(
      session.scan(validPayload.encode()).status,
      MemberQrScanStatus.duplicate,
    );
    expect(
      session.scan('not-a-linkapp-code').status,
      MemberQrScanStatus.invalidPayload,
    );
    expect(
      session
          .scan(
            const MemberQrPayload(
              memberId: 'member-2',
              churchId: 'church-1',
            ).encode(),
          )
          .status,
      MemberQrScanStatus.notInSheet,
    );
    expect(session.scannedIds, {'member-1'});
  });

  test('QR preview counts present and absent while preserving excused', () {
    const members = [
      MemberEntity(
        id: 'member-1',
        churchId: 'church-1',
        fullName: 'عضو 1',
        scope: MemberScope.meeting,
        meetingId: 'meeting-1',
        isActive: true,
      ),
      MemberEntity(
        id: 'member-2',
        churchId: 'church-1',
        fullName: 'عضو 2',
        scope: MemberScope.meeting,
        meetingId: 'meeting-1',
        isActive: true,
      ),
      MemberEntity(
        id: 'member-3',
        churchId: 'church-1',
        fullName: 'عضو 3',
        scope: MemberScope.meeting,
        meetingId: 'meeting-1',
        isActive: true,
      ),
    ];

    final preview = QrAttendancePreview.calculate(
      members: members,
      initialStatuses: const {'member-3': AttendanceStatus.excused},
      scannedIds: const {'member-1', 'not-in-this-sheet'},
      markUnscannedAbsent: true,
    );

    expect(preview.totalMembers, 3);
    expect(preview.scannedPresent, 1);
    expect(preview.willBeAbsent, 1);
    expect(preview.preservedExcused, 1);
  });

  test('QR preview does not mark unscanned members absent when disabled', () {
    final preview = QrAttendancePreview.calculate(
      members: const [
        MemberEntity(
          id: 'member-1',
          churchId: 'church-1',
          fullName: 'عضو 1',
          scope: MemberScope.meeting,
          meetingId: 'meeting-1',
          isActive: true,
        ),
        MemberEntity(
          id: 'member-2',
          churchId: 'church-1',
          fullName: 'عضو 2',
          scope: MemberScope.meeting,
          meetingId: 'meeting-1',
          isActive: true,
        ),
      ],
      initialStatuses: const {},
      scannedIds: const {'member-1'},
      markUnscannedAbsent: false,
    );

    expect(preview.scannedPresent, 1);
    expect(preview.willBeAbsent, 0);
  });

  test(
    'builds a printable Arabic PDF containing active member QR cards',
    () async {
      final bytes = await MemberQrPdfService().build(
        members: const [
          MemberEntity(
            id: 'member-1',
            churchId: 'church-1',
            fullName: 'مينا سمير',
            scope: MemberScope.meeting,
            meetingId: 'meeting-1',
            code: 'MEM-001',
            isActive: true,
          ),
          MemberEntity(
            id: 'member-2',
            churchId: 'church-1',
            fullName: 'عضو غير نشط',
            scope: MemberScope.meeting,
            meetingId: 'meeting-1',
            isActive: false,
          ),
        ],
      );

      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(5000));
    },
  );
}
