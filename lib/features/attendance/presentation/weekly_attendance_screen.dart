import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/app_states.dart';
import '../../church/logic/church_bloc.dart';
import '../logic/attendance_bloc.dart';
import 'attendance_recording_screen.dart';
import 'widgets/attendance_body.dart';
import 'widgets/attendance_date_picker.dart';

class WeeklyAttendanceScreen extends StatefulWidget {
  const WeeklyAttendanceScreen({super.key});

  @override
  State<WeeklyAttendanceScreen> createState() => _WeeklyAttendanceScreenState();
}

class _WeeklyAttendanceScreenState extends State<WeeklyAttendanceScreen> {
  AttendanceBloc? _attendanceBloc;
  MeetingEntity? _selectedMeeting;
  SundaySchoolClassEntity? _selectedClass;
  List<MeetingEntity> _meetings = [];
  List<SundaySchoolClassEntity> _classes = [];
  bool _isLoadingDropdowns = true;
  bool _hasLoadedScopes = false;
  bool _canDeleteSessions = false;
  List<AttendanceSessionEntity> _currentScopeSessions = [];

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

  Future<void> _loadAvailableScopes(ChurchContextLoaded churchState) async {
    if (_hasLoadedScopes) return;
    _hasLoadedScopes = true;
    try {
      setState(() => _isLoadingDropdowns = true);
      final repo = context.read<DatabaseRepository>();
      final profile = churchState.profile;
      final isAdmin =
          profile.role == AppRole.superAdmin ||
          profile.role == AppRole.churchAdmin;

      final results = await Future.wait([
        repo.getMeetings(),
        repo.getAllSundaySchoolClasses(),
      ]);
      final allMeetings = results[0] as List<MeetingEntity>;
      final allClasses = results[1] as List<SundaySchoolClassEntity>;

      final List<MeetingEntity> filteredMeetings = [];
      final List<SundaySchoolClassEntity> filteredClasses = [];

      if (isAdmin) {
        filteredMeetings.addAll(allMeetings.where((m) => m.isActive));
        filteredClasses.addAll(allClasses.where((c) => c.isActive));
        _canDeleteSessions = true;
      } else {
        final assignments = await Future.wait([
          repo.getUserClassAssignments(profile.id),
          repo.getUserMeetingAssignments(profile.id),
        ]);
        final classIds = assignments[0]
            .where((a) => a['can_take_attendance'] as bool? ?? true)
            .map((a) => a['class_id'] as String)
            .toSet();
        final meetingIds = assignments[1]
            .where((a) => a['can_take_attendance'] as bool? ?? true)
            .map((a) => a['meeting_id'] as String)
            .toSet();
        _canDeleteSessions = classIds.isNotEmpty || meetingIds.isNotEmpty;
        filteredClasses.addAll(
          allClasses.where(
            (cls) =>
                cls.isActive &&
                (classIds.contains(cls.id) ||
                    meetingIds.contains(cls.meetingId)),
          ),
        );
        final classMeetingIds = filteredClasses.map((c) => c.meetingId).toSet();
        filteredMeetings.addAll(
          allMeetings.where(
            (m) =>
                m.isActive &&
                (meetingIds.contains(m.id) || classMeetingIds.contains(m.id)),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _meetings = filteredMeetings;
        _classes = filteredClasses;
        _isLoadingDropdowns = false;
        _hasLoadedScopes = true;
        if (_meetings.isNotEmpty) {
          _selectedMeeting = _meetings.first;
          if (_selectedMeeting!.kind == MeetingKind.sundaySchool) {
            _selectedClass = _classesForMeeting(_selectedMeeting).firstOrNull;
          }
          _attendanceBloc?.add(
            LoadAttendanceSessions(
              meetingId: _selectedMeeting!.id,
              classId: _selectedClass?.id,
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
          _hasLoadedScopes = true;
        });
      }
    }
  }

  List<SundaySchoolClassEntity> _classesForMeeting(MeetingEntity? meeting) {
    if (meeting == null) return <SundaySchoolClassEntity>[];
    return _classes.where((c) => c.meetingId == meeting.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceBloc = _attendanceBloc;
    if (attendanceBloc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return BlocProvider.value(
      value: attendanceBloc,
      child: Builder(
        builder: (context) {
          return BlocBuilder<ChurchBloc, ChurchState>(
            builder: (context, churchState) {
              if (churchState is ChurchContextLoaded && !_hasLoadedScopes) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_hasLoadedScopes) {
                    _loadAvailableScopes(churchState);
                  }
                });
              }
              final selectedMeetingClasses = _classesForMeeting(
                _selectedMeeting,
              );

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  backgroundColor: AppTheme.background,
                  appBar: AppBar(
                    backgroundColor: AppTheme.cardBackground,
                    elevation: 0,
                    title: Text(
                      'تسجيل الحضور الأسبوعي',
                      style: GoogleFonts.cairo(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  body: churchState is ChurchError
                      ? AppErrorState(
                          message: churchState.message,
                          onRetry: () {
                            context.read<ChurchBloc>().add(LoadChurchContext());
                          },
                        )
                      : churchState is! ChurchContextLoaded ||
                            _isLoadingDropdowns
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        )
                      : _meetings.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.event_busy_outlined,
                          message:
                              'لا توجد اجتماعات متاحة لتسجيل الحضور. أضف اجتماعاً أولاً من صفحة الاجتماعات.',
                        )
                      : AttendanceBody(
                          meetings: _meetings,
                          selectedMeeting: _selectedMeeting,
                          selectedClass: _selectedClass,
                          selectedMeetingClasses: selectedMeetingClasses,
                          currentScopeSessions: _currentScopeSessions,
                          canDeleteSessions: _canDeleteSessions,
                          onMeetingChanged: (val) {
                            setState(() {
                              _selectedMeeting = val;
                              _selectedClass = null;
                              _currentScopeSessions = [];
                              if (_selectedMeeting?.kind ==
                                  MeetingKind.sundaySchool) {
                                _selectedClass = _classesForMeeting(
                                  _selectedMeeting,
                                ).firstOrNull;
                              }
                            });
                            if (val != null) {
                              context.read<AttendanceBloc>().add(
                                LoadAttendanceSessions(
                                  meetingId: val.id,
                                  classId: _selectedClass?.id,
                                ),
                              );
                            }
                          },
                          onClassChanged: (index) {
                            setState(() {
                              _selectedClass = selectedMeetingClasses[index];
                              _currentScopeSessions = [];
                            });
                            context.read<AttendanceBloc>().add(
                              LoadAttendanceSessions(
                                meetingId: _selectedMeeting!.id,
                                classId: selectedMeetingClasses[index].id,
                              ),
                            );
                          },
                          onSessionsUpdated: (sessions) {
                            setState(() => _currentScopeSessions = sessions);
                          },
                          onCreateSession: _createSessionForPickedDate,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createSessionForPickedDate(
    BuildContext blocContext, {
    required String meetingId,
    String? classId,
    int? meetingWeekday,
  }) async {
    final repo = context.read<DatabaseRepository>();
    final attendanceBloc = blocContext.read<AttendanceBloc>();
    final picked = await pickAttendanceDate(
      context,
      meetingWeekday: meetingWeekday,
      existingSessions: _currentScopeSessions,
    );

    if (picked == null || !mounted) return;

    try {
      final result = await repo.createWeeklySession(
        meetingId: meetingId,
        classId: classId,
        sessionDate: picked,
        weekNumber: _weekNumber(DateTime(picked.year, 1, 1), picked),
        title: sessionTitle(picked),
      );
      final session = result.data;

      if (!mounted) return;
      setState(() {
        _currentScopeSessions = [
          session,
          ..._currentScopeSessions.where((item) => item.id != session.id),
        ];
      });
      if (!result.syncedToServer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ محلياً وسيتم المزامنة عند عودة الاتصال'),
          ),
        );
      }
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: attendanceBloc,
              child: AttendanceRecordingScreen(session: session),
            ),
          ),
        ).then((_) {
          if (!mounted) return;
          attendanceBloc.add(
            LoadAttendanceSessions(meetingId: meetingId, classId: classId),
          );
        }),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل إنشاء السجل: ${e.toString()}',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  int _weekNumber(DateTime startsOn, DateTime sessionDate) {
    final start = DateTime(startsOn.year, startsOn.month, startsOn.day);
    final date = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    final days = date.difference(start).inDays;
    return days < 0 ? 1 : (days ~/ 7) + 1;
  }
}
