import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class AttendanceEvent {}

class LoadAttendanceSessions extends AttendanceEvent {
  final String meetingId;
  final String? classId;
  LoadAttendanceSessions({required this.meetingId, this.classId});
}

class CreateSession extends AttendanceEvent {
  final String meetingId;
  final String? classId;
  final DateTime sessionDate;
  final int weekNumber;
  final String? title;

  CreateSession({
    required this.meetingId,
    this.classId,
    required this.sessionDate,
    required this.weekNumber,
    this.title,
  });
}

class DeleteSession extends AttendanceEvent {
  final String sessionId;
  DeleteSession(this.sessionId);
}

class LoadAttendanceSheet extends AttendanceEvent {
  final AttendanceSessionEntity session;
  final String? flashMessage;

  LoadAttendanceSheet(this.session, {this.flashMessage});
}

class UpdateMemberStatus extends AttendanceEvent {
  final String memberId;
  final AttendanceStatus status;
  UpdateMemberStatus({required this.memberId, required this.status});
}

class SearchSheetMembers extends AttendanceEvent {
  final String query;
  SearchSheetMembers(this.query);
}

class FilterSheetMembers extends AttendanceEvent {
  final String filter; // 'all' | 'present' | 'absent' | 'excused'
  FilterSheetMembers(this.filter);
}

class MarkAllStatus extends AttendanceEvent {
  final AttendanceStatus status;
  MarkAllStatus(this.status);
}

class SaveAttendanceSheet extends AttendanceEvent {}

class OnRealtimeRecordsUpdated extends AttendanceEvent {
  final List<AttendanceRecordEntity> records;
  OnRealtimeRecordsUpdated(this.records);
}

class AddNewcomerToSheet extends AttendanceEvent {
  final String fullName;
  final String? code;
  final String? phone;
  final String? parentName;
  final String? parentPhone;

  AddNewcomerToSheet({
    required this.fullName,
    this.code,
    this.phone,
    this.parentName,
    this.parentPhone,
  });
}

class ClearJustSavedFlag extends AttendanceEvent {}

class ClearFlashMessage extends AttendanceEvent {}

// STATES
abstract class AttendanceState {}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class SessionsLoaded extends AttendanceState {
  final List<AttendanceSessionEntity> sessions;
  final String meetingId;
  final String? classId;
  SessionsLoaded({
    required this.sessions,
    required this.meetingId,
    this.classId,
  });
}

class AttendanceSheetLoaded extends AttendanceState {
  final AttendanceSessionEntity session;
  final List<MemberEntity> allMembers;
  final Map<String, AttendanceStatus> statusMap; // memberId -> status
  final List<MemberEntity> filteredMembers;
  final String searchQuery;
  final String statusFilter;
  final bool isSaving;
  final bool isDirty;
  final bool justSaved;
  final String? flashMessage;

  AttendanceSheetLoaded({
    required this.session,
    required this.allMembers,
    required this.statusMap,
    required this.filteredMembers,
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.isSaving = false,
    this.isDirty = false,
    this.justSaved = false,
    this.flashMessage,
  });

  AttendanceSheetLoaded copyWith({
    AttendanceSessionEntity? session,
    List<MemberEntity>? allMembers,
    Map<String, AttendanceStatus>? statusMap,
    List<MemberEntity>? filteredMembers,
    String? searchQuery,
    String? statusFilter,
    bool? isSaving,
    bool? isDirty,
    bool? justSaved,
    String? flashMessage,
    bool clearFlashMessage = false,
  }) {
    return AttendanceSheetLoaded(
      session: session ?? this.session,
      allMembers: allMembers ?? this.allMembers,
      statusMap: statusMap ?? this.statusMap,
      filteredMembers: filteredMembers ?? this.filteredMembers,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      justSaved: justSaved ?? this.justSaved,
      flashMessage:
          clearFlashMessage ? null : (flashMessage ?? this.flashMessage),
    );
  }
}

class AttendanceError extends AttendanceState {
  final String message;
  AttendanceError(this.message);
}

// BLOC
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final DatabaseRepository repository;
  StreamSubscription? _recordsSubscription;

  AttendanceBloc({required this.repository}) : super(AttendanceInitial()) {
    on<LoadAttendanceSessions>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final sessions = await repository.getSessions(
          event.meetingId,
          classId: event.classId,
        );
        emit(
          SessionsLoaded(
            sessions: sessions,
            meetingId: event.meetingId,
            classId: event.classId,
          ),
        );
      } catch (e) {
        emit(AttendanceError('فشل تحميل الجلسات: ${e.toString()}'));
      }
    });

    on<CreateSession>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final result = await repository.createWeeklySession(
          meetingId: event.meetingId,
          classId: event.classId,
          sessionDate: event.sessionDate,
          weekNumber: event.weekNumber,
          title: event.title,
        );
        add(
          LoadAttendanceSheet(
            result.data,
            flashMessage:
                result.syncedToServer ? null : kOfflineSavedMessage,
          ),
        );
      } catch (e) {
        emit(AttendanceError('فشل إنشاء جلسة جديدة: ${e.toString()}'));
      }
    });

    on<DeleteSession>((event, emit) async {
      final currentState = state;
      String? meetingId;
      String? classId;

      if (currentState is SessionsLoaded) {
        meetingId = currentState.meetingId;
        classId = currentState.classId;
      } else if (currentState is AttendanceSheetLoaded) {
        meetingId = currentState.session.meetingId;
        classId = currentState.session.classId;
      }

      if (meetingId != null) {
        emit(AttendanceLoading());
        try {
          await repository.deleteWeeklySession(
            event.sessionId,
            meetingId: meetingId,
            classId: classId,
          );
          add(LoadAttendanceSessions(meetingId: meetingId, classId: classId));
        } catch (e) {
          emit(AttendanceError('فشل حذف الجلسة: ${e.toString()}'));
        }
      }
    });

    on<LoadAttendanceSheet>((event, emit) async {
      emit(AttendanceLoading());
      try {
        _recordsSubscription?.cancel();

        List<MemberEntity> members;
        if (event.session.classId != null) {
          members = await repository.getClassMembers(event.session.classId!);
        } else {
          members = await repository.getMeetingMembers(event.session.meetingId);
        }

        // Sort alphabetically
        members.sort((a, b) => a.fullName.compareTo(b.fullName));

        final records = await repository.getAttendanceRecords(event.session.id);
        final Map<String, AttendanceStatus> statusMap = {};

        if (records.isNotEmpty) {
          for (var m in members) {
            final record = records.where((r) => r.memberId == m.id).firstOrNull;
            statusMap[m.id] = record?.status ?? AttendanceStatus.absent;
          }
        } else {
          // Copy from previous week if available
          final sessions = await repository.getSessions(
            event.session.meetingId,
            classId: event.session.classId,
          );
          final sortedSessions = List<AttendanceSessionEntity>.from(sessions)
            ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
          final prevSession = sortedSessions
              .where((s) => s.id != event.session.id)
              .firstOrNull;

          if (prevSession != null) {
            final prevRecords = await repository.getAttendanceRecords(
              prevSession.id,
            );
            for (var m in members) {
              final prevRecord = prevRecords
                  .where((r) => r.memberId == m.id)
                  .firstOrNull;
              statusMap[m.id] = prevRecord?.status ?? AttendanceStatus.absent;
            }
          } else {
            for (var m in members) {
              statusMap[m.id] = AttendanceStatus.absent;
            }
          }
        }

        // Subscribe to real-time updates
        _recordsSubscription = repository
            .subscribeToAttendanceRecords(event.session.id)
            .listen((updatedRecords) {
              add(OnRealtimeRecordsUpdated(updatedRecords));
            });

        emit(
          AttendanceSheetLoaded(
            session: event.session,
            allMembers: members,
            statusMap: statusMap,
            filteredMembers: members,
            flashMessage: event.flashMessage,
          ),
        );
      } catch (e) {
        emit(AttendanceError('فشل تحميل كشف الحضور: ${e.toString()}'));
      }
    });

    on<OnRealtimeRecordsUpdated>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        if (currentState.isDirty || currentState.isSaving) {
          return;
        }
        final newMap = Map<String, AttendanceStatus>.from(
          currentState.statusMap,
        );
        for (var record in event.records) {
          newMap[record.memberId] = record.status;
        }
        final updated = currentState.copyWith(statusMap: newMap);
        emit(_applyFilters(updated));
      }
    });

    on<AddNewcomerToSheet>((event, emit) async {
      final currentState = state;
      if (currentState is! AttendanceSheetLoaded) return;

      try {
        final result = await repository.createMember(
          fullName: event.fullName,
          scope: currentState.session.classId != null
              ? MemberScope.sundaySchoolClass
              : MemberScope.meeting,
          sundaySchoolClassId: currentState.session.classId,
          meetingId: currentState.session.classId == null
              ? currentState.session.meetingId
              : null,
          phone: event.phone,
          parentName: event.parentName,
          parentPhone: event.parentPhone,
          code: event.code,
        );
        final created = result.data;

        final updatedMembers = List<MemberEntity>.from(currentState.allMembers)
          ..add(created)
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

        final newMap = Map<String, AttendanceStatus>.from(
          currentState.statusMap,
        );
        newMap[created.id] = AttendanceStatus.present;

        emit(
          _applyFilters(
            currentState.copyWith(
              allMembers: updatedMembers,
              statusMap: newMap,
              isDirty: true,
              justSaved: false,
              flashMessage: result.syncedToServer
                  ? 'تمت إضافة العضو وتحديده كحاضر'
                  : 'تمت إضافة العضو وتحديده كحاضر — $kOfflineSavedMessage',
            ),
          ),
        );
      } catch (e) {
        emit(
          _applyFilters(
            currentState.copyWith(
              flashMessage: 'فشل إضافة العضو: ${e.toString()}',
            ),
          ),
        );
      }
    });

    on<ClearJustSavedFlag>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded && currentState.justSaved) {
        emit(currentState.copyWith(justSaved: false));
      }
    });

    on<ClearFlashMessage>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded &&
          currentState.flashMessage != null) {
        emit(currentState.copyWith(clearFlashMessage: true));
      }
    });

    on<UpdateMemberStatus>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        final newMap = Map<String, AttendanceStatus>.from(
          currentState.statusMap,
        );
        newMap[event.memberId] = event.status;

        final updated = currentState.copyWith(
          statusMap: newMap,
          isDirty: true,
          justSaved: false,
        );
        emit(_applyFilters(updated));
      }
    });

    on<SearchSheetMembers>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        final updated = currentState.copyWith(searchQuery: event.query);
        emit(_applyFilters(updated));
      }
    });

    on<FilterSheetMembers>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        final updated = currentState.copyWith(statusFilter: event.filter);
        emit(_applyFilters(updated));
      }
    });

    on<MarkAllStatus>((event, emit) {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        final newMap = Map<String, AttendanceStatus>.from(
          currentState.statusMap,
        );
        for (var m in currentState.filteredMembers) {
          newMap[m.id] = event.status;
        }

        final updated = currentState.copyWith(
          statusMap: newMap,
          isDirty: true,
          justSaved: false,
        );
        emit(_applyFilters(updated));
      }
    });

    on<SaveAttendanceSheet>((event, emit) async {
      final currentState = state;
      if (currentState is AttendanceSheetLoaded) {
        emit(currentState.copyWith(isSaving: true, justSaved: false));
        try {
          final savedToServer = await repository.saveAttendanceRecords(
            sessionId: currentState.session.id,
            statusesByMemberId: currentState.statusMap,
          );
          emit(
            currentState.copyWith(
              isSaving: false,
              isDirty: !savedToServer,
              justSaved: true,
              flashMessage: savedToServer ? null : kOfflineSavedMessage,
            ),
          );
        } catch (e) {
          emit(
            currentState.copyWith(
              isSaving: false,
              justSaved: false,
              flashMessage: 'فشل حفظ الحضور: ${e.toString()}',
            ),
          );
        }
      }
    });
  }

  AttendanceSheetLoaded _applyFilters(AttendanceSheetLoaded sheetState) {
    var filtered = sheetState.allMembers;

    // Search query filter
    if (sheetState.searchQuery.isNotEmpty) {
      final q = sheetState.searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (m) =>
                m.fullName.toLowerCase().contains(q) ||
                (m.code != null && m.code!.toLowerCase().contains(q)),
          )
          .toList();
    }

    // Status filter
    if (sheetState.statusFilter != 'all') {
      filtered = filtered
          .where(
            (m) => sheetState.statusMap[m.id]?.value == sheetState.statusFilter,
          )
          .toList();
    }

    return sheetState.copyWith(filteredMembers: filtered);
  }

  @override
  Future<void> close() {
    _recordsSubscription?.cancel();
    return super.close();
  }
}
