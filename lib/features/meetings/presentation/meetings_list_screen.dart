import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/app_states.dart';
import '../../church/logic/church_bloc.dart';
import '../logic/meetings_bloc.dart';
import 'add_edit_meeting_screen.dart';
import 'widgets/class_card.dart';
import 'widgets/meeting_assignment_helpers.dart';
import 'widgets/meeting_card.dart';
import 'widgets/meeting_dialogs.dart';

class MeetingsListScreen extends StatefulWidget {
  const MeetingsListScreen({super.key});

  @override
  State<MeetingsListScreen> createState() => _MeetingsListScreenState();
}

class _MeetingsListScreenState extends State<MeetingsListScreen>
    with RouteAware {
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
                backgroundColor: AppTheme.cardBackground,
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
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FloatingActionButton.extended(
                        onPressed: () => showAddMeetingScreen(
                          context,
                          meetingsBloc: meetingsBloc,
                        ),
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        highlightElevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          'إضافة اجتماع',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
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

class _SundaySchoolTab extends StatefulWidget {
  final AppProfile profile;
  final bool isAdmin;

  const _SundaySchoolTab({required this.profile, required this.isAdmin});

  @override
  State<_SundaySchoolTab> createState() => _SundaySchoolTabState();
}

class _SundaySchoolTabState extends State<_SundaySchoolTab> {
  final TextEditingController _searchController = TextEditingController();
  int?
  _selectedWeekday; // null = all, 7 = Sun, 5 = Fri, 6 = Sat, 4 = Thu, 3 = Wed, 2 = Tue, 1 = Mon

  final List<Map<String, dynamic>> _weekdayFilters = const [
    {'label': 'الكل', 'value': null},
    {'label': 'الأحد', 'value': 7},
    {'label': 'الجمعة', 'value': 5},
    {'label': 'السبت', 'value': 6},
    {'label': 'الخميس', 'value': 4},
    {'label': 'الأربعاء', 'value': 3},
    {'label': 'الثلاثاء', 'value': 2},
    {'label': 'الإثنين', 'value': 1},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        if (!widget.isAdmin) {
          for (final entry in state.meetingAssignmentsById.entries) {
            if (entry.value.any(
              (assignment) =>
                  assignment['user_id'] == widget.profile.id &&
                  ((assignment['can_take_attendance'] as bool? ?? true) ||
                      (assignment['can_view_reports'] as bool? ?? true)),
            )) {
              visibleMeetingIds.add(entry.key);
            }
          }
          for (final entry in state.classAssignmentsById.entries) {
            if (entry.value.any(
              (assignment) =>
                  assignment['user_id'] == widget.profile.id &&
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
                  (widget.isAdmin ||
                      visibleClassIds.contains(c.id) ||
                      visibleMeetingIds.contains(c.meetingId)),
            )
            .toList();
        final visibleGroupedMeetingIds = visibleClasses
            .map((c) => c.meetingId)
            .toSet();
        final allVisibleMeetings =
            state.meetings
                .where(
                  (m) =>
                      m.isActive &&
                      (widget.isAdmin ||
                          visibleMeetingIds.contains(m.id) ||
                          (m.kind == MeetingKind.sundaySchool &&
                              visibleGroupedMeetingIds.contains(m.id))),
                )
                .toList()
              ..sort((a, b) => a.nameAr.compareTo(b.nameAr));

        // Filter based on search query & weekday
        final searchQuery = _searchController.text.trim().toLowerCase();
        final filteredMeetings = allVisibleMeetings.where((m) {
          final matchesWeekday =
              _selectedWeekday == null || m.weekday == _selectedWeekday;
          if (!matchesWeekday) return false;

          if (searchQuery.isEmpty) return true;

          final nameMatch = m.nameAr.toLowerCase().contains(searchQuery);
          final descMatch =
              m.description?.toLowerCase().contains(searchQuery) ?? false;
          final classMatch = visibleClasses.any(
            (c) =>
                c.meetingId == m.id &&
                (c.nameAr.toLowerCase().contains(searchQuery) ||
                    c.name.toLowerCase().contains(searchQuery)),
          );

          return nameMatch || descMatch || classMatch;
        }).toList();

        // Calculate summary stats
        final totalMeetings = allVisibleMeetings.length;
        final totalClasses = visibleClasses.length;

        // Count total active unique servants assigned across meetings and classes
        final uniqueServants = <String>{};
        for (final assignList in state.meetingAssignmentsById.values) {
          for (final a in assignList) {
            final uid = a['user_id'] as String?;
            if (uid != null) uniqueServants.add(uid);
          }
        }
        for (final assignList in state.classAssignmentsById.values) {
          for (final a in assignList) {
            final uid = a['user_id'] as String?;
            if (uid != null) uniqueServants.add(uid);
          }
        }
        final totalServantsCount = uniqueServants.length;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<MeetingsBloc>().add(LoadMeetingsAndClasses());
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Summary Card & Search/Filter Controls
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    children: [
                      // Modern Stats Header Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4338CA), // Deep Indigo
                              AppTheme.primary,
                              Color(0xFF6366F1), // Indigo Accent
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              icon: Icons.groups_rounded,
                              label: 'الاجتماعات',
                              value: '$totalMeetings',
                            ),
                            Container(
                              height: 38,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            _StatItem(
                              icon: Icons.meeting_room_rounded,
                              label: 'الفصول',
                              value: '$totalClasses',
                            ),
                            Container(
                              height: 38,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            _StatItem(
                              icon: Icons.badge_rounded,
                              label: 'الخدام المعينين',
                              value: '$totalServantsCount',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Search Bar Input
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.cairo(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم الاجتماع أو الفصل...',
                          hintStyle: GoogleFonts.cairo(
                            color: AppTheme.textLight.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppTheme.textLight,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.cardBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppTheme.border.withValues(alpha: 0.8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppTheme.border.withValues(alpha: 0.8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Weekday Filter Chips Horizontal Scroll
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _weekdayFilters.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = _weekdayFilters[index];
                            final label = filter['label'] as String;
                            final value = filter['value'] as int?;
                            final isSelected = _selectedWeekday == value;

                            return ChoiceChip(
                              showCheckmark: false,
                              label: Text(
                                label,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedWeekday = value;
                                });
                              },
                              selectedColor: AppTheme.primary,
                              backgroundColor: AppTheme.cardBackground,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.border.withValues(alpha: 0.8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Meetings List or Empty State
              if (filteredMeetings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppEmptyState(
                      icon: Icons.groups_outlined,
                      message:
                          _searchController.text.isNotEmpty ||
                              _selectedWeekday != null
                          ? 'لا توجد نتائج تطابق خيارات البحث'
                          : 'لا توجد اجتماعات حالياً',
                      actionLabel:
                          widget.isAdmin &&
                              _searchController.text.isEmpty &&
                              _selectedWeekday == null
                          ? 'إضافة اجتماع جديد'
                          : null,
                      onAction: widget.isAdmin
                          ? () => showAddMeetingScreen(
                              context,
                              meetingsBloc: context.read<MeetingsBloc>(),
                            )
                          : null,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final meeting = filteredMeetings[index];
                      if (meeting.kind == MeetingKind.sundaySchool) {
                        final classes = visibleClasses
                            .where((c) => c.meetingId == meeting.id)
                            .toList();
                        return GroupedMeetingClassesCard(
                          meeting: meeting,
                          classes: classes,
                          isAdmin: widget.isAdmin,
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
                        isAdmin: widget.isAdmin,
                        assignments:
                            state.meetingAssignmentsById[meeting.id] ?? [],
                        pendingInvitations: pendingInvitesForMeeting(
                          state.pendingInvitations,
                          meeting.id,
                        ),
                      );
                    }, childCount: filteredMeetings.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
