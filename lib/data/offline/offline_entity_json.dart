import '../../shared/data/app_models.dart';

bool isOfflineId(String id) => id.startsWith('offline_');

Map<String, dynamic> profileToJson(AppProfile profile) => {
  'id': profile.id,
  'church_id': profile.churchId,
  'full_name': profile.fullName,
  'role': profile.role.value,
  'email': profile.email,
  'phone': profile.phone,
  'is_active': profile.isActive,
};

Map<String, dynamic> churchToJson(Church church) => {
  'id': church.id,
  'name': church.name,
  'name_ar': church.nameAr,
  'slug': church.slug,
  'phone': church.phone,
  'address': church.address,
};

Map<String, dynamic> meetingToJson(MeetingEntity meeting) => {
  'id': meeting.id,
  'church_id': meeting.churchId,
  'name': meeting.name,
  'name_ar': meeting.nameAr,
  'kind': meeting.kind.value,
  'weekday': meeting.weekday,
  'is_active': meeting.isActive,
  'description': meeting.description,
  'attendance_reminder_minutes': meeting.attendanceReminderMinutes,
};

Map<String, dynamic> classToJson(SundaySchoolClassEntity cls) => {
  'id': cls.id,
  'church_id': cls.churchId,
  'meeting_id': cls.meetingId,
  'name': cls.name,
  'name_ar': cls.nameAr,
  'display_order': cls.displayOrder,
  'is_active': cls.isActive,
};

Map<String, dynamic> memberToJson(MemberEntity member) => {
  'id': member.id,
  'church_id': member.churchId,
  'full_name': member.fullName,
  'scope': member.scope.value,
  'sunday_school_class_id': member.sundaySchoolClassId,
  'meeting_id': member.meetingId,
  'phone': member.phone,
  'parent_name': member.parentName,
  'parent_phone': member.parentPhone,
  'code': member.code,
  'is_active': member.isActive,
  if (member.birthDate != null)
    'birth_date': member.birthDate!.toIso8601String().split('T').first,
};

Map<String, dynamic> sessionToJson(AttendanceSessionEntity session) => {
  'id': session.id,
  'church_id': session.churchId,
  'meeting_id': session.meetingId,
  'class_id': session.classId,
  'session_date': session.sessionDate.toIso8601String().split('T').first,
  'week_number': session.weekNumber,
  'title': session.title,
};

Map<String, dynamic> followUpToJson(FollowUpEntity followUp) => {
  'id': followUp.id,
  'church_id': followUp.churchId,
  'member_id': followUp.memberId,
  'session_id': followUp.sessionId,
  'reason': followUp.reason,
  'contact_status': followUp.contactStatus,
  'result': followUp.result,
  'responsible_user_id': followUp.responsibleUserId,
  'follow_up_date': followUp.followUpDate.toIso8601String().split('T').first,
};

Map<String, dynamic> invitationToJson(HelperInvitation invitation) => {
  'id': invitation.id,
  'church_id': invitation.churchId,
  'full_name': invitation.fullName,
  'email': invitation.email,
  'phone': invitation.phone,
  'role': invitation.role.value,
  'target_id': invitation.targetId,
  'assignment_scope': invitation.assignmentScope,
  'can_take_attendance': invitation.canTakeAttendance,
  'can_view_reports': invitation.canViewReports,
  'code': invitation.code,
  'invite_token': invitation.inviteToken,
  'is_used': invitation.isUsed,
  'declined_at': invitation.declinedAt?.toIso8601String(),
  'created_at': invitation.createdAt.toIso8601String(),
};
