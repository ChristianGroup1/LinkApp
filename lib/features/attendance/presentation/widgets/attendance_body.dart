import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../logic/attendance_bloc.dart';
import 'attendance_sessions_list.dart';

class AttendanceBody extends StatelessWidget {
  final List<MeetingEntity> meetings;
  final MeetingEntity? selectedMeeting;
  final SundaySchoolClassEntity? selectedClass;
  final List<SundaySchoolClassEntity> selectedMeetingClasses;
  final List<AttendanceSessionEntity> currentScopeSessions;
  final void Function(MeetingEntity?) onMeetingChanged;
  final void Function(int) onClassChanged;
  final void Function(List<AttendanceSessionEntity>) onSessionsUpdated;
  final Future<void> Function(
    BuildContext, {
    required String meetingId,
    String? classId,
    int? meetingWeekday,
  })
  onCreateSession;
  final bool canDeleteSessions;

  const AttendanceBody({
    super.key,
    required this.meetings,
    required this.selectedMeeting,
    required this.selectedClass,
    required this.selectedMeetingClasses,
    required this.currentScopeSessions,
    required this.onMeetingChanged,
    required this.onClassChanged,
    required this.onSessionsUpdated,
    required this.onCreateSession,
    this.canDeleteSessions = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey('${selectedMeeting?.id}_${selectedMeetingClasses.length}'),
      length:
          selectedMeeting?.kind == MeetingKind.sundaySchool &&
              selectedMeetingClasses.isNotEmpty
          ? selectedMeetingClasses.length
          : 1,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
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
                    const SizedBox(width: 8),
                    Text(
                      'اختر الاجتماع',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<MeetingEntity>(
                  initialValue: meetings.contains(selectedMeeting)
                      ? selectedMeeting
                      : (meetings.isNotEmpty ? meetings.first : null),
                  decoration: InputDecoration(
                    labelText: 'الاجتماع',
                    filled: true,
                    fillColor: AppTheme.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: GoogleFonts.cairo(color: AppTheme.textDark),
                  items: meetings.map((m) {
                    return DropdownMenuItem<MeetingEntity>(
                      value: m,
                      child: Text(m.nameAr),
                    );
                  }).toList(),
                  onChanged: onMeetingChanged,
                ),
              ],
            ),
          ),
          if (selectedMeeting?.kind == MeetingKind.sundaySchool &&
              selectedMeetingClasses.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              color: AppTheme.cardBackground,
              width: double.infinity,
              child: TabBar(
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textLight,
                dividerColor: AppTheme.border.withValues(alpha: 0.5),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: selectedMeetingClasses
                    .map((c) => Tab(text: c.nameAr))
                    .toList(),
                onTap: onClassChanged,
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocConsumer<AttendanceBloc, AttendanceState>(
              listener: (context, state) {
                if (state is AttendanceError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message, style: GoogleFonts.cairo()),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                }
              },
              builder: (context, state) {
                var visibleSessions = currentScopeSessions;
                if (state is AttendanceInitial) {
                  if (selectedMeeting != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<AttendanceBloc>().add(
                        LoadAttendanceSessions(
                          meetingId: selectedMeeting!.id,
                          classId: selectedClass?.id,
                        ),
                      );
                    });
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                if (state is AttendanceLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                if (state is SessionsLoaded) {
                  final sessions = [...state.sessions]
                    ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
                  visibleSessions = sessions;
                  final currentIds = currentScopeSessions
                      .map((session) => session.id)
                      .join(',');
                  final nextIds = sessions
                      .map((session) => session.id)
                      .join(',');
                  if (currentIds != nextIds) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onSessionsUpdated(sessions);
                    });
                  }
                }

                return buildSessionsListUi(
                  context: context,
                  currentScopeSessions: visibleSessions,
                  selectedMeeting: selectedMeeting,
                  selectedClass: selectedClass,
                  onCreateSession: onCreateSession,
                  canDeleteSessions: canDeleteSessions,
                  onReloadSessions: () async {
                    if (selectedMeeting != null) {
                      context.read<AttendanceBloc>().add(
                        LoadAttendanceSessions(
                          meetingId: selectedMeeting!.id,
                          classId: selectedClass?.id,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
