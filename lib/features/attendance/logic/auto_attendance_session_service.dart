import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';

class AutoAttendanceSessionService {
  AutoAttendanceSessionService._();
  static final instance = AutoAttendanceSessionService._();

  /// Automatically creates attendance sessions 1 day before (or on the day of) any active meeting.
  Future<void> autoCreateSessionsOneDayInAdvance(DatabaseRepository repo) async {
    try {
      final profile = await repo.getCurrentProfile();
      if (profile == null) return;

      final results = await Future.wait([
        repo.getMeetings(),
        repo.getAllSundaySchoolClasses(),
      ]);

      final allMeetings =
          (results[0] as List<MeetingEntity>).where((m) => m.isActive).toList();
      final allClasses = (results[1] as List<SundaySchoolClassEntity>)
          .where((c) => c.isActive)
          .toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final meeting in allMeetings) {
        int daysUntilMeeting = (meeting.weekday - today.weekday) % 7;
        if (daysUntilMeeting < 0) daysUntilMeeting += 7;
        final targetDate = today.add(Duration(days: daysUntilMeeting));

        // Auto-create if target date is today or 1 day in advance (tomorrow)
        final daysDifference = targetDate.difference(today).inDays;
        if (daysDifference <= 1) {
          if (meeting.kind == MeetingKind.sundaySchool) {
            final classes =
                allClasses.where((c) => c.meetingId == meeting.id).toList();
            for (final cls in classes) {
              final existingSessions =
                  await repo.getSessions(meeting.id, classId: cls.id);
              final hasSession = existingSessions.any(
                (s) =>
                    s.sessionDate.year == targetDate.year &&
                    s.sessionDate.month == targetDate.month &&
                    s.sessionDate.day == targetDate.day,
              );

              if (!hasSession) {
                await repo.createWeeklySession(
                  meetingId: meeting.id,
                  classId: cls.id,
                  sessionDate: targetDate,
                  weekNumber: (targetDate.day / 7).ceil(),
                );
              }
            }
          } else {
            final existingSessions = await repo.getSessions(meeting.id);
            final hasSession = existingSessions.any(
              (s) =>
                  s.sessionDate.year == targetDate.year &&
                  s.sessionDate.month == targetDate.month &&
                  s.sessionDate.day == targetDate.day,
            );

            if (!hasSession) {
              await repo.createWeeklySession(
                meetingId: meeting.id,
                sessionDate: targetDate,
                weekNumber: (targetDate.day / 7).ceil(),
              );
            }
          }
        }
      }
    } catch (_) {
      // Gracefully handle background errors
    }
  }
}
