import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/offline/offline_save_result.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class MembersEvent {}

class LoadMembers extends MembersEvent {
  final String? flashMessage;

  LoadMembers({this.flashMessage});
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

  MembersLoaded({
    required this.allMembers,
    required this.filteredMembers,
    this.query = '',
    this.classIdFilter,
    this.meetingIdFilter,
    this.scopeFilter,
    this.flashMessage,
  });

  MembersLoaded copyWith({
    List<MemberEntity>? allMembers,
    List<MemberEntity>? filteredMembers,
    String? query,
    String? classIdFilter,
    String? meetingIdFilter,
    String? scopeFilter,
    String? flashMessage,
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

  MembersBloc({required this.repository}) : super(MembersInitial()) {
    on<LoadMembers>((event, emit) async {
      emit(MembersLoading());
      try {
        final profile = await repository.getCurrentProfile();
        final members = await repository.getAllMembers();
        final isAdmin =
            profile != null &&
            (profile.role == AppRole.superAdmin ||
                profile.role == AppRole.churchAdmin);

        List<MemberEntity> scoped = members;
        if (!isAdmin && profile != null) {
          final assignments = await Future.wait([
            repository.getUserClassAssignments(profile.id),
            repository.getUserMeetingAssignments(profile.id),
          ]);
          final classIds = assignments[0]
              .where(
                (a) =>
                    (a['can_take_attendance'] as bool? ?? true) ||
                    (a['can_view_reports'] as bool? ?? true),
              )
              .map((a) => a['class_id'] as String)
              .toSet();
          final meetingIds = assignments[1]
              .where(
                (a) =>
                    (a['can_take_attendance'] as bool? ?? true) ||
                    (a['can_view_reports'] as bool? ?? true),
              )
              .map((a) => a['meeting_id'] as String)
              .toSet();
          scoped = members
              .where(
                (m) =>
                    (m.sundaySchoolClassId != null &&
                        classIds.contains(m.sundaySchoolClassId)) ||
                    (m.meetingId != null && meetingIds.contains(m.meetingId)),
              )
              .toList();
        }

        emit(
          MembersLoaded(
            allMembers: scoped,
            filteredMembers: scoped.where((m) => m.isActive).toList(),
            flashMessage: event.flashMessage,
          ),
        );
      } catch (e) {
        try {
          final members = await repository.getAllMembers();
          emit(
            MembersLoaded(
              allMembers: members,
              filteredMembers: members.where((m) => m.isActive).toList(),
              flashMessage: event.flashMessage,
            ),
          );
        } catch (_) {
          emit(MembersError('فشل تحميل الأعضاء: ${e.toString()}'));
        }
      }
    });

    on<SearchAndFilterMembers>((event, emit) {
      final currentState = state;
      if (currentState is MembersLoaded) {
        var filtered = currentState.allMembers;

        // Filter by active status (show active by default)
        filtered = filtered.where((m) => m.isActive).toList();

        // Filter by scope
        if (event.scopeFilter != null && event.scopeFilter != 'all') {
          filtered = filtered
              .where((m) => m.scope.value == event.scopeFilter)
              .toList();
        }

        // Filter by class
        if (event.classIdFilter != null && event.classIdFilter!.isNotEmpty) {
          filtered = filtered
              .where((m) => m.sundaySchoolClassId == event.classIdFilter)
              .toList();
        }

        // Filter by meeting
        if (event.meetingIdFilter != null &&
            event.meetingIdFilter!.isNotEmpty) {
          filtered = filtered
              .where((m) => m.meetingId == event.meetingIdFilter)
              .toList();
        }

        // Filter by search query
        if (event.query.trim().isNotEmpty) {
          final queryLower = event.query.toLowerCase();
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

        emit(
          currentState.copyWith(
            filteredMembers: filtered,
            query: event.query,
            classIdFilter: event.classIdFilter,
            meetingIdFilter: event.meetingIdFilter,
            scopeFilter: event.scopeFilter,
          ),
        );
      }
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
        if (previous is MembersLoaded) {
          emit(
            previous.copyWith(flashMessage: 'فشل إضافة العضو: ${e.toString()}'),
          );
        } else {
          emit(MembersError('فشل إضافة العضو: ${e.toString()}'));
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
        if (previous is MembersLoaded) {
          emit(
            previous.copyWith(
              flashMessage: 'فشل تعديل بيانات العضو: ${e.toString()}',
            ),
          );
        } else {
          emit(MembersError('فشل تعديل بيانات العضو: ${e.toString()}'));
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
            previous.copyWith(flashMessage: 'فشل حذف العضو: ${e.toString()}'),
          );
        } else {
          emit(MembersError('فشل حذف العضو: ${e.toString()}'));
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
}
