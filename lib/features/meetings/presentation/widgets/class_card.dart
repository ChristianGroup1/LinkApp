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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ColoredBox(
                    color: AppTheme.primary,
                    child: SizedBox(width: 4),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.calendar_view_week_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meeting.nameAr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              onPressed: onEditMeeting,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.accentRed,
                                size: 20,
                              ),
                              onPressed: onDeleteMeeting,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (meeting.description != null && meeting.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  meeting.description!,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    color: AppTheme.textLight,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خدام الاجتماع',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (aggregatedAssignments.isEmpty && meetingPending.isEmpty)
                    Text(
                      'لا يوجد خدام أو دعوات معلقة بعد.',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.accentRed,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  if (isAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAddClass,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          'إضافة فصل',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (classes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'لا توجد فصول داخل هذا الاجتماع حالياً.',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          color: AppTheme.textLight,
                        ),
                      ),
                    )
                  else ...[
                    if (isAdmin) const SizedBox(height: 10),
                    ...classes.map(
                      (cls) => ClassCard(
                        cls: cls,
                        isAdmin: isAdmin,
                        assignments: classAssignmentsById[cls.id] ?? [],
                        pendingInvitations: pendingInvitations,
                      ),
                    ),
                  ],
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
    final classPending =
        pendingInvitesForClass(widget.pendingInvitations, widget.cls.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cls.nameAr.trim().isNotEmpty
                                ? widget.cls.nameAr
                                : widget.cls.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: AppTheme.textDark,
                            ),
                          ),
                          if (classPending.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${classPending.length} دعوة بانتظار التفعيل',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isAdmin) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        onPressed: () => _showEditClassDialog(context),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.accentRed,
                          size: 18,
                        ),
                        onPressed: () => _confirmDeleteClass(context),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خدام الفصل',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.assignments.isEmpty && classPending.isEmpty)
                    Text(
                      'لا يوجد خدام معينون بعد.',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.accentRed,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showAssignLeaderDialog(context, widget.cls),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: Text(
                          'تعيين خادم',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 10,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPending
            ? AppTheme.accentOrange.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isPending
              ? AppTheme.accentOrange.withValues(alpha: 0.35)
              : AppTheme.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending
                ? Icons.hourglass_top_rounded
                : Icons.person_outline_rounded,
            size: 13,
            color: isPending ? AppTheme.accentOrange : AppTheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? '$name (بانتظار التفعيل)' : name,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textLight),
            ),
          ],
        ],
      ),
    );
  }
}
