import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/arabic_error_text.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class FollowUpEvent {}

class LoadFollowUpData extends FollowUpEvent {
  final String? flashMessage;

  LoadFollowUpData({this.flashMessage});
}

class CreateFollowUpNote extends FollowUpEvent {
  final String memberId;
  final String? sessionId;
  final String? reason;
  final String contactStatus; // FollowUpContactStatus values
  final String? result;
  final String? responsibleUserId;
  final DateTime followUpDate;

  CreateFollowUpNote({
    required this.memberId,
    this.sessionId,
    this.reason,
    required this.contactStatus,
    this.result,
    this.responsibleUserId,
    required this.followUpDate,
  });
}

class ClearFollowUpFlashMessage extends FollowUpEvent {}

// STATES
abstract class FollowUpState {}

class FollowUpInitial extends FollowUpState {}

class FollowUpLoading extends FollowUpState {}

class FollowUpDataLoaded extends FollowUpState {
  final List<Map<String, dynamic>>
  urgentAbsences; // latest absent members, including single absence
  final List<FollowUpEntity> followUpHistory;
  final List<AppProfile> servants;
  final List<MemberEntity> members;
  final String? flashMessage;

  FollowUpDataLoaded({
    required this.urgentAbsences,
    required this.followUpHistory,
    required this.servants,
    required this.members,
    this.flashMessage,
  });

  FollowUpDataLoaded copyWith({
    List<Map<String, dynamic>>? urgentAbsences,
    List<FollowUpEntity>? followUpHistory,
    List<AppProfile>? servants,
    List<MemberEntity>? members,
    String? flashMessage,
    bool clearFlashMessage = false,
  }) {
    return FollowUpDataLoaded(
      urgentAbsences: urgentAbsences ?? this.urgentAbsences,
      followUpHistory: followUpHistory ?? this.followUpHistory,
      servants: servants ?? this.servants,
      members: members ?? this.members,
      flashMessage: clearFlashMessage
          ? null
          : (flashMessage ?? this.flashMessage),
    );
  }
}

class FollowUpError extends FollowUpState {
  final String message;
  FollowUpError(this.message);
}

// BLOC
class FollowUpBloc extends Bloc<FollowUpEvent, FollowUpState> {
  final DatabaseRepository repository;
  StreamSubscription<List<FollowUpEntity>>? _followUpsSubscription;

  FollowUpBloc({required this.repository}) : super(FollowUpInitial()) {
    on<LoadFollowUpData>((event, emit) async {
      if (state is! FollowUpDataLoaded) {
        emit(FollowUpLoading());
      }
      try {
        final baseData = await Future.wait([
          repository.getAllMembers(),
          repository.getAllSundaySchoolClasses(),
          repository.getMeetings(),
          repository.getAllFollowUps(),
          repository.getProfiles(),
        ]);
        final members = baseData[0] as List<MemberEntity>;
        final classes = baseData[1] as List<SundaySchoolClassEntity>;
        final meetings = baseData[2] as List<MeetingEntity>;
        final history = baseData[3] as List<FollowUpEntity>;
        final servants = baseData[4] as List<AppProfile>;
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

        // Calculate latest absences. A member can be followed up after one absence.
        final urgentAbsences = <Map<String, dynamic>>[];

        final scopes = <_FollowUpScope>[];
        for (final mtg in meetings.where((meeting) => meeting.isActive)) {
          if (mtg.kind == MeetingKind.sundaySchool) {
            for (final cls in classes.where(
              (cls) =>
                  cls.isActive &&
                  cls.meetingId == mtg.id &&
                  (isAdmin || viewClassIds.contains(cls.id)),
            )) {
              scopes.add(_FollowUpScope(meeting: mtg, classEntity: cls));
            }
          } else if (isAdmin || viewMeetingIds.contains(mtg.id)) {
            scopes.add(_FollowUpScope(meeting: mtg));
          }
        }

        final sessionsResults = await Future.wait(
          scopes.map((scope) async {
            final sessions = await repository.getSessions(
              scope.meeting.id,
              classId: scope.classEntity?.id,
            );
            return MapEntry(scope.key, sessions.take(3).toList());
          }),
        );
        final sessionsByScope = {
          for (final entry in sessionsResults) entry.key: entry.value,
        };

        final sessionIds = sessionsByScope.values
            .expand((sessions) => sessions)
            .map((session) => session.id)
            .toSet()
            .toList();
        final recordsResults = await Future.wait(
          sessionIds.map((sessionId) async {
            final records = await repository.getAttendanceRecords(sessionId);
            return MapEntry(sessionId, records);
          }),
        );
        final recordsBySessionId = {
          for (final entry in recordsResults) entry.key: entry.value,
        };

        for (final scope in scopes) {
          final sessions = sessionsByScope[scope.key] ?? [];
          if (sessions.isEmpty) continue;

          final session1 = recordsBySessionId[sessions[0].id] ?? [];
          final session2 = sessions.length >= 2
              ? recordsBySessionId[sessions[1].id]
              : null;
          final session3 = sessions.length >= 3
              ? recordsBySessionId[sessions[2].id]
              : null;
          final scopedMembers = scope.classEntity == null
              ? members.where((m) => m.meetingId == scope.meeting.id)
              : members.where(
                  (m) => m.sundaySchoolClassId == scope.classEntity!.id,
                );

          for (final member in scopedMembers) {
            final s1 = session1
                .where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;
            final s2 = session2
                ?.where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;
            final s3 = session3
                ?.where((record) => record.memberId == member.id)
                .map((record) => record.status)
                .firstOrNull;

            if (s1 == AttendanceStatus.absent) {
              var consecutiveCount = 1;
              if (s2 == AttendanceStatus.absent) {
                consecutiveCount++;
              }
              if (s2 == AttendanceStatus.absent &&
                  s3 == AttendanceStatus.absent) {
                consecutiveCount++;
              }
              urgentAbsences.add({
                'member': member,
                'className': scope.classEntity?.nameAr ?? scope.meeting.nameAr,
                'consecutiveCount': consecutiveCount,
                'latestSessionId': sessions[0].id,
              });
            }
          }
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

        emit(
          FollowUpDataLoaded(
            urgentAbsences: urgentAbsences,
            followUpHistory: isAdmin
                ? history
                : history
                      .where((item) => visibleMemberIds.contains(item.memberId))
                      .toList(),
            servants: servants,
            members: visibleMembers,
            flashMessage: event.flashMessage,
          ),
        );
        _ensureRealtimeSubscription();
      } catch (e) {
        emit(FollowUpError('فشل تحميل بيانات المتابعة: ${arabicErrorText(e)}'));
      }
    });

    on<CreateFollowUpNote>((event, emit) async {
      final previous = state;
      try {
        final synced = await repository.addFollowUp(
          memberId: event.memberId,
          sessionId: event.sessionId,
          reason: event.reason,
          contactStatus: event.contactStatus,
          result: event.result,
          responsibleUserId: event.responsibleUserId,
          followUpDate: event.followUpDate,
        );
        add(
          LoadFollowUpData(flashMessage: synced ? null : kOfflineSavedMessage),
        );
      } catch (e) {
        if (previous is FollowUpDataLoaded) {
          emit(
            previous.copyWith(
              flashMessage: 'فشل إضافة تقرير المتابعة: ${arabicErrorText(e)}',
            ),
          );
        } else {
          emit(
            FollowUpError('فشل إضافة تقرير المتابعة: ${arabicErrorText(e)}'),
          );
        }
      }
    });

    on<ClearFollowUpFlashMessage>((event, emit) {
      final current = state;
      if (current is FollowUpDataLoaded && current.flashMessage != null) {
        emit(current.copyWith(clearFlashMessage: true));
      }
    });
  }

  void _ensureRealtimeSubscription() {
    _followUpsSubscription ??= repository.subscribeToFollowUps().listen((_) {
      add(LoadFollowUpData());
    });
  }

  @override
  Future<void> close() {
    unawaited(_followUpsSubscription?.cancel());
    return super.close();
  }
}

class _FollowUpScope {
  final MeetingEntity meeting;
  final SundaySchoolClassEntity? classEntity;

  const _FollowUpScope({required this.meeting, this.classEntity});

  String get key => '${meeting.id}:${classEntity?.id ?? 'meeting'}';
}
