import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/diagnostics/storage_write_error.dart';
import '../../../core/errors/arabic_error_text.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/offline/offline_save_result.dart';
import '../../../data/repositories/database_repository.dart';

String _memberWriteErrorMessage(Object error, {required bool isCreate}) {
  return StorageWriteError.from(
    error,
  ).message(action: isCreate ? 'إضافة العضو' : 'حفظ تعديلات العضو');
}

// EVENTS
abstract class MembersEvent {}

class LoadMembers extends MembersEvent {
  final String? flashMessage;
  final bool flashIsError;

  LoadMembers({this.flashMessage, this.flashIsError = false});
}

class SearchAndFilterMembers extends MembersEvent {
  final String query;
  final String? classIdFilter;
  final String? meetingIdFilter;
  final String? scopeFilter; // 'all' | 'sunday_school_class' | 'meeting'
  SearchAndFilterMembers({
    required this.query,
    this.classIdFilter,
    this.meetingIdFilter,
    this.scopeFilter,
  });
}

class CreateMember extends MembersEvent {
  final String fullName;
  final MemberScope scope;
  final String? sundaySchoolClassId;
  final String? meetingId;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final DateTime? birthDate;
  final String? notes;
  final Completer<OfflineSaveResult<MemberEntity>>? completion;

  CreateMember({
    required this.fullName,
    required this.scope,
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    this.birthDate,
    this.notes,
    this.completion,
  });
}

class UpdateMemberEvent extends MembersEvent {
  final String id;
  final String fullName;
  final MemberScope scope;
  final String? sundaySchoolClassId;
  final String? meetingId;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final DateTime? birthDate;
  final bool isActive;
  final String? notes;
  final Completer<OfflineSaveResult<MemberEntity>>? completion;

  UpdateMemberEvent({
    required this.id,
    required this.fullName,
    required this.scope,
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    this.birthDate,
    required this.isActive,
    this.notes,
    this.completion,
  });
}

class DeleteMemberEvent extends MembersEvent {
  final String id;
  DeleteMemberEvent(this.id);
}

class ClearMembersFlashMessage extends MembersEvent {}

class MembersRealtimeUpdated extends MembersEvent {
  final List<MemberEntity> members;

  MembersRealtimeUpdated(this.members);
}

// STATES
abstract class MembersState {}

class MembersInitial extends MembersState {}

class MembersLoading extends MembersState {}

class MembersLoaded extends MembersState {
  final List<MemberEntity> allMembers;
  final List<MemberEntity> filteredMembers;
  final String query;
  final String? classIdFilter;
  final String? meetingIdFilter;
  final String? scopeFilter;
  final String? flashMessage;
  final bool flashIsError;

  MembersLoaded({
    required this.allMembers,
    required this.filteredMembers,
    this.query = '',
    this.classIdFilter,
    this.meetingIdFilter,
    this.scopeFilter,
    this.flashMessage,
    this.flashIsError = false,
  });

  MembersLoaded copyWith({
    List<MemberEntity>? allMembers,
    List<MemberEntity>? filteredMembers,
    String? query,
    String? classIdFilter,
    String? meetingIdFilter,
    String? scopeFilter,
    String? flashMessage,
    bool? flashIsError,
    bool clearFlashMessage = false,
  }) {
    return MembersLoaded(
      allMembers: allMembers ?? this.allMembers,
      filteredMembers: filteredMembers ?? this.filteredMembers,
      query: query ?? this.query,
      classIdFilter: classIdFilter ?? this.classIdFilter,
      meetingIdFilter: meetingIdFilter ?? this.meetingIdFilter,
      scopeFilter: scopeFilter ?? this.scopeFilter,
      flashMessage: clearFlashMessage
          ? null
          : (flashMessage ?? this.flashMessage),
      flashIsError: clearFlashMessage
          ? false
          : (flashIsError ?? this.flashIsError),
    );
  }
}

class MembersError extends MembersState {
  final String message;
  MembersError(this.message);
}

// BLOC
class MembersBloc extends Bloc<MembersEvent, MembersState> {
  final DatabaseRepository repository;
  StreamSubscription<List<MemberEntity>>? _membersSubscription;
  bool _isAdmin = false;
  Set<String> _viewClassIds = {};
  Set<String> _viewMeetingIds = {};

  MembersBloc({required this.repository}) : super(MembersInitial()) {
    on<LoadMembers>((event, emit) async {
      emit(MembersLoading());
      try {
        final profile = await repository.getCurrentProfile();
        final members = await repository.getAllMembers();
        _isAdmin =
            profile != null &&
            (profile.role == AppRole.superAdmin ||
                profile.role == AppRole.churchAdmin);

        if (!_isAdmin && profile != null) {
          final assignments = await Future.wait([
            repository.getUserClassAssignments(profile.id),
            repository.getUserMeetingAssignments(profile.id),
          ]);
          _viewClassIds = assignments[0]
              .where(
                (a) =>
                    (a['can_take_attendance'] as bool? ?? true) ||
                    (a['can_view_reports'] as bool? ?? true),
              )
              .map((a) => a['class_id'] as String)
              .toSet();
          _viewMeetingIds = assignments[1]
              .where(
                (a) =>
                    (a['can_take_attendance'] as bool? ?? true) ||
                    (a['can_view_reports'] as bool? ?? true),
              )
              .map((a) => a['meeting_id'] as String)
              .toSet();
        } else {
          _viewClassIds = {};
          _viewMeetingIds = {};
        }

        final scoped = _scopeMembers(members);
        emit(
          MembersLoaded(
            allMembers: scoped,
            filteredMembers: _applyMemberFilters(
              scoped,
              query: '',
              classIdFilter: null,
              meetingIdFilter: null,
              scopeFilter: null,
            ),
            flashMessage: event.flashMessage,
            flashIsError: event.flashIsError,
          ),
        );
        _ensureRealtimeSubscription();
      } catch (e) {
        try {
          final members = await repository.getAllMembers();
          emit(
            MembersLoaded(
              allMembers: members,
              filteredMembers: members.where((m) => m.isActive).toList(),
              flashMessage: event.flashMessage,
              flashIsError: event.flashIsError,
            ),
          );
          _ensureRealtimeSubscription();
        } catch (_) {
          emit(MembersError('فشل تحميل الأعضاء: ${arabicErrorText(e)}'));
        }
      }
    });

    on<SearchAndFilterMembers>((event, emit) {
      final currentState = state;
      if (currentState is MembersLoaded) {
        emit(
          currentState.copyWith(
            filteredMembers: _applyMemberFilters(
              currentState.allMembers,
              query: event.query,
              classIdFilter: event.classIdFilter,
              meetingIdFilter: event.meetingIdFilter,
              scopeFilter: event.scopeFilter,
            ),
            query: event.query,
            classIdFilter: event.classIdFilter,
            meetingIdFilter: event.meetingIdFilter,
            scopeFilter: event.scopeFilter,
          ),
        );
      }
    });

    on<MembersRealtimeUpdated>((event, emit) {
      final currentState = state;
      if (currentState is! MembersLoaded) return;
      final scoped = _scopeMembers(event.members);
      emit(
        currentState.copyWith(
          allMembers: scoped,
          filteredMembers: _applyMemberFilters(
            scoped,
            query: currentState.query,
            classIdFilter: currentState.classIdFilter,
            meetingIdFilter: currentState.meetingIdFilter,
            scopeFilter: currentState.scopeFilter,
          ),
        ),
      );
    });

    on<CreateMember>((event, emit) async {
      final previous = state;
      try {
        final result = await repository.createMember(
          fullName: event.fullName,
          scope: event.scope,
          sundaySchoolClassId: event.sundaySchoolClassId,
          meetingId: event.meetingId,
          phone: event.phone,
          parentName: event.parentName,
          parentPhone: event.parentPhone,
          code: event.code,
          birthDate: event.birthDate,
          notes: event.notes,
        );
        add(
          LoadMembers(
            flashMessage: result.syncedToServer
                ? 'تم إضافة العضو بنجاح'
                : kOfflineSavedMessage,
          ),
        );
        event.completion?.complete(result);
      } catch (e, stackTrace) {
        event.completion?.completeError(e, stackTrace);
        final message = _memberWriteErrorMessage(e, isCreate: true);
        if (previous is MembersLoaded) {
          emit(previous.copyWith(flashMessage: message, flashIsError: true));
        } else {
          emit(MembersError(message));
        }
      }
    });

    on<UpdateMemberEvent>((event, emit) async {
      final previous = state;
      try {
        final result = await repository.updateMember(
          id: event.id,
          fullName: event.fullName,
          scope: event.scope,
          sundaySchoolClassId: event.sundaySchoolClassId,
          meetingId: event.meetingId,
          phone: event.phone,
          parentName: event.parentName,
          parentPhone: event.parentPhone,
          code: event.code,
          birthDate: event.birthDate,
          isActive: event.isActive,
          notes: event.notes,
        );
        add(
          LoadMembers(
            flashMessage: result.syncedToServer
                ? 'تم حفظ تعديلات العضو بنجاح'
                : kOfflineSavedMessage,
          ),
        );
        event.completion?.complete(result);
      } catch (e, stackTrace) {
        event.completion?.completeError(e, stackTrace);
        final message = _memberWriteErrorMessage(e, isCreate: false);
        if (previous is MembersLoaded) {
          emit(previous.copyWith(flashMessage: message, flashIsError: true));
        } else {
          emit(MembersError(message));
        }
      }
    });

    on<DeleteMemberEvent>((event, emit) async {
      final previous = state;
      try {
        final synced = await repository.deleteMember(event.id);
        add(LoadMembers(flashMessage: synced ? null : kOfflineSavedMessage));
      } catch (e) {
        if (previous is MembersLoaded) {
          emit(
            previous.copyWith(
              flashMessage: StorageWriteError.from(
                e,
              ).message(action: 'حذف العضو'),
              flashIsError: true,
            ),
          );
        } else {
          emit(
            MembersError(
              StorageWriteError.from(e).message(action: 'حذف العضو'),
            ),
          );
        }
      }
    });

    on<ClearMembersFlashMessage>((event, emit) {
      final current = state;
      if (current is MembersLoaded && current.flashMessage != null) {
        emit(current.copyWith(clearFlashMessage: true));
      }
    });
  }

  void _ensureRealtimeSubscription() {
    _membersSubscription ??= repository.subscribeToMembers().listen((members) {
      add(MembersRealtimeUpdated(members));
    });
  }

  List<MemberEntity> _scopeMembers(List<MemberEntity> members) {
    if (_isAdmin) return members;
    return [
      for (final member in members)
        if ((member.sundaySchoolClassId != null &&
                _viewClassIds.contains(member.sundaySchoolClassId)) ||
            (member.meetingId != null &&
                _viewMeetingIds.contains(member.meetingId)))
          member,
    ];
  }

  List<MemberEntity> _applyMemberFilters(
    List<MemberEntity> members, {
    required String query,
    required String? classIdFilter,
    required String? meetingIdFilter,
    required String? scopeFilter,
  }) {
    var filtered = members.where((m) => m.isActive).toList();

    if (scopeFilter != null && scopeFilter != 'all') {
      filtered = filtered.where((m) => m.scope.value == scopeFilter).toList();
    }
    if (classIdFilter != null && classIdFilter.isNotEmpty) {
      filtered = filtered
          .where((m) => m.sundaySchoolClassId == classIdFilter)
          .toList();
    }
    if (meetingIdFilter != null && meetingIdFilter.isNotEmpty) {
      filtered = filtered.where((m) => m.meetingId == meetingIdFilter).toList();
    }
    if (query.trim().isNotEmpty) {
      final queryLower = query.toLowerCase();
      filtered = filtered
          .where(
            (m) =>
                m.fullName.toLowerCase().contains(queryLower) ||
                (m.code != null &&
                    m.code!.toLowerCase().contains(queryLower)) ||
                (m.phone != null && m.phone!.contains(queryLower)),
          )
          .toList();
    }
    return filtered;
  }

  @override
  Future<void> close() {
    unawaited(_membersSubscription?.cancel());
    return super.close();
  }
}
