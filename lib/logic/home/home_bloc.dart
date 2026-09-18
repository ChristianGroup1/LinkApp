import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/errors/arabic_error_text.dart';
import '../../data/models/models.dart';
import '../../data/repositories/database_repository.dart';

// EVENTS
abstract class HomeEvent {}

class LoadHomeData extends HomeEvent {}

// STATES
abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class BirthdayReminder {
  final MemberEntity member;
  final DateTime nextBirthday;
  final int daysUntil;
  final int turningAge;

  const BirthdayReminder({
    required this.member,
    required this.nextBirthday,
    required this.daysUntil,
    required this.turningAge,
  });
}

class HomeLoaded extends HomeState {
  final int meetingsTodayCount;
  final int absentCount;
  final int presentCount;
  final int totalMembersCount;
  final List<Map<String, dynamic>> repeatedAbsences;
  final List<Map<String, dynamic>> upcomingMeetings;
  final List<BirthdayReminder> upcomingBirthdays;
  final bool canTakeAttendance;
  final bool canViewReports;
  final bool canManageServants;

  /// Admins and attendance officers can add/edit/delete members.
  final bool canManageMembers;

  HomeLoaded({
    required this.meetingsTodayCount,
    required this.absentCount,
    required this.presentCount,
    required this.totalMembersCount,
    required this.repeatedAbsences,
    required this.upcomingMeetings,
    required this.upcomingBirthdays,
    required this.canTakeAttendance,
    required this.canViewReports,
    required this.canManageServants,
    required this.canManageMembers,
  });
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}

// BLOC
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DatabaseRepository repository;

  HomeBloc({required this.repository}) : super(HomeInitial()) {
    on<LoadHomeData>((event, emit) async {
      if (state is! HomeLoaded) {
        emit(HomeLoading());
      }
      try {
        // 1. Get current profile to check church ID.
        final profile = await repository.getCurrentProfile();
        if (profile?.churchId == null) {
          emit(HomeError('المستخدم غير مرتبط بكنيسة.'));
          return;
        }

        // 2. Fetch base dashboard data in parallel.
        final baseData = await Future.wait([
          repository.getAllMembers(),
          repository.getMeetings(),
          repository.getAllSundaySchoolClasses(),
        ]);
        final allMembers = baseData[0] as List<MemberEntity>;
        final allMeetings = baseData[1] as List<MeetingEntity>;
        final allClasses = baseData[2] as List<SundaySchoolClassEntity>;
        final isAdmin =
            profile!.role == AppRole.superAdmin ||
            profile.role == AppRole.churchAdmin;
        final viewClassIds = <String>{};
        final viewMeetingIds = <String>{};
        final takeClassIds = <String>{};
        final takeMeetingIds = <String>{};
        if (!isAdmin) {
          final assignments = await Future.wait([
            repository.getUserClassAssignments(profile.id),
            repository.getUserMeetingAssignments(profile.id),
          ]);
          final classAssignments = assignments[0];
          final meetingAssignments = assignments[1];
          viewClassIds.addAll(
            classAssignments
                .where((a) => a['can_view_reports'] as bool? ?? true)
                .map((a) => a['class_id'] as String),
          );
          viewMeetingIds.addAll(
            meetingAssignments
                .where((a) => a['can_view_reports'] as bool? ?? true)
                .map((a) => a['meeting_id'] as String),
          );
          takeClassIds.addAll(
            classAssignments
                .where((a) => a['can_take_attendance'] as bool? ?? true)
                .map((a) => a['class_id'] as String),
          );
          takeMeetingIds.addAll(
            meetingAssignments
                .where((a) => a['can_take_attendance'] as bool? ?? true)
                .map((a) => a['meeting_id'] as String),
          );
        }
        final canTakeAttendance =
            isAdmin || takeClassIds.isNotEmpty || takeMeetingIds.isNotEmpty;
        final canViewReports =
            isAdmin || viewClassIds.isNotEmpty || viewMeetingIds.isNotEmpty;
        final visibleMembers = allMembers
            .where(
              (member) =>
                  member.isActive &&
                  (isAdmin ||
                      viewMeetingIds.contains(member.meetingId) ||
                      viewClassIds.contains(member.sundaySchoolClassId) ||
                      takeMeetingIds.contains(member.meetingId) ||
                      takeClassIds.contains(member.sundaySchoolClassId)),
            )
            .toList();

        // 3. Today's stats
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayWeekday = today.weekday; // Monday = 1, Sunday = 7
        final upcomingBirthdays = findUpcomingBirthdays(visibleMembers, today);
        // In our DB weekday constraint, Monday = 1 ... Sunday = 7
        final meetingsToday = allMeetings
            .where(
              (m) =>
                  m.weekday == todayWeekday &&
                  m.isActive &&
                  (isAdmin ||
                      viewMeetingIds.contains(m.id) ||
                      allClasses.any(
                        (c) =>
                            c.meetingId == m.id && viewClassIds.contains(c.id),
                      )),
            )
            .toList();

        final scopes = <_AttendanceScope>[];
        for (final mtg in allMeetings.where((meeting) => meeting.isActive)) {
          if (mtg.kind == MeetingKind.sundaySchool) {
            final meetingClasses = allClasses
                .where(
                  (cls) =>
                      cls.isActive &&
                      cls.meetingId == mtg.id &&
                      (isAdmin || viewClassIds.contains(cls.id)),
                )
                .toList();
            for (final cls in meetingClasses) {
              scopes.add(_AttendanceScope(meeting: mtg, classEntity: cls));
            }
          } else if (isAdmin || viewMeetingIds.contains(mtg.id)) {
            scopes.add(_AttendanceScope(meeting: mtg));
          }
        }

        final sessionsByScope = <String, List<AttendanceSessionEntity>>{};
        final sessionsResults = await Future.wait(
          scopes.map((scope) async {
            final sessions = await repository.getSessions(
              scope.meeting.id,
              classId: scope.classEntity?.id,
            );
            return MapEntry(scope.key, sessions.take(2).toList());
          }),
        );
        for (final entry in sessionsResults) {
          sessionsByScope[entry.key] = entry.value;
        }

        final neededSessionIds = sessionsByScope.values
            .expand((sessions) => sessions)
            .map((session) => session.id)
            .toSet()
            .toList();
        final recordsResults = await Future.wait(
          neededSessionIds.map((sessionId) async {
            final records = await repository.getAttendanceRecords(sessionId);
            return MapEntry(sessionId, records);
          }),
        );
        final recordsBySessionId = {
          for (final entry in recordsResults) entry.key: entry.value,
        };

        // 4. Latest attendance stats
        int presentCount = 0;
        int absentCount = 0;
        for (final sessions in sessionsByScope.values) {
          if (sessions.isEmpty) continue;
          final records = recordsBySessionId[sessions.first.id] ?? [];
          for (final record in records) {
            if (record.status == AttendanceStatus.present) {
              presentCount++;
            } else if (record.status == AttendanceStatus.absent) {
              absentCount++;
            }
          }
        }

        // 5. Calculate repeated/consecutive absences from cached recent records.
        final repeatedAbsences = <Map<String, dynamic>>[];
        for (final scope in scopes) {
          final sessions = sessionsByScope[scope.key] ?? [];
          if (sessions.length < 2) continue;

          final session1Records = recordsBySessionId[sessions[0].id] ?? [];
          final session2Records = recordsBySessionId[sessions[1].id] ?? [];
          final scopedMembers = scope.classEntity == null
              ? allMembers.where((m) => m.meetingId == scope.meeting.id)
              : allMembers.where(
                  (m) => m.sundaySchoolClassId == scope.classEntity!.id,
                );

          for (final member in scopedMembers) {
            final status1 = session1Records
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;
            final status2 = session2Records
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;

            if (status1 == AttendanceStatus.absent &&
                status2 == AttendanceStatus.absent) {
              repeatedAbsences.add({
                'member': member,
                'className': scope.classEntity?.nameAr ?? scope.meeting.nameAr,
                'consecutiveCount': 2,
              });
            }
          }
        }

        // 6. Upcoming meetings (scheduled for the week)
        final upcomingMeetings =
            allMeetings
                .where((mtg) {
                  return mtg.isActive &&
                      (isAdmin ||
                          viewMeetingIds.contains(mtg.id) ||
                          allClasses.any(
                            (c) =>
                                c.meetingId == mtg.id &&
                                viewClassIds.contains(c.id),
                          ));
                })
                .map((mtg) {
                  final weekdayDiff = mtg.weekday - todayWeekday;
                  final targetDate = today.add(
                    Duration(
                      days: weekdayDiff < 0 ? weekdayDiff + 7 : weekdayDiff,
                    ),
                  );
                  return {
                    'id': mtg.id,
                    'nameAr': mtg.nameAr,
                    'date': targetDate,
                    'weekday': mtg.weekday,
                  };
                })
                .toList()
              ..sort(
                (a, b) =>
                    (a['date'] as DateTime).compareTo(b['date'] as DateTime),
              );

        emit(
          HomeLoaded(
            meetingsTodayCount: meetingsToday.length,
            absentCount: absentCount,
            presentCount: presentCount,
            totalMembersCount: isAdmin
                ? allMembers.length
                : allMembers
                      .where(
                        (member) =>
                            viewMeetingIds.contains(member.meetingId) ||
                            viewClassIds.contains(member.sundaySchoolClassId),
                      )
                      .length,
            repeatedAbsences: repeatedAbsences,
            upcomingMeetings: upcomingMeetings,
            upcomingBirthdays: upcomingBirthdays,
            canTakeAttendance: canTakeAttendance,
            canViewReports: canViewReports,
            canManageServants: isAdmin,
            canManageMembers: canTakeAttendance,
          ),
        );

        // Warm report-stats cache for offline viewing later.
        unawaited(repository.getAttendanceReportStats());
        unawaited(repository.warmOfflineCache());
      } catch (e) {
        emit(
          HomeError('حدث خطأ أثناء تحميل لوحة البيانات: ${arabicErrorText(e)}'),
        );
      }
    }, transformer: restartable());
  }
}

List<BirthdayReminder> findUpcomingBirthdays(
  List<MemberEntity> members,
  DateTime today, {
  int withinDays = 30,
}) {
  final reminders = <BirthdayReminder>[];
  for (final member in members) {
    final birthDate = member.birthDate;
    if (birthDate == null) continue;

    var nextBirthday = _birthdayInYear(birthDate, today.year);
    if (nextBirthday.isBefore(today)) {
      nextBirthday = _birthdayInYear(birthDate, today.year + 1);
    }

    final daysUntil = nextBirthday.difference(today).inDays;
    if (daysUntil > withinDays) continue;

    reminders.add(
      BirthdayReminder(
        member: member,
        nextBirthday: nextBirthday,
        daysUntil: daysUntil,
        turningAge: nextBirthday.year - birthDate.year,
      ),
    );
  }

  reminders.sort((a, b) {
    final byDate = a.nextBirthday.compareTo(b.nextBirthday);
    return byDate != 0
        ? byDate
        : a.member.fullName.compareTo(b.member.fullName);
  });
  return reminders;
}

DateTime _birthdayInYear(DateTime birthDate, int year) {
  if (birthDate.month == DateTime.february &&
      birthDate.day == 29 &&
      !_isLeapYear(year)) {
    return DateTime(year, DateTime.february, 28);
  }
  return DateTime(year, birthDate.month, birthDate.day);
}

bool _isLeapYear(int year) =>
    year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);

class _AttendanceScope {
  final MeetingEntity meeting;
  final SundaySchoolClassEntity? classEntity;

  const _AttendanceScope({required this.meeting, this.classEntity});

  String get key => '${meeting.id}:${classEntity?.id ?? 'meeting'}';
}
