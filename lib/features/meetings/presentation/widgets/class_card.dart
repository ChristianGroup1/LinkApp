import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../logic/meetings_bloc.dart';
import 'meeting_dialogs.dart';
import 'meeting_assignment_helpers.dart';

class GroupedMeetingClassesCard extends StatelessWidget {
  final MeetingEntity meeting;
  final List<SundaySchoolClassEntity> classes;
  final bool isAdmin;
  final Map<String, List<Map<String, dynamic>>> classAssignmentsById;
  final List<HelperInvitation> pendingInvitations;
  final VoidCallback onAddClass;
  final VoidCallback onEditMeeting;
  final VoidCallback onDeleteMeeting;

  const GroupedMeetingClassesCard({
    super.key,
    required this.meeting,
    required this.classes,
    required this.isAdmin,
    required this.classAssignmentsById,
    this.pendingInvitations = const [],
    required this.onAddClass,
    required this.onEditMeeting,
    required this.onDeleteMeeting,
  });

  @override
  Widget build(BuildContext context) {
    final aggregatedAssignments = aggregateClassAssignmentsForMeeting(
      classes,
      classAssignmentsById,
    );
    final meetingPending = pendingInvitesForSundaySchoolMeeting(
      pendingInvitations,
      meeting.id,
      classes,
    );
    final totalServants = aggregatedAssignments.length + meetingPending.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Gradient Accent Strip
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryLight,
                              AppTheme.primaryLight.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    meeting.nameAr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppTheme.textDark,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${classes.length} فصول',
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _MeetingMetaTag(
                              icon: Icons.event_repeat_rounded,
                              label:
                                  'كل يوم ${kWeekdaysAr[meeting.weekday - 1]}',
                              color: AppTheme.primary,
                              backgroundColor: AppTheme.primaryLight,
                            ),
                          ],
                        ),
                      ),
                      if (isAdmin) ...[
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onEditMeeting,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onDeleteMeeting,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRedLight.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.accentRed,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (meeting.description != null &&
                      meeting.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        meeting.description!,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppTheme.textLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'خدام الاجتماع',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: totalServants > 0
                              ? AppTheme.primaryLight
                              : AppTheme.accentRedLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalServants',
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: totalServants > 0
                                ? AppTheme.primary
                                : AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (aggregatedAssignments.isEmpty && meetingPending.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRedLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentRed.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppTheme.accentRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'لا يوجد خدام أو دعوات معلقة بعد.',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              color: AppTheme.accentRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...aggregatedAssignments.map((assign) {
                          final profile =
                              assign['profiles'] as Map<String, dynamic>;
                          return _MeetingPersonTag(
                            name: profile['full_name'] as String,
                          );
                        }),
                        ...meetingPending.map(
                          (pending) => _MeetingPersonTag(
                            name: pending.className == null
                                ? pending.invite.fullName
                                : '${pending.invite.fullName} · ${pending.className}',
                            isPending: true,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'قائمة الفصول الدراسية',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (isAdmin)
                        TextButton.icon(
                          onPressed: onAddClass,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          label: Text(
                            'إضافة فصل',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (classes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        'لا توجد فصول داخل هذا الاجتماع حالياً.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: classes
                          .map(
                            (cls) => ClassCard(
                              cls: cls,
                              isAdmin: isAdmin,
                              assignments: classAssignmentsById[cls.id] ?? [],
                              pendingInvitations: pendingInvitations,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassCard extends StatefulWidget {
  final SundaySchoolClassEntity cls;
  final bool isAdmin;
  final List<Map<String, dynamic>> assignments;
  final List<HelperInvitation> pendingInvitations;

  const ClassCard({
    super.key,
    required this.cls,
    required this.isAdmin,
    required this.assignments,
    this.pendingInvitations = const [],
  });

  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final classPending = pendingInvitesForClass(
      widget.pendingInvitations,
      widget.cls.id,
    );
    final totalServants = widget.assignments.length + classPending.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _expanded
            ? Colors.white
            : AppTheme.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.border.withValues(alpha: 0.7),
        ),
        boxShadow: _expanded ? AppTheme.cardShadow : null,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _expanded
                            ? AppTheme.primary
                            : AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: _expanded ? Colors.white : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.cls.nameAr.trim().isNotEmpty
                                      ? widget.cls.nameAr
                                      : widget.cls.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$totalServants خادم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (classPending.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 12,
                                  color: AppTheme.accentOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${classPending.length} دعوة بانتظار التفعيل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isAdmin) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showEditClassDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_outlined,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _confirmDeleteClass(context),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              color: AppTheme.accentRed,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _expanded ? AppTheme.primary : AppTheme.textLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 10),
                  Text(
                    'خدام الفصل المعينين',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.assignments.isEmpty && classPending.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRedLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'لا يوجد خدام معينون بعد.',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...widget.assignments.map((assign) {
                          final profile =
                              assign['profiles'] as Map<String, dynamic>;
                          return _MeetingPersonTag(
                            name: profile['full_name'] as String,
                            onRemove: widget.isAdmin
                                ? () => _removeLeader(assign['id'] as String)
                                : null,
                          );
                        }),
                        ...classPending.map(
                          (invite) => _MeetingPersonTag(
                            name: invite.fullName,
                            isPending: true,
                          ),
                        ),
                      ],
                    ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            showAssignLeaderDialog(context, widget.cls),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'تعيين خادم للفصل',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppTheme.primaryLight.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditClassDialog(BuildContext context) {
    final displayName = widget.cls.nameAr.trim().isNotEmpty
        ? widget.cls.nameAr
        : widget.cls.name;
    final nameController = TextEditingController(text: displayName);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'تعديل الفصل',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: nameController,
              style: GoogleFonts.cairo(),
              autofocus: true,
              decoration: meetingFormInputDecoration(
                'اسم الفصل*',
                Icons.class_rounded,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  context.read<MeetingsBloc>().add(
                    UpdateClass(
                      id: widget.cls.id,
                      name: name,
                      nameAr: name,
                      displayOrder: widget.cls.displayOrder,
                      isActive: true,
                    ),
                  );
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: Text(
                  'حفظ',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteClass(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'حذف الفصل نهائياً؟',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'سيتم حذف الفصل وكل الأعضاء وسجلات الحضور والمتابعة المرتبطة به. لا يمكن التراجع عن هذا الإجراء.',
              style: GoogleFonts.cairo(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<MeetingsBloc>().add(DeleteClass(widget.cls.id));
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                ),
                child: Text(
                  'حذف',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeLeader(String assignmentId) async {
    final repo = context.read<DatabaseRepository>();
    final meetingsBloc = context.read<MeetingsBloc>();
    await repo.removeClassAssignment(assignmentId);
    if (!mounted) return;
    meetingsBloc.add(LoadMeetingsAndClasses());
  }
}

class _MeetingMetaTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _MeetingMetaTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingPersonTag extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;
  final bool isPending;

  const _MeetingPersonTag({
    required this.name,
    this.onRemove,
    this.isPending = false,
  });

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return fullName.isNotEmpty ? fullName[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final tagColor = isPending ? AppTheme.accentOrange : AppTheme.primary;
    final tagBg = isPending
        ? AppTheme.accentOrangeLight
        : AppTheme.primaryLight.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tagColor.withValues(alpha: isPending ? 0.4 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: tagColor,
            child: Text(
              initials,
              style: GoogleFonts.cairo(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isPending ? '$name (بانتظار التفعيل)' : name,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppTheme.textLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
