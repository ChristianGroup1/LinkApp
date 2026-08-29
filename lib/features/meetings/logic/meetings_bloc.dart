import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/notifications/meeting_reminder_service.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class MeetingsEvent {}

class LoadMeetingsAndClasses extends MeetingsEvent {
  final String? flashMessage;

  LoadMeetingsAndClasses({this.flashMessage});
}

class NewMeetingClassDraft {
  final String name;
  final String nameAr;

  const NewMeetingClassDraft({required this.name, required this.nameAr});
}

class CreateNewMeeting extends MeetingsEvent {
  final String name;
  final String nameAr;
  final MeetingKind kind;
  final int weekday;
  final int? attendanceReminderMinutes;
  final String? description;
  final List<NewMeetingClassDraft> classes;
  final Completer<void>? completion;
  CreateNewMeeting({
    required this.name,
    required this.nameAr,
    required this.kind,
    required this.weekday,
    this.attendanceReminderMinutes,
    this.description,
    this.classes = const [],
    this.completion,
  });
}

class UpdateExistingMeeting extends MeetingsEvent {
  final String id;
  final String name;
  final String nameAr;
  final int weekday;
  final bool isActive;
  final int? attendanceReminderMinutes;
  final String? description;
  final Completer<void>? completion;
  UpdateExistingMeeting({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.weekday,
    required this.isActive,
    this.attendanceReminderMinutes,
    this.description,
    this.completion,
  });
}

class DeleteExistingMeeting extends MeetingsEvent {
  final String id;
  DeleteExistingMeeting(this.id);
}

class CreateClass extends MeetingsEvent {
  final String meetingId;
  final String name;
  final String nameAr;
  final int displayOrder;
  CreateClass({
    required this.meetingId,
    required this.name,
    required this.nameAr,
    required this.displayOrder,
  });
}

class UpdateClass extends MeetingsEvent {
  final String id;
  final String name;
  final String nameAr;
  final int displayOrder;
  final bool isActive;
  UpdateClass({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.displayOrder,
    required this.isActive,
  });
}

class DeleteClass extends MeetingsEvent {
  final String id;
  DeleteClass(this.id);
}

class ClearMeetingsFlashMessage extends MeetingsEvent {}

// STATES
abstract class MeetingsState {}

class MeetingsInitial extends MeetingsState {}

class MeetingsLoading extends MeetingsState {}

class MeetingsLoaded extends MeetingsState {
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final Map<String, List<Map<String, dynamic>>> classAssignmentsById;
  final Map<String, List<Map<String, dynamic>>> meetingAssignmentsById;
  final List<HelperInvitation> pendingInvitations;
  final String? flashMessage;

  MeetingsLoaded({
    required this.meetings,
    required this.classes,
    required this.classAssignmentsById,
    required this.meetingAssignmentsById,
    this.pendingInvitations = const [],
    this.flashMessage,
  });

  MeetingsLoaded copyWith({
    List<MeetingEntity>? meetings,
    List<SundaySchoolClassEntity>? classes,
    Map<String, List<Map<String, dynamic>>>? classAssignmentsById,
    Map<String, List<Map<String, dynamic>>>? meetingAssignmentsById,
    List<HelperInvitation>? pendingInvitations,
    String? flashMessage,
    bool clearFlashMessage = false,
  }) {
    return MeetingsLoaded(
      meetings: meetings ?? this.meetings,
      classes: classes ?? this.classes,
      classAssignmentsById: classAssignmentsById ?? this.classAssignmentsById,
      meetingAssignmentsById:
          meetingAssignmentsById ?? this.meetingAssignmentsById,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      flashMessage: clearFlashMessage
          ? null
          : (flashMessage ?? this.flashMessage),
    );
  }
}

class MeetingsError extends MeetingsState {
  final String message;
  MeetingsError(this.message);
}

// BLOC
class MeetingsBloc extends Bloc<MeetingsEvent, MeetingsState> {
  final DatabaseRepository repository;

  MeetingsBloc({required this.repository}) : super(MeetingsInitial()) {
    on<LoadMeetingsAndClasses>((event, emit) async {
      emit(MeetingsLoading());
      try {
        final results = await Future.wait([
          repository.getMeetings(),
          repository.getAllSundaySchoolClasses(),
          repository.getInvitations(),
        ]);
        final meetings = results[0] as List<MeetingEntity>;
        final classes = results[1] as List<SundaySchoolClassEntity>;
        final invitations = results[2] as List<HelperInvitation>;
        final pendingInvitations = invitations
            .where((invite) => invite.isPending)
            .toList();
        final classAssignmentResults = await Future.wait(
          classes.map((cls) async {
            try {
              final assignments = await repository.getClassAssignments(cls.id);
              return MapEntry(cls.id, assignments);
            } catch (_) {
              return MapEntry(cls.id, <Map<String, dynamic>>[]);
            }
          }),
        );
        final meetingAssignmentResults = await Future.wait(
          meetings
              .where((meeting) => meeting.kind != MeetingKind.sundaySchool)
              .map((meeting) async {
                try {
                  final assignments = await repository.getMeetingAssignments(
                    meeting.id,
                  );
                  return MapEntry(meeting.id, assignments);
                } catch (_) {
                  return MapEntry(meeting.id, <Map<String, dynamic>>[]);
                }
              }),
        );
        emit(
          MeetingsLoaded(
            meetings: meetings,
            classes: classes,
            classAssignmentsById: {
              for (final entry in classAssignmentResults)
                entry.key: entry.value,
            },
            meetingAssignmentsById: {
              for (final entry in meetingAssignmentResults)
                entry.key: entry.value,
            },
            pendingInvitations: pendingInvitations,
            flashMessage: event.flashMessage,
          ),
        );
        unawaited(
          MeetingReminderService.instance.syncForCurrentUser(repository),
        );
      } catch (e) {
        emit(MeetingsError('فشل تحميل الاجتماعات: ${e.toString()}'));
      }
    });

    on<CreateNewMeeting>((event, emit) async {
      final previous = state;
      try {
        final meetingResult = await repository.createMeeting(
          name: event.name,
          nameAr: event.nameAr,
          kind: event.kind,
          weekday: event.weekday,
          attendanceReminderMinutes: event.attendanceReminderMinutes,
          description: event.description,
        );
        var synced = meetingResult.syncedToServer;
        for (var i = 0; i < event.classes.length; i++) {
          final cls = event.classes[i];
          final classResult = await repository.createSundaySchoolClass(
            meetingId: meetingResult.data.id,
            name: cls.name,
            nameAr: cls.nameAr,
            displayOrder: i,
          );
          synced = synced && classResult.syncedToServer;
        }
        add(
          LoadMeetingsAndClasses(
            flashMessage: synced
                ? 'تم إنشاء الاجتماع بنجاح'
                : kOfflineSavedMessage,
          ),
        );
        event.completion?.complete();
      } catch (e, stackTrace) {
        event.completion?.completeError(e, stackTrace);
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(
              flashMessage: 'فشل إنشاء الاجتماع: ${e.toString()}',
            ),
          );
        } else {
          emit(MeetingsError('فشل إنشاء الاجتماع: ${e.toString()}'));
        }
      }
    });

    on<UpdateExistingMeeting>((event, emit) async {
      final previous = state;
      try {
        final result = await repository.updateMeeting(
          id: event.id,
          name: event.name,
          nameAr: event.nameAr,
          weekday: event.weekday,
          isActive: event.isActive,
          attendanceReminderMinutes: event.attendanceReminderMinutes,
          description: event.description,
        );
        add(
          LoadMeetingsAndClasses(
            flashMessage: result.syncedToServer
                ? 'تم حفظ تعديلات الاجتماع بنجاح'
                : kOfflineSavedMessage,
          ),
        );
        event.completion?.complete();
      } catch (e, stackTrace) {
        event.completion?.completeError(e, stackTrace);
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(
              flashMessage: 'فشل تعديل الاجتماع: ${e.toString()}',
            ),
          );
        } else {
          emit(MeetingsError('فشل تعديل الاجتماع: ${e.toString()}'));
        }
      }
    });

    on<DeleteExistingMeeting>((event, emit) async {
      final previous = state;
      try {
        final synced = await repository.deleteMeeting(event.id);
        add(
          LoadMeetingsAndClasses(
            flashMessage: synced ? null : kOfflineSavedMessage,
          ),
        );
      } catch (e) {
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(
              flashMessage: 'فشل حذف الاجتماع: ${e.toString()}',
            ),
          );
        } else {
          emit(MeetingsError('فشل حذف الاجتماع: ${e.toString()}'));
        }
      }
    });

    on<CreateClass>((event, emit) async {
      final previous = state;
      try {
        final result = await repository.createSundaySchoolClass(
          meetingId: event.meetingId,
          name: event.name,
          nameAr: event.nameAr,
          displayOrder: event.displayOrder,
        );
        add(
          LoadMeetingsAndClasses(
            flashMessage: result.syncedToServer ? null : kOfflineSavedMessage,
          ),
        );
      } catch (e) {
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(flashMessage: 'فشل إنشاء الفصل: ${e.toString()}'),
          );
        } else {
          emit(MeetingsError('فشل إنشاء الفصل: ${e.toString()}'));
        }
      }
    });

    on<UpdateClass>((event, emit) async {
      final previous = state;
      try {
        final result = await repository.updateSundaySchoolClass(
          id: event.id,
          name: event.name,
          nameAr: event.nameAr,
          displayOrder: event.displayOrder,
          isActive: event.isActive,
        );
        add(
          LoadMeetingsAndClasses(
            flashMessage: result.syncedToServer ? null : kOfflineSavedMessage,
          ),
        );
      } catch (e) {
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(flashMessage: 'فشل تعديل الفصل: ${e.toString()}'),
          );
        } else {
          emit(MeetingsError('فشل تعديل الفصل: ${e.toString()}'));
        }
      }
    });

    on<DeleteClass>((event, emit) async {
      final previous = state;
      try {
        final synced = await repository.deleteSundaySchoolClass(event.id);
        add(
          LoadMeetingsAndClasses(
            flashMessage: synced ? null : kOfflineSavedMessage,
          ),
        );
      } catch (e) {
        if (previous is MeetingsLoaded) {
          emit(
            previous.copyWith(flashMessage: 'فشل حذف الفصل: ${e.toString()}'),
          );
        } else {
          emit(MeetingsError('فشل حذف الفصل: ${e.toString()}'));
        }
      }
    });

    on<ClearMeetingsFlashMessage>((event, emit) {
      final current = state;
      if (current is MeetingsLoaded && current.flashMessage != null) {
        emit(current.copyWith(clearFlashMessage: true));
      }
    });
  }
}
