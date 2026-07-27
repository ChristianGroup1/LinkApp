import 'package:flutter_test/flutter_test.dart';
import 'package:link/features/meetings/presentation/widgets/meeting_assignment_helpers.dart';
import 'package:link/shared/data/app_models.dart';

HelperInvitation _invite({
  required String id,
  String? assignmentScope,
  String? targetId,
}) {
  return HelperInvitation(
    id: id,
    churchId: 'church-1',
    fullName: 'خادم $id',
    role: AppRole.classLeader,
    targetId: targetId,
    assignmentScope: assignmentScope,
    code: 'CODE$id',
    inviteToken: 'token-$id',
    isUsed: false,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('pendingInvitesForMeeting', () {
    test('returns direct meeting invites only', () {
      final invites = [
        _invite(
          id: '1',
          assignmentScope: 'meeting',
          targetId: 'meeting-a',
        ),
        _invite(
          id: '2',
          assignmentScope: 'meeting_classes',
          targetId: 'meeting-a',
        ),
      ];

      final result = pendingInvitesForMeeting(invites, 'meeting-a');

      expect(result, hasLength(1));
      expect(result.first.id, '1');
    });
  });

  group('pendingInvitesForSundaySchoolMeeting', () {
    test('aggregates meeting_classes and class scoped invites', () {
      final invites = [
        _invite(
          id: '1',
          assignmentScope: 'meeting_classes',
          targetId: 'meeting-a',
        ),
        _invite(
          id: '2',
          assignmentScope: 'class',
          targetId: 'class-1',
        ),
        _invite(
          id: '3',
          assignmentScope: 'class',
          targetId: 'class-other',
        ),
      ];
      final classes = [
        SundaySchoolClassEntity(
          id: 'class-1',
          churchId: 'church-1',
          meetingId: 'meeting-a',
          name: 'Class 1',
          nameAr: 'الفصل الأول',
          displayOrder: 0,
          isActive: true,
        ),
      ];

      final result = pendingInvitesForSundaySchoolMeeting(
        invites,
        'meeting-a',
        classes,
      );

      expect(result, hasLength(2));
      expect(result.map((item) => item.invite.id), ['1', '2']);
      expect(result.last.className, 'الفصل الأول');
    });
  });
}
