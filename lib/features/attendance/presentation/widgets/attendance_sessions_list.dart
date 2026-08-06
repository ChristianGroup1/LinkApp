import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../../../shared/ui/app_states.dart';
import '../../logic/attendance_bloc.dart';
import '../attendance_recording_screen.dart';
import 'attendance_date_picker.dart';

final Map<String, AttendanceSummary> _sessionSummaryCache = {};

void invalidateSessionSummaryCache([String? sessionId]) {
  if (sessionId == null) {
    _sessionSummaryCache.clear();
    return;
  }
  _sessionSummaryCache.remove(sessionId);
}

Future<void> prefetchAttendanceSessionSummaries(
  DatabaseRepository repository,
  List<AttendanceSessionEntity> sessions,
) async {
  final uncached = sessions
      .where((session) => !_sessionSummaryCache.containsKey(session.id))
      .toList(growable: false);
  if (uncached.isEmpty) return;

  await Future.wait(
    uncached.map((session) async {
      final summary = await loadAttendanceSessionSummary(repository, session);
      _sessionSummaryCache[session.id] = summary;
    }),
  );
}

Future<AttendanceSummary> loadAttendanceSessionSummary(
  DatabaseRepository repository,
  AttendanceSessionEntity session,
) async {
  final records = await repository.getAttendanceRecords(session.id);
  final members = session.classId == null
      ? await repository.getMeetingMembers(session.meetingId)
      : await repository.getClassMembers(session.classId!);

  final namesById = {for (final member in members) member.id: member.fullName};
  final present = <String>[];
  final absent = <String>[];
  final excused = <String>[];

  for (final record in records) {
    final name = namesById[record.memberId];
    if (name == null) continue;
    switch (record.status) {
      case AttendanceStatus.present:
        present.add(name);
        break;
      case AttendanceStatus.absent:
        absent.add(name);
        break;
      case AttendanceStatus.excused:
        excused.add(name);
        break;
    }
  }

  return AttendanceSummary(
    membersCount: members.length,
    present: present..sort(),
    absent: absent..sort(),
    excused: excused..sort(),
  );
}

Widget buildSessionAttendanceStatsRow({
  required int? present,
  required int? absent,
  required int? excused,
}) {
  return SizedBox(
    height: 36,
    child: Row(
      children: [
        Expanded(
          child: _sessionAttendanceStatChip(
            label: 'حاضر',
            value: present,
            color: AppTheme.secondary,
            icon: Icons.check_rounded,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _sessionAttendanceStatChip(
            label: 'غائب',
            value: absent,
            color: AppTheme.accentRed,
            icon: Icons.close_rounded,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _sessionAttendanceStatChip(
            label: 'مستأذن',
            value: excused,
            color: AppTheme.accentOrange,
            icon: Icons.event_busy_rounded,
          ),
        ),
      ],
    ),
  );
}

Widget _sessionAttendanceStatChip({
  required String label,
  required int? value,
  required Color color,
  required IconData icon,
}) {
  final isLoading = value == null;
  return AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: isLoading ? 0.5 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Text(
                  '${value ?? 0}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.9),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AttendanceSessionCard extends StatefulWidget {
  final AttendanceSessionEntity session;
  final DatabaseRepository repository;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final bool canDelete;

  const AttendanceSessionCard({
    super.key,
    required this.session,
    required this.repository,
    required this.onOpen,
    this.onDelete,
    this.canDelete = false,
  });

  @override
  State<AttendanceSessionCard> createState() => _AttendanceSessionCardState();
}

class _AttendanceSessionCardState extends State<AttendanceSessionCard> {
  AttendanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    _summary = _sessionSummaryCache[widget.session.id];
    if (_summary == null) {
      _loadSummary();
    }
  }

  @override
  void didUpdateWidget(covariant AttendanceSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _summary = _sessionSummaryCache[widget.session.id];
      if (_summary == null) {
        _loadSummary();
      }
      return;
    }

    final cached = _sessionSummaryCache[widget.session.id];
    if (cached != null && cached != _summary) {
      setState(() => _summary = cached);
    }
  }

  Future<void> _loadSummary() async {
    final summary = await loadAttendanceSessionSummary(
      widget.repository,
      widget.session,
    );
    _sessionSummaryCache[widget.session.id] = summary;
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateStr = intl.DateFormat('d/M/yyyy').format(session.sessionDate);
    final summary = _summary ?? _sessionSummaryCache[widget.session.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitle(session.sessionDate),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'التاريخ: $dateStr • أسبوع: ${session.weekNumber}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canDelete && widget.onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.accentRed,
                  ),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMembersCountChip(summary?.membersCount),
          const SizedBox(height: 8),
          buildSessionAttendanceStatsRow(
            present: summary?.present.length,
            absent: summary?.absent.length,
            excused: summary?.excused.length,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: widget.onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'فتح الكشف',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: summary == null
                      ? null
                      : () => _showDetails(context, summary),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                  child: Text(
                    'التفاصيل',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCountChip(int? value) {
    final isLoading = value == null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isLoading ? 0.5 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_rounded,
              size: 16,
              color: AppTheme.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Text(
              'الأعضاء: ${value ?? 0}',
              style: GoogleFonts.cairo(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, AttendanceSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    'تفاصيل كشف الحضور',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildNamesSection('حاضر', summary.present, Colors.green),
                  _buildNamesSection(
                    'غائب',
                    summary.absent,
                    AppTheme.accentRed,
                  ),
                  _buildNamesSection('مستأذن', summary.excused, Colors.orange),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNamesSection(String title, List<String> names, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${names.length})',
            style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (names.isEmpty)
            Text('لا يوجد', style: GoogleFonts.cairo(color: AppTheme.textLight))
          else
            ...names.map(
              (name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(name, style: GoogleFonts.cairo()),
              ),
            ),
        ],
      ),
    );
  }
}

class AttendanceSummary {
  final int membersCount;
  final List<String> present;
  final List<String> absent;
  final List<String> excused;

  const AttendanceSummary({
    required this.membersCount,
    required this.present,
    required this.absent,
    required this.excused,
  });
}

/// بناء واجهة عرض قائمة الجلسات
Widget buildSessionsListUi({
  required BuildContext context,
  required List<AttendanceSessionEntity> currentScopeSessions,
  required MeetingEntity? selectedMeeting,
  required SundaySchoolClassEntity? selectedClass,
  required Future<void> Function(
    BuildContext, {
    required String meetingId,
    String? classId,
    int? meetingWeekday,
  })
  onCreateSession,
  required Future<void> Function() onReloadSessions,
  bool canDeleteSessions = false,
}) {
  if (currentScopeSessions.isEmpty) {
    return AppEmptyState(
      icon: Icons.playlist_add_check,
      message: 'لا توجد سجلات سابقة لهذا النطاق.',
      actionLabel: 'إنشاء كشف حضور جديد',
      onAction: () => onCreateSession(
        context,
        meetingId: selectedMeeting!.id,
        classId: selectedClass?.id,
        meetingWeekday: selectedMeeting.weekday,
      ),
    );
  }

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onCreateSession(
              context,
              meetingId: selectedMeeting!.id,
              classId: selectedClass?.id,
              meetingWeekday: selectedMeeting.weekday,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'كشف جديد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: BlocBuilder<AttendanceBloc, AttendanceState>(
          builder: (context, state) {
            return _SessionsListView(
              sessions: currentScopeSessions,
              selectedMeeting: selectedMeeting,
              selectedClass: selectedClass,
              canDeleteSessions: canDeleteSessions,
              onReloadSessions: onReloadSessions,
            );
          },
        ),
      ),
    ],
  );
}

class _SessionsListView extends StatefulWidget {
  final List<AttendanceSessionEntity> sessions;
  final MeetingEntity? selectedMeeting;
  final SundaySchoolClassEntity? selectedClass;
  final bool canDeleteSessions;
  final Future<void> Function() onReloadSessions;

  const _SessionsListView({
    required this.sessions,
    required this.selectedMeeting,
    required this.selectedClass,
    required this.canDeleteSessions,
    required this.onReloadSessions,
  });

  @override
  State<_SessionsListView> createState() => _SessionsListViewState();
}

class _SessionsListViewState extends State<_SessionsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchSummaries());
  }

  @override
  void didUpdateWidget(covariant _SessionsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSessions(oldWidget.sessions, widget.sessions)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchSummaries());
    }
  }

  bool _sameSessions(
    List<AttendanceSessionEntity> a,
    List<AttendanceSessionEntity> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _prefetchSummaries() async {
    final repository = context.read<DatabaseRepository>();
    await prefetchAttendanceSessionSummaries(repository, widget.sessions);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: widget.sessions.length,
      itemBuilder: (context, index) {
        final session = widget.sessions[index];
        return _SessionTile(
          session: session,
          selectedMeeting: widget.selectedMeeting,
          selectedClass: widget.selectedClass,
          canDelete: widget.canDeleteSessions,
          onReloadSessions: widget.onReloadSessions,
        );
      },
    );
  }
}

class _SessionTile extends StatefulWidget {
  final AttendanceSessionEntity session;
  final MeetingEntity? selectedMeeting;
  final SundaySchoolClassEntity? selectedClass;
  final Future<void> Function() onReloadSessions;
  final bool canDelete;

  const _SessionTile({
    required this.session,
    required this.selectedMeeting,
    required this.selectedClass,
    required this.onReloadSessions,
    this.canDelete = false,
  });

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  AttendanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    final cached = _sessionSummaryCache[widget.session.id];
    if (cached != null) {
      _summary = cached;
    } else {
      _loadSummary();
    }
  }

  @override
  void didUpdateWidget(covariant _SessionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _summary = _sessionSummaryCache[widget.session.id];
      if (_summary == null) {
        _loadSummary();
      }
      return;
    }

    final cached = _sessionSummaryCache[widget.session.id];
    if (cached != null && cached != _summary) {
      setState(() => _summary = cached);
    }
  }

  Future<void> _loadSummary() async {
    final repo = context.read<DatabaseRepository>();
    final summary = await loadAttendanceSessionSummary(repo, widget.session);
    _sessionSummaryCache[widget.session.id] = summary;
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final date = session.sessionDate;
    final dayLabel = intl.DateFormat('d', 'ar').format(date);
    final monthLabel = intl.DateFormat('MMM', 'ar').format(date);
    final fullDateLabel = intl.DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(date);
    final title = session.title ?? sessionTitle(date);
    final summary = _summary ?? _sessionSummaryCache[widget.session.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSession(context),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.75),
              ),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.14),
                        AppTheme.primaryAccent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthLabel,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullDateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: AppTheme.textLight,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildSessionAttendanceStatsRow(
                        present: summary?.present.length,
                        absent: summary?.absent.length,
                        excused: summary?.excused.length,
                      ),
                    ],
                  ),
                ),
                if (widget.canDelete)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.accentRed,
                      size: 20,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppTheme.primary,
                    size: 22,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد الحذف', style: GoogleFonts.cairo()),
        content: Text(
          'هل أنت متأكد من حذف هذا السجل نهائياً؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () {
              invalidateSessionSummaryCache(widget.session.id);
              context.read<AttendanceBloc>().add(
                DeleteSession(widget.session.id),
              );
              Navigator.pop(dialogContext);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openSession(BuildContext context) {
    final attendanceBloc = context.read<AttendanceBloc>();
    final meetingId = widget.selectedMeeting?.id ?? widget.session.meetingId;
    final classId = widget.selectedClass?.id ?? widget.session.classId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: attendanceBloc,
          child: AttendanceRecordingScreen(session: widget.session),
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      invalidateSessionSummaryCache(widget.session.id);
      _loadSummary();
      attendanceBloc.add(
        LoadAttendanceSessions(meetingId: meetingId, classId: classId),
      );
    });
  }
}
