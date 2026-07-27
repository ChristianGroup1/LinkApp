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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(color: AppTheme.secondary, child: SizedBox(width: 4)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryLight,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: AppTheme.secondary.withValues(alpha: 0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: AppTheme.secondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                    fontSize: 15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _MeetingMetaTag(
                                  icon: Icons.event_repeat_rounded,
                                  label:
                                      'كل يوم ${kWeekdaysAr[widget.meeting.weekday - 1]}',
                                  color: AppTheme.secondary,
                                  backgroundColor: AppTheme.secondaryLight,
                                ),
                              ],
                            ),
                          ),
                          if (widget.isAdmin) ...[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              onPressed: () =>
                                  showEditMeetingScreen(context, widget.meeting),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.accentRed,
                                size: 20,
                              ),
                              onPressed: () =>
                                  showConfirmDeleteMeeting(context, widget.meeting),
                            ),
                          ],
                        ],
                      ),
                      if (widget.meeting.description != null &&
                          widget.meeting.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.meeting.description!,
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        'مسؤولو الحضور',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.assignments.isEmpty &&
                          widget.pendingInvitations.isEmpty)
                        Text(
                          'لا يوجد مسؤولو حضور معينون بعد.',
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
                                    ? () =>
                                          _removeOfficer(assign['id'] as String)
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showAssignOfficerDialog(context, widget.meeting),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                            label: Text(
                              'تعيين مسؤول حضور',
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
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(9),
        border: isPending
            ? Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.35))
            : null,
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
