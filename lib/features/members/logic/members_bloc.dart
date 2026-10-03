import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/storage_write_error.dart';
import '../../../core/errors/arabic_error_text.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/member_local_store.dart';
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

class LoadMoreMembers extends MembersEvent {}

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
  final String? schoolYear;
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
    this.schoolYear,
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
  final String? schoolYear;
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
    this.schoolYear,
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
  final MemberRealtimeDelta delta;

  MembersRealtimeUpdated(this.delta);
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
  final bool hasMore;
  final bool isLoadingMore;
  final int page;
  final int totalCount;
  final int sundaySchoolCount;
  final int meetingsCount;

  MembersLoaded({
    required this.allMembers,
    required this.filteredMembers,
    this.query = '',
    this.classIdFilter,
    this.meetingIdFilter,
    this.scopeFilter,
    this.flashMessage,
    this.flashIsError = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.page = 0,
    this.totalCount = 0,
    this.sundaySchoolCount = 0,
    this.meetingsCount = 0,
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
    bool? hasMore,
    bool? isLoadingMore,
    int? page,
    int? totalCount,
    int? sundaySchoolCount,
    int? meetingsCount,
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
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      totalCount: totalCount ?? this.totalCount,
      sundaySchoolCount: sundaySchoolCount ?? this.sundaySchoolCount,
      meetingsCount: meetingsCount ?? this.meetingsCount,
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
  StreamSubscription<MemberRealtimeDelta>? _membersSubscription;
  bool _isAdmin = false;
  Set<String> _viewClassIds = {};
  Set<String> _viewMeetingIds = {};
  Set<String> _manageClassIds = {};
  Set<String> _manageMeetingIds = {};
  bool _permissionsReady = false;

  bool canManageMember(MemberEntity member) {
    if (_isAdmin) return true;
    if (member.scope == MemberScope.sundaySchoolClass) {
      return member.sundaySchoolClassId != null &&
          _manageClassIds.contains(member.sundaySchoolClassId);
    }
    return _manageMeetingIds.contains(member.meetingId);
  }

  bool canViewMeeting(String meetingId) =>
      _isAdmin || _viewMeetingIds.contains(meetingId);

  bool canManageMeeting(String meetingId) =>
      _isAdmin || _manageMeetingIds.contains(meetingId);

  MembersBloc({required this.repository}) : super(MembersInitial()) {
    on<LoadMembers>(_onLoadMembers, transformer: restartable());
    on<LoadMoreMembers>(_onLoadMoreMembers, transformer: droppable());
    on<SearchAndFilterMembers>(
      _onSearchAndFilterMembers,
      transformer: restartable(),
    );
    on<MembersRealtimeUpdated>(_onRealtimeUpdated);
    on<CreateMember>(_onCreateMember);
    on<UpdateMemberEvent>(_onUpdateMember);
    on<DeleteMemberEvent>(_onDeleteMember);
    on<ClearMembersFlashMessage>((event, emit) {
      final current = state;
      if (current is MembersLoaded && current.flashMessage != null) {
        emit(current.copyWith(clearFlashMessage: true));
      }
    });
  }

  Future<void> _onLoadMembers(
    LoadMembers event,
    Emitter<MembersState> emit,
  ) async {
    final previous = state;
    final query = previous is MembersLoaded ? previous.query : '';
    final classIdFilter = previous is MembersLoaded
        ? previous.classIdFilter
        : null;
    final meetingIdFilter = previous is MembersLoaded
        ? previous.meetingIdFilter
        : null;
    final scopeFilter = previous is MembersLoaded ? previous.scopeFilter : null;
    if (previous is! MembersLoaded) {
      emit(MembersLoading());
    }
    try {
      await _ensurePermissions();
      final page = await _fetchPage(
        page: 0,
        query: query,
        classIdFilter: classIdFilter,
        meetingIdFilter: meetingIdFilter,
        scopeFilter: scopeFilter,
      );
      emit(
        _stateFromPage(
          page,
          query: query,
          classIdFilter: classIdFilter,
          meetingIdFilter: meetingIdFilter,
          scopeFilter: scopeFilter,
          flashMessage: event.flashMessage,
          flashIsError: event.flashIsError,
        ),
      );
      _ensureRealtimeSubscription();
    } catch (e) {
      if (previous is MembersLoaded) {
        emit(
          previous.copyWith(
            flashMessage: 'فشل تحميل الأعضاء: ${arabicErrorText(e)}',
            flashIsError: true,
          ),
        );
        return;
      }
      emit(MembersError('فشل تحميل الأعضاء: ${arabicErrorText(e)}'));
    }
  }

  Future<void> _onLoadMoreMembers(
    LoadMoreMembers event,
    Emitter<MembersState> emit,
  ) async {
    final current = state;
    if (current is! MembersLoaded ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetchPage(
        page: current.page + 1,
        query: current.query,
        classIdFilter: current.classIdFilter,
        meetingIdFilter: current.meetingIdFilter,
        scopeFilter: current.scopeFilter,
      );
      final next = _scopeMembers(page.items);
      final merged = _mergeMembers(current.allMembers, next);
      emit(
        current.copyWith(
          allMembers: merged,
          filteredMembers: merged,
          hasMore: page.hasMore,
          isLoadingMore: false,
          page: page.page,
          totalCount: page.counts.total == 0
              ? current.totalCount
              : page.counts.total,
          sundaySchoolCount: page.counts.sundaySchool == 0
              ? current.sundaySchoolCount
              : page.counts.sundaySchool,
          meetingsCount: page.counts.meetings == 0
              ? current.meetingsCount
              : page.counts.meetings,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSearchAndFilterMembers(
    SearchAndFilterMembers event,
    Emitter<MembersState> emit,
  ) async {
    final previous = state;
    if (previous is MembersLoaded) {
      emit(
        previous.copyWith(
          query: event.query,
          classIdFilter: event.classIdFilter,
          meetingIdFilter: event.meetingIdFilter,
          scopeFilter: event.scopeFilter,
        ),
      );
    } else {
      emit(MembersLoading());
    }
    try {
      await _ensurePermissions();
      final page = await _fetchPage(
        page: 0,
        query: event.query,
        classIdFilter: event.classIdFilter,
        meetingIdFilter: event.meetingIdFilter,
        scopeFilter: event.scopeFilter,
      );
      final current = state;
      emit(
        _stateFromPage(
          page,
          query: event.query,
          classIdFilter: event.classIdFilter,
          meetingIdFilter: event.meetingIdFilter,
          scopeFilter: event.scopeFilter,
          flashMessage: current is MembersLoaded ? current.flashMessage : null,
          flashIsError: current is MembersLoaded && current.flashIsError,
          totalCount: current is MembersLoaded
              ? current.totalCount
              : page.counts.total,
          sundaySchoolCount: current is MembersLoaded
              ? current.sundaySchoolCount
              : page.counts.sundaySchool,
          meetingsCount: current is MembersLoaded
              ? current.meetingsCount
              : page.counts.meetings,
        ),
      );
      _ensureRealtimeSubscription();
    } catch (e) {
      if (previous is MembersLoaded) {
        emit(
          previous.copyWith(
            flashMessage: 'فشل تصفية الأعضاء: ${arabicErrorText(e)}',
            flashIsError: true,
          ),
        );
        return;
      }
      emit(MembersError('فشل تحميل الأعضاء: ${arabicErrorText(e)}'));
    }
  }

  void _onRealtimeUpdated(
    MembersRealtimeUpdated event,
    Emitter<MembersState> emit,
  ) {
    final current = state;
    if (current is! MembersLoaded) return;
    var members = [...current.allMembers];
    var totalCount = current.totalCount;
    var sundaySchoolCount = current.sundaySchoolCount;
    var meetingsCount = current.meetingsCount;

    if (event.delta.deletedIds.isNotEmpty) {
      final removed = members.where(
        (member) => event.delta.deletedIds.contains(member.id),
      );
      for (final member in removed) {
        totalCount = (totalCount - 1).clamp(0, totalCount);
        if (member.scope == MemberScope.sundaySchoolClass) {
          sundaySchoolCount = (sundaySchoolCount - 1).clamp(
            0,
            sundaySchoolCount,
          );
        } else {
          meetingsCount = (meetingsCount - 1).clamp(0, meetingsCount);
        }
      }
      members.removeWhere(
        (member) => event.delta.deletedIds.contains(member.id),
      );
    }

    for (final incoming in event.delta.upserts) {
      final previous = members
          .where((item) => item.id == incoming.id)
          .firstOrNull;
      final merged = previous == null
          ? incoming
          : incoming.copyWith(
              meetingIds: {
                ...previous.meetingIds,
                ...incoming.meetingIds,
              }.toList(),
            );
      final visible = _canViewMember(merged);
      final matches = visible && _matchesLoadedFilters(merged, current);
      final index = members.indexWhere((item) => item.id == merged.id);
      if (index >= 0 && !matches) {
        members.removeAt(index);
        continue;
      }
      if (!matches) {
        continue;
      }
      if (index >= 0) {
        members[index] = merged;
      } else {
        members.add(merged);
        if (previous == null && merged.isActive) {
          totalCount += 1;
          if (merged.scope == MemberScope.sundaySchoolClass) {
            sundaySchoolCount += 1;
          } else {
            meetingsCount += 1;
          }
        }
      }
    }
    members.sort((a, b) => a.fullName.compareTo(b.fullName));
    emit(
      current.copyWith(
        allMembers: members,
        filteredMembers: members,
        totalCount: totalCount,
        sundaySchoolCount: sundaySchoolCount,
        meetingsCount: meetingsCount,
      ),
    );
  }

  Future<void> _onCreateMember(
    CreateMember event,
    Emitter<MembersState> emit,
  ) async {
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
        schoolYear: event.schoolYear,
        notes: event.notes,
      );
      _applyLocalWrite(
        emit,
        member: result.data,
        flashMessage: result.syncedToServer
            ? 'تم إضافة العضو بنجاح'
            : kOfflineSavedMessage,
        isCreate: true,
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
  }

  Future<void> _onUpdateMember(
    UpdateMemberEvent event,
    Emitter<MembersState> emit,
  ) async {
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
        schoolYear: event.schoolYear,
        notes: event.notes,
      );
      _applyLocalWrite(
        emit,
        member: result.data,
        flashMessage: result.syncedToServer
            ? 'تم حفظ تعديلات العضو بنجاح'
            : kOfflineSavedMessage,
        isCreate: false,
        replacedId: event.id,
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
  }

  Future<void> _onDeleteMember(
    DeleteMemberEvent event,
    Emitter<MembersState> emit,
  ) async {
    final previous = state;
    try {
      final synced = await repository.deleteMember(event.id);
      if (previous is MembersLoaded) {
        final removed = previous.allMembers
            .where((member) => member.id == event.id)
            .firstOrNull;
        final remaining = [
          for (final member in previous.allMembers)
            if (member.id != event.id) member,
        ];
        emit(
          previous.copyWith(
            allMembers: remaining,
            filteredMembers: remaining,
            flashMessage: synced ? null : kOfflineSavedMessage,
            totalCount: (previous.totalCount - 1).clamp(0, previous.totalCount),
            sundaySchoolCount: removed?.scope == MemberScope.sundaySchoolClass
                ? (previous.sundaySchoolCount - 1).clamp(
                    0,
                    previous.sundaySchoolCount,
                  )
                : previous.sundaySchoolCount,
            meetingsCount: removed?.scope == MemberScope.meeting
                ? (previous.meetingsCount - 1).clamp(0, previous.meetingsCount)
                : previous.meetingsCount,
          ),
        );
        return;
      }
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
          MembersError(StorageWriteError.from(e).message(action: 'حذف العضو')),
        );
      }
    }
  }

  void _applyLocalWrite(
    Emitter<MembersState> emit, {
    required MemberEntity member,
    required String flashMessage,
    required bool isCreate,
    String? replacedId,
  }) {
    final current = state;
    if (current is! MembersLoaded) {
      add(LoadMembers(flashMessage: flashMessage));
      return;
    }
    final withoutReplaced = [
      for (final item in current.allMembers)
        if (item.id != member.id && item.id != replacedId) item,
    ];
    final matches =
        _canViewMember(member) && _matchesLoadedFilters(member, current);
    final next = [...withoutReplaced, if (matches) member]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    var totalCount = current.totalCount;
    var sundaySchoolCount = current.sundaySchoolCount;
    var meetingsCount = current.meetingsCount;
    if (isCreate && member.isActive) {
      totalCount += 1;
      if (member.scope == MemberScope.sundaySchoolClass) {
        sundaySchoolCount += 1;
      } else {
        meetingsCount += 1;
      }
    }
    emit(
      current.copyWith(
        allMembers: next,
        filteredMembers: next,
        flashMessage: flashMessage,
        totalCount: totalCount,
        sundaySchoolCount: sundaySchoolCount,
        meetingsCount: meetingsCount,
      ),
    );
  }

  Future<void> _ensurePermissions() async {
    if (_permissionsReady) {
      return;
    }
    final profile = await repository.getCurrentProfile();
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
      _manageClassIds = assignments[0]
          .where((a) => a['can_take_attendance'] as bool? ?? true)
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
      _manageMeetingIds = assignments[1]
          .where((a) => a['can_take_attendance'] as bool? ?? true)
          .map((a) => a['meeting_id'] as String)
          .toSet();
    } else {
      _viewClassIds = {};
      _viewMeetingIds = {};
      _manageClassIds = {};
      _manageMeetingIds = {};
    }
    _permissionsReady = true;
  }

  Future<MembersPage> _fetchPage({
    required int page,
    required String query,
    required String? classIdFilter,
    required String? meetingIdFilter,
    required String? scopeFilter,
  }) {
    return repository.getMembersPage(
      page: page,
      query: query,
      classId: classIdFilter,
      meetingId: meetingIdFilter,
      scope: scopeFilter == 'all' ? null : scopeFilter,
    );
  }

  MembersLoaded _stateFromPage(
    MembersPage page, {
    required String query,
    required String? classIdFilter,
    required String? meetingIdFilter,
    required String? scopeFilter,
    String? flashMessage,
    bool flashIsError = false,
    int? totalCount,
    int? sundaySchoolCount,
    int? meetingsCount,
  }) {
    final scoped = _scopeMembers(page.items);
    return MembersLoaded(
      allMembers: scoped,
      filteredMembers: scoped,
      query: query,
      classIdFilter: classIdFilter,
      meetingIdFilter: meetingIdFilter,
      scopeFilter: scopeFilter,
      flashMessage: flashMessage,
      flashIsError: flashIsError,
      hasMore: page.hasMore,
      page: page.page,
      totalCount: totalCount ?? page.counts.total,
      sundaySchoolCount: sundaySchoolCount ?? page.counts.sundaySchool,
      meetingsCount: meetingsCount ?? page.counts.meetings,
    );
  }

  void _ensureRealtimeSubscription() {
    _membersSubscription ??= repository.subscribeToMembers().listen((delta) {
      add(MembersRealtimeUpdated(delta));
    });
  }

  List<MemberEntity> _scopeMembers(List<MemberEntity> members) {
    if (_isAdmin) return members;
    return [
      for (final member in members)
        if (_canViewMember(member)) member,
    ];
  }

  bool _canViewMember(MemberEntity member) {
    if (_isAdmin) return true;
    return (member.sundaySchoolClassId != null &&
            _viewClassIds.contains(member.sundaySchoolClassId)) ||
        member.meetingIds.any(_viewMeetingIds.contains) ||
        (member.meetingId != null &&
            _viewMeetingIds.contains(member.meetingId));
  }

  bool _matchesLoadedFilters(MemberEntity member, MembersLoaded current) {
    return memberMatchesLocalQuery(
      member,
      query: current.query,
      meetingId: current.meetingIdFilter,
      classId: current.classIdFilter,
      scope: current.scopeFilter,
    );
  }

  List<MemberEntity> _mergeMembers(
    List<MemberEntity> existing,
    List<MemberEntity> incoming,
  ) {
    final byId = {for (final member in existing) member.id: member};
    for (final member in incoming) {
      byId[member.id] = member;
    }
    return byId.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<void> close() {
    unawaited(_membersSubscription?.cancel());
    return super.close();
  }
}
