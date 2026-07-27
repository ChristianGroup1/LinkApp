import '../../../../data/models/models.dart';

class PendingMeetingInviteDisplay {
  final HelperInvitation invite;
  final String? className;

  const PendingMeetingInviteDisplay({
    required this.invite,
    this.className,
  });
}

List<HelperInvitation> pendingInvitesForMeeting(
  List<HelperInvitation> invitations,
  String meetingId,
) {
  return invitations
      .where(
        (invite) =>
            invite.isPending &&
            invite.assignmentScope == 'meeting' &&
            invite.targetId == meetingId,
      )
      .toList();
}

List<HelperInvitation> pendingInvitesForMeetingClasses(
  List<HelperInvitation> invitations,
  String meetingId,
) {
  return invitations
      .where(
        (invite) =>
            invite.isPending &&
            invite.assignmentScope == 'meeting_classes' &&
            invite.targetId == meetingId,
      )
      .toList();
}

List<HelperInvitation> pendingInvitesForClass(
  List<HelperInvitation> invitations,
  String classId,
) {
  return invitations
      .where(
        (invite) =>
            invite.isPending &&
            invite.assignmentScope == 'class' &&
            invite.targetId == classId,
      )
      .toList();
}

/// All pending invites tied to a Sunday-school meeting:
/// whole-meeting scope plus any class-level invites under its classes.
List<PendingMeetingInviteDisplay> pendingInvitesForSundaySchoolMeeting(
  List<HelperInvitation> invitations,
  String meetingId,
  List<SundaySchoolClassEntity> classes,
) {
  final classIds = classes.map((cls) => cls.id).toSet();
  final classNameById = {
    for (final cls in classes) cls.id: cls.nameAr.trim().isNotEmpty
        ? cls.nameAr
        : cls.name,
  };
  final result = <PendingMeetingInviteDisplay>[];
  final seen = <String>{};

  for (final invite in invitations) {
    if (invite.isUsed || !invite.isPending || !seen.add(invite.id)) continue;

    if (invite.assignmentScope == 'meeting_classes' &&
        invite.targetId == meetingId) {
      result.add(PendingMeetingInviteDisplay(invite: invite));
      continue;
    }

    final targetId = invite.targetId;
    if (invite.assignmentScope == 'class' &&
        targetId != null &&
        classIds.contains(targetId)) {
      result.add(
        PendingMeetingInviteDisplay(
          invite: invite,
          className: classNameById[targetId],
        ),
      );
    }
  }

  return result;
}

List<Map<String, dynamic>> aggregateClassAssignmentsForMeeting(
  List<SundaySchoolClassEntity> classes,
  Map<String, List<Map<String, dynamic>>> classAssignmentsById,
) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final cls in classes) {
    for (final assign in classAssignmentsById[cls.id] ?? const []) {
      final userId = assign['user_id'] as String?;
      if (userId == null || !seen.add(userId)) continue;
      result.add(assign);
    }
  }
  return result;
}
