import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/app_states.dart';
import '../logic/meetings_bloc.dart';
import '../../church/logic/church_bloc.dart';
import 'widgets/meeting_dialogs.dart';
import 'add_edit_meeting_screen.dart';
import 'widgets/meeting_card.dart';
import 'widgets/class_card.dart';
import 'widgets/meeting_assignment_helpers.dart';

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen> with RouteAware {
  MeetingsBloc? _meetingsBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
    _meetingsBloc ??= MeetingsBloc(
      repository: context.read<DatabaseRepository>(),
    )..add(LoadMeetingsAndClasses());
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _meetingsBloc?.close();
    super.dispose();
  }

  @override
  void didPopNext() {
    _meetingsBloc?.add(LoadMeetingsAndClasses());
  }

  @override
  Widget build(BuildContext context) {
    final meetingsBloc = _meetingsBloc;
    if (meetingsBloc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return BlocProvider.value(
      value: meetingsBloc,
      child: BlocListener<MeetingsBloc, MeetingsState>(
        listenWhen: (previous, current) =>
            current is MeetingsLoaded && current.flashMessage != null,
        listener: (context, state) {
          if (state is! MeetingsLoaded || state.flashMessage == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.flashMessage!, style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
          context.read<MeetingsBloc>().add(ClearMeetingsFlashMessage());
        },
        child: BlocBuilder<ChurchBloc, ChurchState>(
          builder: (context, churchState) {
            if (churchState is! ChurchContextLoaded) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }

            final profile = churchState.profile;
            final isAdmin =
                profile.role == AppRole.superAdmin ||
                profile.role == AppRole.churchAdmin;

            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'الاجتماعات',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                    height: 1,
                    color: AppTheme.border.withValues(alpha: 0.7),
                  ),
                ),
              ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton.extended(
                      onPressed: () => showAddMeetingScreen(
                        context,
                        meetingsBloc: meetingsBloc,
                      ),
                      backgroundColor: AppTheme.primary,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'إضافة اجتماع',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                      ),
                    )
                  : null,
              body: _SundaySchoolTab(profile: profile, isAdmin: isAdmin),
            );
          },
        ),
      ),
    );
  }
}

class _SundaySchoolTab extends StatelessWidget {
  final AppProfile profile;
  final bool isAdmin;

  const _SundaySchoolTab({required this.profile, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeetingsBloc, MeetingsState>(
      builder: (context, state) {
        if (state is MeetingsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }
        if (state is MeetingsError) {
          return AppErrorState(
            message: state.message,
            onRetry: () =>
                context.read<MeetingsBloc>().add(LoadMeetingsAndClasses()),
          );
        }
        if (state is! MeetingsLoaded) {
          return const AppEmptyState(
            icon: Icons.event_busy_outlined,
            message: 'لا توجد بيانات متاحة',
          );
        }

        final visibleMeetingIds = <String>{};
        final visibleClassIds = <String>{};
        if (!isAdmin) {
          for (final entry in state.meetingAssignmentsById.entries) {
            if (entry.value.any(
              (assignment) =>
                  assignment['user_id'] == profile.id &&
                  ((assignment['can_take_attendance'] as bool? ?? true) ||
                      (assignment['can_view_reports'] as bool? ?? true)),
            )) {
              visibleMeetingIds.add(entry.key);
            }
          }
          for (final entry in state.classAssignmentsById.entries) {
            if (entry.value.any(
              (assignment) =>
                  assignment['user_id'] == profile.id &&
                  ((assignment['can_take_attendance'] as bool? ?? true) ||
                      (assignment['can_view_reports'] as bool? ?? true)),
            )) {
              visibleClassIds.add(entry.key);
            }
          }
        }

        final visibleClasses = state.classes
            .where(
              (c) =>
                  c.isActive &&
                  (isAdmin ||
                      visibleClassIds.contains(c.id) ||
                      visibleMeetingIds.contains(c.meetingId)),
            )
            .toList();
        final visibleGroupedMeetingIds = visibleClasses
            .map((c) => c.meetingId)
            .toSet();
        final visibleMeetings = state.meetings
            .where(
              (m) =>
                  m.isActive &&
                  (isAdmin ||
                      visibleMeetingIds.contains(m.id) ||
                      (m.kind == MeetingKind.sundaySchool &&
                          visibleGroupedMeetingIds.contains(m.id))),
            )
            .toList()
          ..sort((a, b) => a.nameAr.compareTo(b.nameAr));

        return RefreshIndicator(
          onRefresh: () async {
            context.read<MeetingsBloc>().add(LoadMeetingsAndClasses());
          },
          child: visibleMeetings.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    AppEmptyState(
                      icon: Icons.groups_outlined,
                      message: 'لا توجد اجتماعات حالياً',
                      actionLabel: isAdmin ? 'إضافة اجتماع جديد' : null,
                      onAction: isAdmin
                          ? () => showAddMeetingScreen(
                              context,
                              meetingsBloc: context.read<MeetingsBloc>(),
                            )
                          : null,
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  itemCount: visibleMeetings.length,
                  itemBuilder: (context, index) {
                    final meeting = visibleMeetings[index];
                    if (meeting.kind == MeetingKind.sundaySchool) {
                      final classes = visibleClasses
                          .where((c) => c.meetingId == meeting.id)
                          .toList();
                      return GroupedMeetingClassesCard(
                        meeting: meeting,
                        classes: classes,
                        isAdmin: isAdmin,
                        classAssignmentsById: state.classAssignmentsById,
                        pendingInvitations: state.pendingInvitations,
                        onAddClass: () =>
                            showAddClassDialog(context, meeting.id),
                        onEditMeeting: () =>
                            showEditMeetingScreen(context, meeting),
                        onDeleteMeeting: () =>
                            showConfirmDeleteMeeting(context, meeting),
                      );
                    }

                    return MeetingCard(
                      meeting: meeting,
                      isAdmin: isAdmin,
                      assignments:
                          state.meetingAssignmentsById[meeting.id] ?? [],
                      pendingInvitations: pendingInvitesForMeeting(
                        state.pendingInvitations,
                        meeting.id,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
