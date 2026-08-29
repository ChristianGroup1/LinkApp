import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../logic/meetings_bloc.dart';
import 'meeting_dialogs.dart';
import '../add_edit_meeting_screen.dart';

class MeetingCard extends StatefulWidget {
  final MeetingEntity meeting;
  final bool isAdmin;
  final List<Map<String, dynamic>> assignments;
  final List<HelperInvitation> pendingInvitations;

  const MeetingCard({
    super.key,
    required this.meeting,
    required this.isAdmin,
    required this.assignments,
    this.pendingInvitations = const [],
  });

  @override
  State<MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends State<MeetingCard> {
  @override
  Widget build(BuildContext context) {
    final totalServants =
        widget.assignments.length + widget.pendingInvitations.length;

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
            color: AppTheme.secondary.withValues(alpha: 0.03),
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
            // Card Top Gradient Accent Line
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.secondary, Color(0xFF34D399)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header & Actions Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.secondaryLight,
                              AppTheme.secondaryLight.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: AppTheme.secondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.meeting.nameAr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppTheme.textDark,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _MeetingMetaTag(
                                  icon: Icons.event_repeat_rounded,
                                  label:
                                      'كل يوم ${kWeekdaysAr[widget.meeting.weekday - 1]}',
                                  color: AppTheme.secondary,
                                  backgroundColor: AppTheme.secondaryLight,
                                ),
                                if (widget.meeting.attendanceReminderMinutes !=
                                    null)
                                  _MeetingMetaTag(
                                    icon: Icons.notifications_active_rounded,
                                    label:
                                        'تذكير ${_formatReminderTime(widget.meeting.attendanceReminderMinutes!)}',
                                    color: AppTheme.primary,
                                    backgroundColor: AppTheme.primaryLight,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.isAdmin) ...[
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                showEditMeetingScreen(context, widget.meeting),
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
                            onTap: () => showConfirmDeleteMeeting(
                              context,
                              widget.meeting,
                            ),
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
                  if (widget.meeting.description != null &&
                      widget.meeting.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.meeting.description!,
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
                        'مسؤولو الحضور',
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
                              ? AppTheme.secondaryLight
                              : AppTheme.accentRedLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalServants',
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: totalServants > 0
                                ? AppTheme.secondary
                                : AppTheme.accentRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.assignments.isEmpty &&
                      widget.pendingInvitations.isEmpty)
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
                            'لا يوجد مسؤولو حضور معينون بعد.',
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
                        ...widget.assignments.map((assign) {
                          final profile =
                              assign['profiles'] as Map<String, dynamic>;
                          return _MeetingPersonTag(
                            name: profile['full_name'] as String,
                            onRemove: widget.isAdmin
                                ? () => _removeOfficer(assign['id'] as String)
                                : null,
                          );
                        }),
                        ...widget.pendingInvitations.map(
                          (invite) => _MeetingPersonTag(
                            name: invite.fullName,
                            isPending: true,
                          ),
                        ),
                      ],
                    ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            showAssignOfficerDialog(context, widget.meeting),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 17,
                        ),
                        label: Text(
                          'تعيين مسؤول حضور',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: AppTheme.primaryLight.withValues(
                            alpha: 0.25,
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
      ),
    );
  }

  Future<void> _removeOfficer(String assignmentId) async {
    final repo = context.read<DatabaseRepository>();
    final meetingsBloc = context.read<MeetingsBloc>();
    await repo.removeMeetingAssignment(assignmentId);
    if (!mounted) return;
    meetingsBloc.add(LoadMeetingsAndClasses());
  }

  String _formatReminderTime(int minutesAfterMidnight) {
    final time = TimeOfDay(
      hour: minutesAfterMidnight ~/ 60,
      minute: minutesAfterMidnight % 60,
    );
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
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
