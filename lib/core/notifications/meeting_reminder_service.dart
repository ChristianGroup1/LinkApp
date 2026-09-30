import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../data/models/models.dart';
import '../../data/repositories/database_repository.dart';
import '../../main.dart';
import '../../presentation/screens/main_navigation_wrapper.dart';

enum MeetingReminderDeliveryResult {
  sent,
  permissionDenied,
  unsupported,
  failed,
}

class MeetingReminderService {
  static final MeetingReminderService instance = MeetingReminderService._();

  static const _storedNotificationIdsKey =
      'scheduled_meeting_reminder_notification_ids';
  static const _storedBirthdayNotificationIdsKey =
      'scheduled_birthday_notification_ids';
  static const _channelId = 'attendance_reminders';
  static const _channelName = 'تذكيرات الحضور والغياب';
  static const _channelDescription =
      'تذكير أسبوعي بموعد تسجيل حضور وغياب الاجتماع';
  static const _birthdayChannelId = 'birthday_reminders';
  static const _birthdayChannelName = 'أعياد ميلاد المخدومين';
  static const _birthdayChannelDescription =
      'تذكير الخادم بأعياد ميلاد المخدومين في اجتماعاته وفصوله';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsRequested = false;
  Future<void>? _initialization;
  Future<void>? _syncInFlight;
  bool _syncRequestedAgain = false;

  MeetingReminderService._();

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) return;

    final pendingInitialization = _initialization;
    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }

    final initialization = _initializePlugin();
    _initialization = initialization;
    try {
      await initialization;
      _initialized = true;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initializePlugin() async {
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
      android: AndroidInitializationSettings('ic_notification_logo'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('meeting:')) {
          final navigator = MyApp.navigatorKey.currentState;
          if (navigator != null && navigator.mounted) {
            navigator.popUntil((route) => route.isFirst);
          }
          final state = MainNavigationWrapper.wrapperKey.currentState;
          if (state != null) {
            (state as dynamic).switchToTab(1);
          }
        } else if (payload != null && payload.startsWith('birthday:')) {
          final navigator = MyApp.navigatorKey.currentState;
          if (navigator != null && navigator.mounted) {
            navigator.popUntil((route) => route.isFirst);
          }
          final state = MainNavigationWrapper.wrapperKey.currentState;
          if (state != null) {
            (state as dynamic).switchToTab(2);
          }
        }
      },
    );
  }

  Future<void> syncForCurrentUser(DatabaseRepository repository) async {
    if (!_isSupportedPlatform) return;

    // Startup, app resume, and MeetingsBloc can all request the same refresh.
    // Join an active refresh and run at most one follow-up if data changed
    // while it was in progress, instead of queueing every duplicate request.
    final activeSync = _syncInFlight;
    if (activeSync != null) {
      _syncRequestedAgain = true;
      await activeSync;
      return;
    }

    late final Future<void> sync;
    sync =
        (() async {
          do {
            _syncRequestedAgain = false;
            await _syncForCurrentUser(repository);
          } while (_syncRequestedAgain);
        })().whenComplete(() {
          if (!identical(_syncInFlight, sync)) return;
          _syncInFlight = null;
          if (_syncRequestedAgain) {
            _syncRequestedAgain = false;
            unawaited(syncForCurrentUser(repository));
          }
        });
    _syncInFlight = sync;
    await sync;
  }

  Future<void> _syncForCurrentUser(DatabaseRepository repository) async {
    try {
      await initialize();
      await _requestPermissionsOnce();

      final profile = await repository.getCurrentProfile();
      if (profile?.churchId == null || !profile!.isActive) {
        await _replaceScheduledMeetings(const []);
        await _replaceScheduledBirthdays(const []);
        return;
      }

      final results = await Future.wait([
        repository.getMeetings(),
        repository.getAllSundaySchoolClasses(),
        repository.getAllMembers(),
      ]);
      final meetings = results[0] as List<MeetingEntity>;
      final classes = results[1] as List<SundaySchoolClassEntity>;
      final members = results[2] as List<MemberEntity>;
      final isAdmin =
          profile.role == AppRole.superAdmin ||
          profile.role == AppRole.churchAdmin;

      Set<String> visibleMeetingIds;
      Set<String> visibleClassIds;
      if (isAdmin) {
        visibleMeetingIds = meetings
            .where((meeting) => meeting.isActive)
            .map((meeting) => meeting.id)
            .toSet();
        visibleClassIds = classes
            .where(
              (item) =>
                  item.isActive && visibleMeetingIds.contains(item.meetingId),
            )
            .map((item) => item.id)
            .toSet();
      } else {
        final assignmentResults = await Future.wait([
          repository.getUserClassAssignments(profile.id),
          repository.getUserMeetingAssignments(profile.id),
        ]);
        final assignedClassIds = assignmentResults[0]
            .where(
              (assignment) =>
                  assignment['can_take_attendance'] as bool? ?? true,
            )
            .map((assignment) => assignment['class_id'] as String)
            .toSet();
        visibleClassIds = classes
            .where(
              (item) => item.isActive && assignedClassIds.contains(item.id),
            )
            .map((item) => item.id)
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
              .where((item) => visibleClassIds.contains(item.id))
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
      final birthdayMembers = members.where((member) {
        if (!member.isActive || member.birthDate == null) return false;
        return member.scope == MemberScope.sundaySchoolClass
            ? visibleClassIds.contains(member.sundaySchoolClassId)
            : member.meetingIds.any(visibleMeetingIds.contains);
      }).toList();
      await _replaceScheduledBirthdays(birthdayMembers);
    } catch (error, stackTrace) {
      debugPrint('[MeetingReminderService] Reminder sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _ensureNotificationPermission({
    required bool requestIfNeeded,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;

      final enabled = await android.areNotificationsEnabled() ?? false;
      if (enabled || !requestIfNeeded) return enabled;

      final granted = await android.requestNotificationsPermission();
      if (granted == true) return true;
      return await android.areNotificationsEnabled() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios == null) return false;

      final status = await ios.checkPermissions();
      if (status?.isEnabled == true || !requestIfNeeded) {
        return status?.isEnabled ?? false;
      }
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macOS = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS == null) return false;

      final status = await macOS.checkPermissions();
      if (status?.isEnabled == true || !requestIfNeeded) {
        return status?.isEnabled ?? false;
      }
      return await macOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  Future<void> _requestPermissionsOnce() async {
    if (_permissionsRequested) return;

    final granted = await _ensureNotificationPermission(requestIfNeeded: true);
    debugPrint(
      '[MeetingReminderService] Notification permission granted: $granted',
    );

    _permissionsRequested = true;
  }

  Future<MeetingReminderDeliveryResult> showInstantReminder({
    required String meetingName,
    required String meetingId,
  }) async {
    if (!_isSupportedPlatform) {
      return MeetingReminderDeliveryResult.unsupported;
    }

    try {
      await initialize();
      final permissionGranted = await _ensureNotificationPermission(
        requestIfNeeded: true,
      );
      _permissionsRequested = true;
      if (!permissionGranted) {
        return MeetingReminderDeliveryResult.permissionDenied;
      }

      await _notifications.show(
        _notificationIdForMeeting(meetingId),
        'تذكير تسجيل الحضور 🔔',
        'حان موعد تسجيل الحضور والغياب لاجتماع $meetingName',
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
            interruptionLevel: InterruptionLevel.active,
          ),
          macOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: 'meeting:$meetingId',
      );
      return MeetingReminderDeliveryResult.sent;
    } catch (error, stackTrace) {
      debugPrint(
        '[MeetingReminderService] Could not show instant reminder: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return MeetingReminderDeliveryResult.failed;
    }
  }

  Future<void> _replaceScheduledMeetings(List<MeetingEntity> meetings) async {
    final preferences = await SharedPreferences.getInstance();
    final previousIds =
        preferences.getStringList(_storedNotificationIdsKey) ?? const [];
    final previousIdSet = previousIds.toSet();
    final scheduledIds = <String>{};
    for (final meeting in meetings) {
      final reminderMinutes = meeting.attendanceReminderMinutes;
      if (reminderMinutes == null) continue;

      final notificationId = _notificationIdForMeeting(meeting.id);
      final storedId = '$notificationId';
      try {
        await _notifications.zonedSchedule(
          notificationId,
          'تذكير تسجيل الحضور 🔔',
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
            macOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.active,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'meeting:${meeting.id}',
        );
        scheduledIds.add(storedId);
      } catch (error, stackTrace) {
        // One malformed/stale meeting must not prevent every other reminder.
        debugPrint(
          '[MeetingReminderService] Could not schedule meeting '
          '${meeting.id}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (previousIdSet.contains(storedId)) scheduledIds.add(storedId);
      }
    }

    for (final value in previousIdSet.difference(scheduledIds)) {
      final notificationId = int.tryParse(value);
      if (notificationId != null) await _notifications.cancel(notificationId);
    }

    await preferences.setStringList(
      _storedNotificationIdsKey,
      scheduledIds.toList(growable: false),
    );
    debugPrint(
      '[MeetingReminderService] Scheduled ${scheduledIds.length} reminder(s)',
    );
  }

  Future<void> _replaceScheduledBirthdays(List<MemberEntity> members) async {
    final preferences = await SharedPreferences.getInstance();
    final previousIds =
        preferences.getStringList(_storedBirthdayNotificationIdsKey) ??
        const <String>[];
    final previousIdSet = previousIds.toSet();
    final meetingIds =
        (preferences.getStringList(_storedNotificationIdsKey) ??
                const <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();

    final candidates =
        members
            .where((member) => member.birthDate != null)
            .map(
              (member) => (
                member: member,
                scheduledDate: _nextBirthdayOccurrence(member.birthDate!),
              ),
            )
            .toList()
          ..sort(
            (left, right) => left.scheduledDate.compareTo(right.scheduledDate),
          );

    // iOS keeps a maximum of 64 pending local notifications. Leave room for
    // the existing meeting reminders and schedule the nearest birthdays.
    final availableSlots = defaultTargetPlatform == TargetPlatform.iOS
        ? (64 - meetingIds.length).clamp(0, 64)
        : candidates.length;
    final scheduledIds = <String>{};
    final usedIds = Set<int>.from(meetingIds);
    for (final candidate in candidates.take(availableSlots)) {
      final member = candidate.member;
      var notificationId = _notificationIdForBirthday(member.id);
      while (usedIds.contains(notificationId)) {
        notificationId = notificationId == 0x7FFFFFFF ? 0 : notificationId + 1;
      }
      usedIds.add(notificationId);
      final storedId = '$notificationId';

      try {
        await _notifications.zonedSchedule(
          notificationId,
          'عيد ميلاد سعيد 🎂',
          'النهارده عيد ميلاد ${member.fullName}.',
          candidate.scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _birthdayChannelId,
              _birthdayChannelName,
              channelDescription: _birthdayChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              color: AppThemeNotificationColor.primary,
            ),
            iOS: DarwinNotificationDetails(
              threadIdentifier: _birthdayChannelId,
              interruptionLevel: InterruptionLevel.active,
            ),
            macOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.active,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
          payload: 'birthday:${member.id}',
        );
        scheduledIds.add(storedId);
      } catch (error, stackTrace) {
        debugPrint(
          '[MeetingReminderService] Could not schedule birthday '
          'for ${member.id}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (previousIdSet.contains(storedId)) scheduledIds.add(storedId);
      }
    }

    for (final value in previousIdSet.difference(scheduledIds)) {
      final notificationId = int.tryParse(value);
      if (notificationId != null) await _notifications.cancel(notificationId);
    }

    await preferences.setStringList(
      _storedBirthdayNotificationIdsKey,
      scheduledIds.toList(growable: false),
    );
    debugPrint(
      '[MeetingReminderService] Scheduled ${scheduledIds.length} birthday reminder(s)',
    );
  }

  timezone.TZDateTime _nextBirthdayOccurrence(DateTime birthDate) {
    final now = timezone.TZDateTime.now(timezone.local);
    for (var year = now.year; year <= now.year + 8; year++) {
      final lastDayOfMonth = DateTime(year, birthDate.month + 1, 0).day;
      if (birthDate.day > lastDayOfMonth) continue;
      final candidate = timezone.TZDateTime(
        timezone.local,
        year,
        birthDate.month,
        birthDate.day,
        9,
      );
      if (candidate.isAfter(now)) return candidate;
    }
    throw StateError('Could not calculate the next birthday occurrence');
  }

  int _notificationIdForBirthday(String memberId) {
    var hash = 0x811C9DC5;
    for (final codeUnit in memberId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  timezone.TZDateTime _nextWeeklyOccurrence({
    required int weekday,
    required int minutesAfterMidnight,
  }) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday', 'Must be between 1 and 7');
    }
    if (minutesAfterMidnight < 0 || minutesAfterMidnight >= 24 * 60) {
      throw ArgumentError.value(
        minutesAfterMidnight,
        'minutesAfterMidnight',
        'Must be between 0 and 1439',
      );
    }

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
