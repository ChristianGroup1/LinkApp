import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class ReportsEvent {}

class LoadReportsData extends ReportsEvent {
  LoadReportsData();
}

// STATES
abstract class ReportsState {}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final List<Map<String, dynamic>> memberStats; // member_id -> statistics
  final List<Map<String, dynamic>> classStats; // class_id -> statistics
  final List<Map<String, dynamic>> meetingStats; // meeting_id -> statistics
  final List<Map<String, dynamic>> monthlyStats; // month -> statistics
  final List<Map<String, dynamic>>
  consecutiveAbsences; // members with 3+ consecutive absences

  ReportsLoaded({
    required this.memberStats,
    required this.classStats,
    required this.meetingStats,
    required this.monthlyStats,
    required this.consecutiveAbsences,
  });
}

class MemberAttendanceDay {
  final DateTime date;
  final int weekNumber;
  final String? title;
  final String meetingName;
  final String? className;
  final AttendanceStatus status;

  const MemberAttendanceDay({
    required this.date,
    required this.weekNumber,
    required this.title,
    required this.meetingName,
    required this.className,
    required this.status,
  });
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}

// BLOC
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final DatabaseRepository repository;

  ReportsBloc({required this.repository}) : super(ReportsInitial()) {
    on<LoadReportsData>((event, emit) async {
      emit(ReportsLoading());
      try {
        // 1. Fetch report base data in parallel.
        final baseData = await Future.wait([
          repository.getAttendanceReportStats(),
          repository.getAllSundaySchoolClasses(),
          repository.getMeetings(),
          repository.getAllMembers(),
        ]);
        final rawStats = baseData[0] as List<Map<String, dynamic>>;
        final classes = baseData[1] as List<SundaySchoolClassEntity>;
        final meetings = baseData[2] as List<MeetingEntity>;
        final members = baseData[3] as List<MemberEntity>;
        final profile = await repository.getCurrentProfile();
        final isAdmin =
            profile?.role == AppRole.superAdmin ||
            profile?.role == AppRole.churchAdmin;
        final viewClassIds = <String>{};
        final viewMeetingIds = <String>{};
        if (!isAdmin && profile != null) {
          final assignments = await Future.wait([
            repository.getUserClassAssignments(profile.id),
            repository.getUserMeetingAssignments(profile.id),
          ]);
          viewClassIds.addAll(
            assignments[0]
                .where((a) => a['can_view_reports'] as bool? ?? true)
                .map((a) => a['class_id'] as String),
          );
          viewMeetingIds.addAll(
            assignments[1]
                .where((a) => a['can_view_reports'] as bool? ?? true)
                .map((a) => a['meeting_id'] as String),
          );
        }
        final visibleMembers = isAdmin
            ? members
            : members
                  .where(
                    (m) =>
                        viewMeetingIds.contains(m.meetingId) ||
                        viewClassIds.contains(m.sundaySchoolClassId),
                  )
                  .toList();
        final visibleMemberIds = visibleMembers.map((m) => m.id).toSet();
        final visibleClasses = isAdmin
            ? classes
            : classes.where((c) => viewClassIds.contains(c.id)).toList();
        final visibleMeetings = isAdmin
            ? meetings
            : meetings
                  .where(
                    (m) =>
                        viewMeetingIds.contains(m.id) ||
                        classes.any(
                          (c) =>
                              c.meetingId == m.id &&
                              viewClassIds.contains(c.id),
                        ),
                  )
                  .toList();
        final meetingsById = {
          for (final meeting in meetings) meeting.id: meeting,
        };
        final classesById = {for (final cls in classes) cls.id: cls};
        final membersById = {for (final member in members) member.id: member};
        final rawStatsByMemberId = {
          for (final row in rawStats.where(
            (row) => visibleMemberIds.contains(row['member_id'] as String),
          ))
            row['member_id'] as String: row,
        };

        // 3. Process Member Statistics
        final memberStats = <Map<String, dynamic>>[];
        final attendanceDaysByMemberId = <String, List<MemberAttendanceDay>>{};
        for (var row in rawStats.where(
          (row) => visibleMemberIds.contains(row['member_id'] as String),
        )) {
          final memberId = row['member_id'] as String;
          final m = membersById[memberId];
          if (m != null) {
            memberStats.add({
              'member': m,
              'recordedWeeks': row['recorded_weeks'] as int,
              'presentWeeks': row['present_weeks'] as int,
              'absentWeeks': row['absent_weeks'] as int,
              'excusedWeeks': row['excused_weeks'] as int,
              'percentage': (row['attendance_percentage'] as num).toDouble(),
            });
          }
        }

        // 4. Process Class-level Statistics
        final classStats = <Map<String, dynamic>>[];
        for (var cls in visibleClasses) {
          final classMembers = visibleMembers
              .where((m) => m.sundaySchoolClassId == cls.id)
              .toList();
          if (classMembers.isNotEmpty) {
            double totalPercentage = 0;
            int count = 0;
            for (var m in classMembers) {
              final mStat = rawStatsByMemberId[m.id];
              if (mStat != null) {
                totalPercentage += (mStat['attendance_percentage'] as num)
                    .toDouble();
                count++;
              }
            }
            classStats.add({
              'id': cls.id,
              'name': cls.nameAr,
              'membersCount': classMembers.length,
              'percentage': count == 0
                  ? 0.0
                  : double.parse((totalPercentage / count).toStringAsFixed(2)),
            });
          }
        }

        // 5. Process Meeting-level Statistics
        final meetingStats = <Map<String, dynamic>>[];
        for (var mtg in visibleMeetings) {
          if (mtg.kind == MeetingKind.sundaySchool) {
            final classIds = visibleClasses
                .where((c) => c.meetingId == mtg.id)
                .map((c) => c.id)
                .toSet();
            final groupedMeetingMembers = visibleMembers
                .where((m) => classIds.contains(m.sundaySchoolClassId))
                .toList();
            if (groupedMeetingMembers.isNotEmpty) {
              double totalPercentage = 0;
              int count = 0;
              for (var m in groupedMeetingMembers) {
                final mStat = rawStatsByMemberId[m.id];
                if (mStat != null) {
                  totalPercentage += (mStat['attendance_percentage'] as num)
                      .toDouble();
                  count++;
                }
              }
              meetingStats.add({
                'id': mtg.id,
                'name': mtg.nameAr,
                'kind': mtg.kind,
                'membersCount': groupedMeetingMembers.length,
                'percentage': count == 0
                    ? 0.0
                    : double.parse(
                        (totalPercentage / count).toStringAsFixed(2),
                      ),
              });
            }
          } else {
            // General meeting
            final mtgMembers = visibleMembers
                .where((m) => m.meetingId == mtg.id)
                .toList();
            if (mtgMembers.isNotEmpty) {
              double totalPercentage = 0;
              int count = 0;
              for (var m in mtgMembers) {
                final mStat = rawStatsByMemberId[m.id];
                if (mStat != null) {
                  totalPercentage += (mStat['attendance_percentage'] as num)
                      .toDouble();
                  count++;
                }
              }
              meetingStats.add({
                'id': mtg.id,
                'name': mtg.nameAr,
                'kind': mtg.kind,
                'membersCount': mtgMembers.length,
                'percentage': count == 0
                    ? 0.0
                    : double.parse(
                        (totalPercentage / count).toStringAsFixed(2),
                      ),
              });
            }
          }
        }

        // 6. Monthly Comparison Stats
        // Aggregate attendance in bulk by fetching all available sessions.
        // We'll calculate present vs total counts grouped by month name (in Arabic)
        final monthlyStats = <Map<String, dynamic>>[];
        final monthNamesAr = [
          'يناير',
          'فبراير',
          'مارس',
          'أبريل',
          'مايو',
          'يونيو',
          'يوليو',
          'أغسطس',
          'سبتمبر',
          'أكتوبر',
          'نوفمبر',
          'ديسمبر',
        ];

        final scopes = <_ReportScope>[];
        for (final mtg in visibleMeetings) {
          if (mtg.kind == MeetingKind.sundaySchool) {
            for (final cls in visibleClasses.where(
              (cls) => cls.meetingId == mtg.id,
            )) {
              scopes.add(_ReportScope(meeting: mtg, classEntity: cls));
            }
          } else {
            scopes.add(_ReportScope(meeting: mtg));
          }
        }

        final sessionResults = await Future.wait(
          scopes.map((scope) async {
            try {
              final sessions = await repository.getSessions(
                scope.meeting.id,
                classId: scope.classEntity?.id,
              );
              return MapEntry(scope.key, sessions);
            } catch (_) {
              return MapEntry(scope.key, <AttendanceSessionEntity>[]);
            }
          }),
        );
        final sessionsByScope = {
          for (final entry in sessionResults) entry.key: entry.value,
        };
        final sessionsList = sessionsByScope.values
            .expand((sessions) => sessions)
            .toList();
        final recordResults = await Future.wait(
          sessionsList.map((session) async {
            try {
              final records = await repository.getAttendanceRecords(session.id);
              return MapEntry(session.id, records);
            } catch (_) {
              return MapEntry(session.id, <AttendanceRecordEntity>[]);
            }
          }),
        );
        final recordsBySessionId = {
          for (final entry in recordResults) entry.key: entry.value,
        };

        for (var session in sessionsList) {
          final records = recordsBySessionId[session.id] ?? [];
          final meetingName =
              meetingsById[session.meetingId]?.nameAr ?? 'اجتماع غير محدد';
          final className = session.classId == null
              ? null
              : classesById[session.classId]?.nameAr;

          for (var record in records) {
            attendanceDaysByMemberId
                .putIfAbsent(record.memberId, () => [])
                .add(
                  MemberAttendanceDay(
                    date: session.sessionDate,
                    weekNumber: session.weekNumber,
                    title: session.title,
                    meetingName: meetingName,
                    className: className,
                    status: record.status,
                  ),
                );
          }
        }

        for (final days in attendanceDaysByMemberId.values) {
          days.sort((a, b) => b.date.compareTo(a.date));
        }

        for (final row in memberStats) {
          final member = row['member'] as MemberEntity;
          final days = attendanceDaysByMemberId[member.id] ?? [];
          row['days'] = days;
          if (days.isNotEmpty) {
            _applyDaysToMemberStatsRow(row, days);
          }
        }

        for (final member in visibleMembers) {
          final days = attendanceDaysByMemberId[member.id] ?? [];
          if (days.isEmpty) continue;
          final alreadyListed = memberStats.any(
            (row) => (row['member'] as MemberEntity).id == member.id,
          );
          if (alreadyListed) continue;
          memberStats.add(_memberStatsRowFromDays(member, days));
        }

        final monthlyGroups = <int, List<AttendanceSessionEntity>>{};
        for (var session in sessionsList) {
          final month = session.sessionDate.month;
          monthlyGroups.putIfAbsent(month, () => []).add(session);
        }

        for (var entry in monthlyGroups.entries) {
          final monthIndex = entry.key - 1;
          int presentCount = 0;
          int totalCount = 0;

          for (var s in entry.value) {
            final records = recordsBySessionId[s.id] ?? [];
            for (var r in records) {
              if (r.status == AttendanceStatus.present) {
                presentCount++;
              }
              totalCount++;
            }
          }

          monthlyStats.add({
            'month': monthNamesAr[monthIndex],
            'monthNum': entry.key,
            'presentCount': presentCount,
            'totalCount': totalCount,
            'percentage': totalCount == 0
                ? 0.0
                : double.parse(
                    ((presentCount / totalCount) * 100).toStringAsFixed(1),
                  ),
          });
        }

        monthlyStats.sort(
          (a, b) => (a['monthNum'] as int).compareTo(b['monthNum'] as int),
        );

        // 7. Calculate Consecutive Absences (3 or more)
        final consecutiveAbsences = <Map<String, dynamic>>[];

        for (final scope in scopes) {
          final recentSessions = (sessionsByScope[scope.key] ?? [])
              .take(3)
              .toList();
          if (recentSessions.length < 3) continue;

          final session1 = recordsBySessionId[recentSessions[0].id] ?? [];
          final session2 = recordsBySessionId[recentSessions[1].id] ?? [];
          final session3 = recordsBySessionId[recentSessions[2].id] ?? [];
          final scopedMembers = scope.classEntity == null
              ? visibleMembers.where((m) => m.meetingId == scope.meeting.id)
              : visibleMembers.where(
                  (m) => m.sundaySchoolClassId == scope.classEntity!.id,
                );

          for (final member in scopedMembers) {
            final s1 = session1
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;
            final s2 = session2
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;
            final s3 = session3
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;

            if (s1 == AttendanceStatus.absent &&
                s2 == AttendanceStatus.absent &&
                s3 == AttendanceStatus.absent) {
              consecutiveAbsences.add({
                'member': member,
                'className': scope.classEntity?.nameAr ?? scope.meeting.nameAr,
                'consecutiveCount': 3,
              });
            }
          }
        }

        emit(
          ReportsLoaded(
            memberStats: memberStats,
            classStats: classStats,
            meetingStats: meetingStats,
            monthlyStats: monthlyStats,
            consecutiveAbsences: consecutiveAbsences,
          ),
        );
      } catch (e) {
        emit(ReportsError('فشل تحميل التقارير: ${e.toString()}'));
      }
    });
  }
}

class _ReportScope {
  final MeetingEntity meeting;
  final SundaySchoolClassEntity? classEntity;

  const _ReportScope({required this.meeting, this.classEntity});

  String get key => '${meeting.id}:${classEntity?.id ?? 'meeting'}';
}

void _applyDaysToMemberStatsRow(
  Map<String, dynamic> row,
  List<MemberAttendanceDay> days,
) {
  final presentWeeks = days
      .where((day) => day.status == AttendanceStatus.present)
      .length;
  final absentWeeks = days
      .where((day) => day.status == AttendanceStatus.absent)
      .length;
  final excusedWeeks = days
      .where((day) => day.status == AttendanceStatus.excused)
      .length;
  final recordedWeeks = days.length;

  row['recordedWeeks'] = recordedWeeks;
  row['presentWeeks'] = presentWeeks;
  row['absentWeeks'] = absentWeeks;
  row['excusedWeeks'] = excusedWeeks;
  row['percentage'] = recordedWeeks == 0
      ? 0.0
      : double.parse(((presentWeeks / recordedWeeks) * 100).toStringAsFixed(1));
}

Map<String, dynamic> _memberStatsRowFromDays(
  MemberEntity member,
  List<MemberAttendanceDay> days,
) {
  final row = <String, dynamic>{
    'member': member,
    'days': days,
    'recordedWeeks': 0,
    'presentWeeks': 0,
    'absentWeeks': 0,
    'excusedWeeks': 0,
    'percentage': 0.0,
  };
  _applyDaysToMemberStatsRow(row, days);
  return row;
}
