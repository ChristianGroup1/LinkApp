import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../data/models/models.dart';
import '../../data/repositories/database_repository.dart';

class MeetingReminderService {
  static final MeetingReminderService instance = MeetingReminderService._();

  static const _storedNotificationIdsKey =
      'scheduled_meeting_reminder_notification_ids';
  static const _channelId = 'attendance_reminders';
  static const _channelName = 'تذكيرات الحضور والغياب';
  static const _channelDescription =
      'تذكير أسبوعي بموعد تسجيل حضور وغياب الاجتماع';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsRequested = false;

  MeetingReminderService._();

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) return;

    timezone_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(
        timezone.getLocation(deviceTimezone.identifier),
      );
    } catch (error) {
      debugPrint(
        '[MeetingReminderService] Could not resolve device timezone: $error',
      );
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<void> syncForCurrentUser(DatabaseRepository repository) async {
    if (!_isSupportedPlatform) return;

    try {
      await initialize();
      await _requestPermissionsOnce();

      final profile = await repository.getCurrentProfile();
      if (profile?.churchId == null || !profile!.isActive) {
        await _replaceScheduledMeetings(const []);
        return;
      }

      final results = await Future.wait([
        repository.getMeetings(),
        repository.getAllSundaySchoolClasses(),
      ]);
      final meetings = results[0] as List<MeetingEntity>;
      final classes = results[1] as List<SundaySchoolClassEntity>;
      final isAdmin =
          profile.role == AppRole.superAdmin ||
          profile.role == AppRole.churchAdmin;

      Set<String> visibleMeetingIds;
      if (isAdmin) {
        visibleMeetingIds = meetings.map((meeting) => meeting.id).toSet();
      } else {
        final assignmentResults = await Future.wait([
          repository.getUserClassAssignments(profile.id),
          repository.getUserMeetingAssignments(profile.id),
        ]);
        final classIds = assignmentResults[0]
            .where(
              (assignment) =>
                  assignment['can_take_attendance'] as bool? ?? true,
            )
            .map((assignment) => assignment['class_id'] as String)
            .toSet();
        visibleMeetingIds = assignmentResults[1]
            .where(
              (assignment) =>
                  assignment['can_take_attendance'] as bool? ?? true,
            )
            .map((assignment) => assignment['meeting_id'] as String)
            .toSet();
        visibleMeetingIds.addAll(
          classes
              .where((item) => classIds.contains(item.id))
              .map((item) => item.meetingId),
        );
      }

      final scheduledMeetings = meetings
          .where(
            (meeting) =>
                meeting.isActive &&
                meeting.attendanceReminderMinutes != null &&
                visibleMeetingIds.contains(meeting.id),
          )
          .toList();
      await _replaceScheduledMeetings(scheduledMeetings);
    } catch (error, stackTrace) {
      debugPrint('[MeetingReminderService] Reminder sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestPermissionsOnce() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _replaceScheduledMeetings(List<MeetingEntity> meetings) async {
    final preferences = await SharedPreferences.getInstance();
    final previousIds =
        preferences.getStringList(_storedNotificationIdsKey) ?? const [];
    for (final value in previousIds) {
      final notificationId = int.tryParse(value);
      if (notificationId != null) {
        await _notifications.cancel(notificationId);
      }
    }

    final scheduledIds = <String>[];
    for (final meeting in meetings) {
      final reminderMinutes = meeting.attendanceReminderMinutes;
      if (reminderMinutes == null) continue;

      final notificationId = _notificationIdForMeeting(meeting.id);
      await _notifications.zonedSchedule(
        notificationId,
        'تذكير تسجيل الحضور',
        'حان موعد تسجيل الحضور والغياب لاجتماع ${meeting.nameAr}',
        _nextWeeklyOccurrence(
          weekday: meeting.weekday,
          minutesAfterMidnight: reminderMinutes,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            color: AppThemeNotificationColor.primary,
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: _channelId,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'meeting:${meeting.id}',
      );
      scheduledIds.add('$notificationId');
    }

    await preferences.setStringList(_storedNotificationIdsKey, scheduledIds);
  }

  timezone.TZDateTime _nextWeeklyOccurrence({
    required int weekday,
    required int minutesAfterMidnight,
  }) {
    final now = timezone.TZDateTime.now(timezone.local);
    final hour = minutesAfterMidnight ~/ 60;
    final minute = minutesAfterMidnight % 60;

    for (var offset = 0; offset <= 7; offset++) {
      final date = now.add(Duration(days: offset));
      if (date.weekday != weekday) continue;
      final candidate = timezone.TZDateTime(
        timezone.local,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      if (candidate.isAfter(now)) return candidate;
    }

    final nextWeek = now.add(const Duration(days: 7));
    return timezone.TZDateTime(
      timezone.local,
      nextWeek.year,
      nextWeek.month,
      nextWeek.day,
      hour,
      minute,
    );
  }

  int _notificationIdForMeeting(String meetingId) {
    var hash = 0x811C9DC5;
    for (final codeUnit in meetingId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}

abstract final class AppThemeNotificationColor {
  static const primary = Color(0xFF4F46E5);
}
