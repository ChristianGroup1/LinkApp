import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/app_states.dart';
import '../logic/attendance_bloc.dart';
import 'attendance_recording_screen.dart';
import 'widgets/attendance_date_picker.dart';
import 'widgets/attendance_sessions_list.dart';

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen> {
  AttendanceBloc? _attendanceBloc;
  MeetingEntity? _selectedMeeting;
  SundaySchoolClassEntity? _selectedClass;
  List<MeetingEntity> _meetings = [];
  List<SundaySchoolClassEntity> _classes = [];
  List<AttendanceSessionEntity> _sessions = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  Set<String> _attendanceClassIds = {};
  Set<String> _attendanceMeetingIds = {};
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attendanceBloc ??= AttendanceBloc(
      repository: context.read<DatabaseRepository>(),
    );
  }

  @override
  void dispose() {
    _attendanceBloc?.close();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final repo = context.read<DatabaseRepository>();
    try {
      final profile = await repo.getCurrentProfile();
      final results = await Future.wait([
        repo.getMeetings(),
        repo.getAllSundaySchoolClasses(),
      ]);
      final allMeetings = results[0] as List<MeetingEntity>;
      final allClasses = results[1] as List<SundaySchoolClassEntity>;
      final isAdmin =
          profile?.role == AppRole.superAdmin ||
          profile?.role == AppRole.churchAdmin;

      final List<MeetingEntity> meetings;
      final List<SundaySchoolClassEntity> classes;

      if (profile == null) {
        meetings = [];
        classes = [];
        _attendanceClassIds = {};
        _attendanceMeetingIds = {};
      } else if (isAdmin) {
        meetings = allMeetings.where((m) => m.isActive).toList();
        classes = allClasses.where((c) => c.isActive).toList();
        _attendanceClassIds = {};
        _attendanceMeetingIds = {};
      } else {
        final assignments = await Future.wait([
          repo.getUserClassAssignments(profile.id),
          repo.getUserMeetingAssignments(profile.id),
        ]);
        _attendanceClassIds = assignments[0]
            .where((a) => a['can_take_attendance'] as bool? ?? true)
            .map((a) => a['class_id'] as String)
            .toSet();
        _attendanceMeetingIds = assignments[1]
            .where((a) => a['can_take_attendance'] as bool? ?? true)
            .map((a) => a['meeting_id'] as String)
            .toSet();
        final classIds = assignments[0]
            .where(
              (a) =>
                  (a['can_view_reports'] as bool? ?? true) ||
                  (a['can_take_attendance'] as bool? ?? true),
            )
            .map((a) => a['class_id'] as String)
            .toSet();
        final meetingIds = assignments[1]
            .where(
              (a) =>
                  (a['can_view_reports'] as bool? ?? true) ||
                  (a['can_take_attendance'] as bool? ?? true),
            )
            .map((a) => a['meeting_id'] as String)
            .toSet();
        classes = allClasses
            .where(
              (cls) =>
                  cls.isActive &&
                  (classIds.contains(cls.id) ||
                      meetingIds.contains(cls.meetingId)),
            )
            .toList();
        final classMeetingIds = classes.map((c) => c.meetingId).toSet();
        meetings = allMeetings
            .where(
              (m) =>
                  m.isActive &&
                  (meetingIds.contains(m.id) ||
                      classMeetingIds.contains(m.id)),
            )
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _classes = classes;
        _isAdmin = isAdmin;
        _selectedMeeting = _meetings.firstOrNull;
        if (_selectedMeeting?.kind == MeetingKind.sundaySchool) {
          _selectedClass = _classes
              .where((c) => c.meetingId == _selectedMeeting!.id)
              .firstOrNull;
        }
      });
      await _loadSessions();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _canDeleteSession(AttendanceSessionEntity session) {
    if (_isAdmin) return true;
    if (session.classId != null) {
      return _attendanceClassIds.contains(session.classId);
    }
    return _attendanceMeetingIds.contains(session.meetingId);
  }

  Future<void> _loadSessions() async {
    final meeting = _selectedMeeting;
    if (meeting == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final repo = context.read<DatabaseRepository>();
    final sessions = await repo.getSessions(
      meeting.id,
      classId: meeting.kind == MeetingKind.sundaySchool
          ? _selectedClass?.id
          : null,
    );
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _selectedSessionId = sessions
          .where((s) => s.id == _selectedSessionId)
          .firstOrNull
          ?.id;
      _selectedSessionId ??= sessions.firstOrNull?.id;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<DatabaseRepository>();
    final attendanceBloc = _attendanceBloc;
    if (attendanceBloc == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final sorted = [..._sessions]
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final filteredSessions = _selectedSessionId == null
        ? sorted
        : sorted.where((s) => s.id == _selectedSessionId).toList();

    return BlocProvider.value(
      value: attendanceBloc,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'السجلات',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocConsumer<AttendanceBloc, AttendanceState>(
            listenWhen: (previous, current) => current is AttendanceError,
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
              return Column(
                children: [
                  _buildFilters(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          )
                        : filteredSessions.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.event_note_outlined,
                            message: 'لا توجد سجلات مطابقة للفلتر',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSessions,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredSessions.length,
                              itemBuilder: (context, index) {
                                final session = filteredSessions[index];
                                final canDelete = _canDeleteSession(session);
                                return AttendanceSessionCard(
                                  session: session,
                                  repository: repo,
                                  canDelete: canDelete,
                                  onOpen: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: context
                                              .read<AttendanceBloc>(),
                                          child: AttendanceRecordingScreen(
                                            session: session,
                                          ),
                                        ),
                                      ),
                                    ).then((_) => _loadSessions());
                                  },
                                  onDelete: canDelete
                                      ? () async {
                                          try {
                                            final synced =
                                                await repo.deleteWeeklySession(
                                              session.id,
                                              meetingId: session.meetingId,
                                              classId: session.classId,
                                            );
                                            if (!mounted) return;
                                            _loadSessions();
                                            if (!synced && mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    kOfflineSavedMessage,
                                                    style: GoogleFonts.cairo(),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'فشل حذف السجل: ${e.toString()}',
                                                  style: GoogleFonts.cairo(),
                                                ),
                                                backgroundColor:
                                                    AppTheme.accentRed,
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }

  Widget _buildFilters() {
    final meetingClasses = _selectedMeeting == null
        ? <SundaySchoolClassEntity>[]
        : _classes
              .where((c) => c.meetingId == _selectedMeeting!.id)
              .toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          DropdownButtonFormField<MeetingEntity>(
            value: _selectedMeeting,
            decoration: const InputDecoration(labelText: 'فلتر الاجتماع'),
            items: _meetings.map((m) {
              return DropdownMenuItem(value: m, child: Text(m.nameAr));
            }).toList(),
            onChanged: (meeting) {
              setState(() {
                _selectedMeeting = meeting;
                _selectedClass =
                    meeting?.kind == MeetingKind.sundaySchool
                    ? _classes
                          .where((c) => c.meetingId == meeting!.id)
                          .firstOrNull
                    : null;
                _selectedSessionId = null;
              });
              _loadSessions();
            },
          ),
          if (_selectedMeeting?.kind == MeetingKind.sundaySchool &&
              meetingClasses.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<SundaySchoolClassEntity>(
              value: _selectedClass,
              decoration: const InputDecoration(labelText: 'فلتر الفصل'),
              items: meetingClasses.map((cls) {
                return DropdownMenuItem(
                  value: cls,
                  child: Text(cls.nameAr),
                );
              }).toList(),
              onChanged: (cls) {
                setState(() {
                  _selectedClass = cls;
                  _selectedSessionId = null;
                });
                _loadSessions();
              },
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedSessionId,
            decoration:
                const InputDecoration(labelText: 'فلتر كشف الحضور'),
            items: _sessions.map((s) {
              return DropdownMenuItem(
                value: s.id,
                child: Text(sessionTitle(s.sessionDate)),
              );
            }).toList(),
            onChanged: (sessionId) {
              setState(() => _selectedSessionId = sessionId);
            },
          ),
        ],
      ),
    );
  }
}
