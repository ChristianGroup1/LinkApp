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

class SupportTicketEntity {
  final String id;
  final String category;
  final String subject;
  final String description;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportTicketMessageEntity> messages;

  const SupportTicketEntity({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.adminNote,
    this.messages = const [],
  });

  factory SupportTicketEntity.fromJson(Map<String, dynamic> json) =>
      SupportTicketEntity(
        id: json['id'] as String,
        category: json['category'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String,
        status: json['status'] as String,
        adminNote: json['admin_note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        messages: (json['support_ticket_messages'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (message) => SupportTicketMessageEntity.fromJson(
                Map<String, dynamic>.from(message),
              ),
            )
            .toList(growable: false),
      );
}

class SupportTicketMessageEntity {
  final String id;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  const SupportTicketMessageEntity({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory SupportTicketMessageEntity.fromJson(Map<String, dynamic> json) =>
      SupportTicketMessageEntity(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        senderRole: json['sender_role'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
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
      other is MeetingEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

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
  final List<String> meetingIds;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final bool isActive;
  final DateTime? birthDate;
  final String? schoolYear;
  final String? notes;

  const MemberEntity({
    required this.id,
    required this.churchId,
    required this.fullName,
    required this.scope,
    this.sundaySchoolClassId,
    this.meetingId,
    this.meetingIds = const [],
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    required this.isActive,
    this.birthDate,
    this.schoolYear,
    this.notes,
  });

  factory MemberEntity.fromJson(Map<String, dynamic> json) {
    final scope = MemberScope.fromJson(json['scope'] as String);
    final primaryMeetingId = json['meeting_id'] as String?;
    final linkedMeetings =
        (json['member_meeting_assignments'] as List? ?? const [])
            .whereType<Map>()
            .where((assignment) => assignment['sunday_school_class_id'] == null)
            .map((assignment) => assignment['meeting_id']?.toString())
            .whereType<String>()
            .toSet();
    final explicitMeetingIds = (json['meeting_ids'] as List? ?? const [])
        .map((id) => id.toString())
        .toSet();
    if (scope == MemberScope.meeting && primaryMeetingId != null) {
      linkedMeetings.add(primaryMeetingId);
    }
    linkedMeetings.addAll(explicitMeetingIds);
    return MemberEntity(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      fullName: json['full_name'] as String,
      scope: scope,
      sundaySchoolClassId: json['sunday_school_class_id'] as String?,
      meetingId: primaryMeetingId,
      meetingIds: linkedMeetings.toList(growable: false),
      phone: json['phone'] as String?,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      code: json['code'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      schoolYear: json['school_year'] as String? ?? json['notes'] as String?,
      notes: json['notes'] as String?,
    );
  }

  MemberEntity copyWith({
    List<String>? meetingIds,
    String? sundaySchoolClassId,
    String? meetingId,
    bool clearSundaySchoolClassId = false,
    bool clearMeetingId = false,
  }) => MemberEntity(
    id: id,
    churchId: churchId,
    fullName: fullName,
    scope: scope,
    sundaySchoolClassId: clearSundaySchoolClassId
        ? null
        : (sundaySchoolClassId ?? this.sundaySchoolClassId),
    meetingId: clearMeetingId ? null : (meetingId ?? this.meetingId),
    meetingIds: meetingIds ?? this.meetingIds,
    phone: phone,
    parentName: parentName,
    parentPhone: parentPhone,
    code: code,
    isActive: isActive,
    birthDate: birthDate,
    schoolYear: schoolYear,
    notes: notes,
  );
}

class AttendanceSessionEntity {
  final String id;
  final String churchId;
  final String meetingId;
  final String? classId;
  final DateTime sessionDate;
  final int weekNumber;
  final String? title;
  final bool isLocked;
  final DateTime? lockedAt;
  final String? lockedBy;

  const AttendanceSessionEntity({
    required this.id,
    required this.churchId,
    required this.meetingId,
    required this.classId,
    required this.sessionDate,
    required this.weekNumber,
    this.title,
    this.isLocked = false,
    this.lockedAt,
    this.lockedBy,
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
      isLocked: json['is_locked'] as bool? ?? false,
      lockedAt: json['locked_at'] == null
          ? null
          : DateTime.tryParse(json['locked_at'] as String),
      lockedBy: json['locked_by'] as String?,
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

class MemberAttendanceHistoryEntry {
  final String recordId;
  final String sessionId;
  final String meetingId;
  final String? classId;
  final DateTime sessionDate;
  final String? sessionTitle;
  final AttendanceStatus status;
  final String? notes;

  const MemberAttendanceHistoryEntry({
    required this.recordId,
    required this.sessionId,
    required this.meetingId,
    required this.classId,
    required this.sessionDate,
    required this.sessionTitle,
    required this.status,
    this.notes,
  });

  factory MemberAttendanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MemberAttendanceHistoryEntry(
      recordId: json['record_id'] as String,
      sessionId: json['session_id'] as String,
      meetingId: json['meeting_id'] as String,
      classId: json['class_id'] as String?,
      sessionDate: DateTime.parse(json['session_date'] as String),
      sessionTitle: json['session_title'] as String?,
      status: AttendanceStatus.fromJson(json['status'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'record_id': recordId,
    'session_id': sessionId,
    'meeting_id': meetingId,
    'class_id': classId,
    'session_date': sessionDate.toIso8601String(),
    'session_title': sessionTitle,
    'status': status.value,
    'notes': notes,
  };
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
  final String activityType;

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
    this.activityType = 'absence_follow_up',
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
      activityType: json['activity_type'] as String? ?? 'absence_follow_up',
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

  HelperInvitation copyWith({
    String? fullName,
    String? email,
    String? targetId,
  }) {
    return HelperInvitation(
      id: id,
      churchId: churchId,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone,
      role: role,
      targetId: targetId ?? this.targetId,
      assignmentScope: assignmentScope,
      canTakeAttendance: canTakeAttendance,
      canViewReports: canViewReports,
      code: code,
      inviteToken: inviteToken,
      isUsed: isUsed,
      declinedAt: declinedAt,
      createdAt: createdAt,
    );
  }

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
