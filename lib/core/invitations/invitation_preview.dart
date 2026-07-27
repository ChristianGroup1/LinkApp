import '../../shared/data/app_models.dart';

class InvitationPreview {
  final bool valid;
  final String? status;
  final String? invitationId;
  final String? churchId;
  final String? churchName;
  final String? inviteeName;
  final String? email;
  final AppRole? role;
  final String? assignmentScope;
  final bool canTakeAttendance;
  final bool canViewReports;

  const InvitationPreview({
    required this.valid,
    this.status,
    this.invitationId,
    this.churchId,
    this.churchName,
    this.inviteeName,
    this.email,
    this.role,
    this.assignmentScope,
    this.canTakeAttendance = true,
    this.canViewReports = true,
  });

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    final roleValue = json['role'] as String?;
    return InvitationPreview(
      valid: json['valid'] == true,
      status: json['status'] as String?,
      invitationId: json['invitation_id'] as String?,
      churchId: json['church_id'] as String?,
      churchName: json['church_name'] as String?,
      inviteeName: json['invitee_name'] as String?,
      email: json['email'] as String?,
      role: roleValue == null ? null : AppRole.fromJson(roleValue),
      assignmentScope: json['assignment_scope'] as String?,
      canTakeAttendance: json['can_take_attendance'] as bool? ?? true,
      canViewReports: json['can_view_reports'] as bool? ?? true,
    );
  }

  String get scopeLabel {
    switch (assignmentScope) {
      case 'class':
        return 'فصل واحد';
      case 'meeting_classes':
        return 'كل فصول اجتماع';
      case 'meeting':
        return 'اجتماع مباشر';
      default:
        return 'مكان محدد';
    }
  }

  List<String> get permissions {
    final items = <String>[];
    if (canTakeAttendance) items.add('تسجيل الحضور والغياب');
    if (canViewReports) items.add('عرض التقارير والمتابعة');
    return items;
  }
}
