import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/app_states.dart';
import '../logic/attendance_bloc.dart';
import '../logic/auto_attendance_session_service.dart';
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
      await AutoAttendanceSessionService.instance.autoCreateSessionsOneDayInAdvance(repo);
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

  bool get _canCreateSession =>
      _isAdmin ||
      _attendanceClassIds.isNotEmpty ||
      _attendanceMeetingIds.isNotEmpty;

  Future<void> _showCreateSessionDialog() async {
    MeetingEntity? dialogMeeting = _selectedMeeting ?? _meetings.firstOrNull;
    SundaySchoolClassEntity? dialogClass = _selectedClass ??
        (_classes.where((c) => c.meetingId == dialogMeeting?.id).firstOrNull);
    DateTime dialogDate = DateTime.now();
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final meetingClasses = dialogMeeting == null
                ? <SundaySchoolClassEntity>[]
                : _classes.where((c) => c.meetingId == dialogMeeting!.id).toList();

            final dateStr = intl.DateFormat('yyyy-MM-dd', 'ar').format(dialogDate);
            final dayAr = intl.DateFormat('EEEE', 'ar').format(dialogDate);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.post_add_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            'إنشاء كشف حضور جديد',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'اختر الاجتماع والتاريخ لإنشاء كشف مستقل جديد',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dropdown Meeting
                  DropdownButtonFormField<MeetingEntity>(
                    initialValue: _meetings.contains(dialogMeeting)
                        ? dialogMeeting
                        : _meetings.firstOrNull,
                    decoration: const InputDecoration(labelText: 'الاجتماع'),
                    items: _meetings.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m.nameAr));
                    }).toList(),
                    onChanged: (meeting) {
                      setModalState(() {
                        dialogMeeting = meeting;
                        dialogClass = meeting?.kind == MeetingKind.sundaySchool
                            ? _classes.where((c) => c.meetingId == meeting!.id).firstOrNull
                            : null;
                      });
                    },
                  ),

                  // Dropdown Class (if Sunday School)
                  if (dialogMeeting?.kind == MeetingKind.sundaySchool &&
                      meetingClasses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SundaySchoolClassEntity>(
                      initialValue: meetingClasses.contains(dialogClass)
                          ? dialogClass
                          : meetingClasses.firstOrNull,
                      decoration: const InputDecoration(labelText: 'الفصل'),
                      items: meetingClasses.map((cls) {
                        return DropdownMenuItem(value: cls, child: Text(cls.nameAr));
                      }).toList(),
                      onChanged: (cls) {
                        setModalState(() => dialogClass = cls);
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Session Date Picker
                  Text(
                    'تاريخ الكشف:',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await pickAttendanceDate(
                        context,
                        meetingWeekday: dialogMeeting?.weekday,
                        existingSessions: _sessions,
                      );
                      if (picked != null) {
                        setModalState(() => dialogDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '$dayAr ($dateStr)',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.edit_calendar_rounded, color: AppTheme.textLight, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isSubmitting || dialogMeeting == null)
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(this.context);
                              final rootNavigator = Navigator.of(this.context);
                              final bloc = _attendanceBloc;
                              try {
                                final repo = this.context.read<DatabaseRepository>();
                                final weekNum = (dialogDate.day / 7).ceil();
                                final saveResult = await repo.createWeeklySession(
                                  meetingId: dialogMeeting!.id,
                                  classId: dialogMeeting!.kind == MeetingKind.sundaySchool
                                      ? dialogClass?.id
                                      : null,
                                  sessionDate: dialogDate,
                                  weekNumber: weekNum,
                                );

                                if (mounted) {
                                  Navigator.pop(sheetContext); // Close bottom sheet
                                  await _loadSessions(); // Reload sessions list

                                  final newSession = saveResult.data;
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم إنشاء كشف الحضور بنجاح! 🎉',
                                          style: GoogleFonts.cairo(),
                                        ),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );

                                    if (newSession != null && bloc != null) {
                                      rootNavigator.push(
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: bloc,
                                            child: AttendanceRecordingScreen(
                                              session: newSession,
                                            ),
                                          ),
                                        ),
                                      ).then((_) {
                                        if (mounted) _loadSessions();
                                      });
                                    }
                                  }
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'فشل إنشاء الكشف: ${e.toString()}',
                                        style: GoogleFonts.cairo(),
                                      ),
                                      backgroundColor: AppTheme.accentRed,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isSubmitting ? 'جاري إنشاء الكشف...' : 'إنشاء الكشف 🚀',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          actions: [],
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
                                          final messenger =
                                              ScaffoldMessenger.of(context);
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
                                              messenger.showSnackBar(
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
                                            messenger.showSnackBar(
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
          floatingActionButton: _canCreateSession
              ? FloatingActionButton.extended(
                  onPressed: _showCreateSessionDialog,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: Text(
                    'كشف جديد ',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
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
            value: _meetings.contains(_selectedMeeting)
                ? _selectedMeeting
                : null,
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
              value: meetingClasses.contains(_selectedClass)
                  ? _selectedClass
                  : null,
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
            value: _sessions.any((s) => s.id == _selectedSessionId)
                ? _selectedSessionId
                : null,
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
