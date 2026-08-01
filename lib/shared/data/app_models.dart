enum AppRole {
  superAdmin('super_admin'),
  churchAdmin('church_admin'),
  classLeader('class_leader'),
  attendanceOfficer('attendance_officer');

  final String value;
  const AppRole(this.value);

  static AppRole fromJson(String value) {
    return AppRole.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppRole.attendanceOfficer,
    );
  }
}

enum MeetingKind {
  sundaySchool('sunday_school'),
  normal('normal');

  final String value;
  const MeetingKind(this.value);

  static MeetingKind fromJson(String value) {
    return MeetingKind.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MeetingKind.normal,
    );
  }
}

enum MemberScope {
  sundaySchoolClass('sunday_school_class'),
  meeting('meeting');

  final String value;
  const MemberScope(this.value);

  static MemberScope fromJson(String value) {
    return MemberScope.values.firstWhere(
      (item) => item.value == value,
      orElse: () => MemberScope.meeting,
    );
  }
}

enum AttendanceStatus {
  present('present'),
  absent('absent'),
  excused('excused');

  final String value;
  const AttendanceStatus(this.value);

  static AttendanceStatus fromJson(String value) {
    return AttendanceStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

class Church {
  final String id;
  final String name;
  final String nameAr;
  final String slug;
  final String? phone;
  final String? address;

  const Church({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.slug,
    this.phone,
    this.address,
  });

  factory Church.fromJson(Map<String, dynamic> json) {
    final fallbackName =
        (json['name_ar'] ?? json['name'] ?? 'منصة لينك للخدمة') as String;

    return Church(
      id: json['id'] as String,
      name: (json['name'] ?? fallbackName) as String,
      nameAr: (json['name_ar'] ?? fallbackName) as String,
      slug: (json['slug'] ?? json['id']) as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }
}

class AppProfile {
  final String id;
  final String? churchId;
  final String fullName;
  final AppRole role;
  final String? email;
  final String? phone;
  final bool isActive;

  const AppProfile({
    required this.id,
    required this.churchId,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.isActive = true,
  });

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      churchId: json['church_id'] as String?,
      fullName: json['full_name'] as String,
      role: AppRole.fromJson(json['role'] as String),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class MeetingEntity {
  final String id;
  final String churchId;
  final String name;
  final String nameAr;
  final MeetingKind kind;
  final int weekday;
  final bool isActive;
  final String? description;
  final int? attendanceReminderMinutes;

  const MeetingEntity({
    required this.id,
    required this.churchId,
    required this.name,
    required this.nameAr,
    required this.kind,
    required this.weekday,
    required this.isActive,
    this.description,
    this.attendanceReminderMinutes,
  });

  factory MeetingEntity.fromJson(Map<String, dynamic> json) {
    return MeetingEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      kind: MeetingKind.fromJson(json['kind'] as String),
      weekday: json['weekday'] as int? ?? 7,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
      attendanceReminderMinutes: json['attendance_reminder_minutes'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SundaySchoolClassEntity {
  final String id;
  final String churchId;
  final String meetingId;
  final String name;
  final String nameAr;
  final int displayOrder;
  final bool isActive;

  const SundaySchoolClassEntity({
    required this.id,
    required this.churchId,
    required this.meetingId,
    required this.name,
    required this.nameAr,
    required this.displayOrder,
    required this.isActive,
  });

  factory SundaySchoolClassEntity.fromJson(Map<String, dynamic> json) {
    return SundaySchoolClassEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      meetingId: json['meeting_id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SundaySchoolClassEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MemberEntity {
  final String id;
  final String churchId;
  final String fullName;
  final MemberScope scope;
  final String? sundaySchoolClassId;
  final String? meetingId;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final bool isActive;
  final DateTime? birthDate;

  const MemberEntity({
    required this.id,
    required this.churchId,
    required this.fullName,
    required this.scope,
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    required this.isActive,
    this.birthDate,
  });

  factory MemberEntity.fromJson(Map<String, dynamic> json) {
    return MemberEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      fullName: json['full_name'] as String,
      scope: MemberScope.fromJson(json['scope'] as String),
      sundaySchoolClassId: json['sunday_school_class_id'] as String?,
      meetingId: json['meeting_id'] as String?,
      phone: json['phone'] as String?,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      code: json['code'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
    );
  }
}

class AttendanceSessionEntity {
  final String id;
  final String churchId;
  final String meetingId;
  final String? classId;
  final DateTime sessionDate;
  final int weekNumber;
  final String? title;

  const AttendanceSessionEntity({
    required this.id,
    required this.churchId,
    required this.meetingId,
    required this.classId,
    required this.sessionDate,
    required this.weekNumber,
    this.title,
  });

  factory AttendanceSessionEntity.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      meetingId: json['meeting_id'] as String,
      classId: json['class_id'] as String?,
      sessionDate: DateTime.parse(json['session_date'] as String),
      weekNumber: json['week_number'] as int,
      title: json['title'] as String?,
    );
  }
}

class AttendanceRecordEntity {
  final String id;
  final String sessionId;
  final String memberId;
  final AttendanceStatus status;
  final String? notes;

  const AttendanceRecordEntity({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.status,
    this.notes,
  });

  factory AttendanceRecordEntity.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordEntity(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      memberId: json['member_id'] as String,
      status: AttendanceStatus.fromJson(json['status'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class FollowUpEntity {
  final String id;
  final String churchId;
  final String memberId;
  final String? sessionId;
  final String? reason;
  final String contactStatus;
  final String? result;
  final String? responsibleUserId;
  final DateTime followUpDate;

  const FollowUpEntity({
    required this.id,
    required this.churchId,
    required this.memberId,
    this.sessionId,
    this.reason,
    required this.contactStatus,
    this.result,
    this.responsibleUserId,
    required this.followUpDate,
  });

  factory FollowUpEntity.fromJson(Map<String, dynamic> json) {
    return FollowUpEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      memberId: json['member_id'] as String,
      sessionId: json['session_id'] as String?,
      reason: json['reason'] as String?,
      contactStatus: json['contact_status'] as String,
      result: json['result'] as String?,
      responsibleUserId: json['responsible_user_id'] as String?,
      followUpDate: DateTime.parse(json['follow_up_date'] as String),
    );
  }
}

class HelperInvitation {
  final String id;
  final String churchId;
  final String fullName;
  final String? email;
  final String? phone;
  final AppRole role;
  final String? targetId;
  final String? assignmentScope;
  final bool canTakeAttendance;
  final bool canViewReports;
  final String code;
  final String inviteToken;
  final bool isUsed;
  final DateTime? declinedAt;
  final DateTime createdAt;

  const HelperInvitation({
    required this.id,
    required this.churchId,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.targetId,
    this.assignmentScope,
    this.canTakeAttendance = true,
    this.canViewReports = true,
    required this.code,
    required this.inviteToken,
    required this.isUsed,
    this.declinedAt,
    required this.createdAt,
  });

  bool get isPending => !isUsed && declinedAt == null;

  factory HelperInvitation.fromJson(Map<String, dynamic> json) {
    return HelperInvitation(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: AppRole.fromJson(json['role'] as String),
      targetId: json['target_id'] as String?,
      assignmentScope: json['assignment_scope'] as String?,
      canTakeAttendance: json['can_take_attendance'] as bool? ?? true,
      canViewReports: json['can_view_reports'] as bool? ?? true,
      code: json['code'] as String,
      inviteToken: json['invite_token'] as String? ?? '',
      isUsed: json['is_used'] as bool? ?? false,
      declinedAt: json['declined_at'] == null
          ? null
          : DateTime.parse(json['declined_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
