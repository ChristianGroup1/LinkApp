import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/notifications/meeting_reminder_service.dart';
import '../../data/repositories/database_repository.dart';
import '../../features/church/logic/church_bloc.dart';
import '../../features/church/presentation/dashboard_screen.dart';
import '../../features/attendance/presentation/weekly_attendance_screen.dart';
import '../../features/members/presentation/members_list_screen.dart';
import '../../features/church/presentation/settings_screen.dart';
import '../../logic/home/home_bloc.dart';
import '../../data/offline/connectivity_service.dart';
import '../../shared/ui/bubble_bottom_nav.dart';
import '../../shared/ui/offline_banner.dart';
import '../../shared/ui/tab_navigator.dart';
import '../../shared/data/app_data_changes.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  final List<int> _refreshTokens = [0, 0, 0, 0];
  final List<Widget?> _tabBodies = List<Widget?>.filled(4, null);
  late final HomeBloc _homeBloc;
  late final ChurchBloc _churchBloc;
  bool _blocsInitialized = false;
  bool _offlineListenersAttached = false;
  bool _hasPendingSync = false;
  StreamSubscription<AppDataChange>? _dataChangeSubscription;
  Timer? _dataChangeDebounce;
  final Set<AppDataArea> _pendingDataAreas = {};

  static const _navItems = [
    BubbleNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'الرئيسية',
      bubbleColor: AppTheme.primary,
    ),
    BubbleNavItem(
      icon: Icons.checklist_rtl_outlined,
      activeIcon: Icons.checklist_rounded,
      label: 'الحضور',
      bubbleColor: AppTheme.primary,
    ),
    BubbleNavItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
      label: 'الأعضاء',
      bubbleColor: AppTheme.primary,
    ),
    BubbleNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'الإعدادات',
      bubbleColor: AppTheme.primary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _appLifecycleObserver = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          if (_blocsInitialized) {
            _homeBloc.add(LoadHomeData());
            _churchBloc.add(LoadChurchContext());
          }
          unawaited(
            MeetingReminderService.instance.syncForCurrentUser(
              context.read<DatabaseRepository>(),
            ),
          );
        }
      },
    );
  }

  late final AppLifecycleListener _appLifecycleObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_blocsInitialized) {
      _blocsInitialized = true;
      final dbRepo = context.read<DatabaseRepository>();
      _churchBloc = ChurchBloc(repository: dbRepo)..add(LoadChurchContext());
      _homeBloc = HomeBloc(repository: dbRepo)..add(LoadHomeData());
      _dataChangeSubscription = AppDataChanges.instance.stream.listen(
        _onAppDataChanged,
      );
      _ensureTabBuilt(0);
      unawaited(MeetingReminderService.instance.syncForCurrentUser(dbRepo));
    }

    if (!_offlineListenersAttached) {
      _offlineListenersAttached = true;
      unawaited(ConnectivityService.instance.ensureInitialized());
      ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
      unawaited(_loadPendingSyncState());
    }
  }

  Future<void> _loadPendingSyncState() async {
    final pending = await context
        .read<DatabaseRepository>()
        .hasPendingOfflineData();
    if (mounted) {
      setState(() => _hasPendingSync = pending);
    }
  }

  void _onConnectivityChanged() {
    unawaited(_loadPendingSyncState());
  }

  void _onAppDataChanged(AppDataChange change) {
    _pendingDataAreas.addAll(change.areas);
    _dataChangeDebounce?.cancel();
    _dataChangeDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final areas = Set<AppDataArea>.of(_pendingDataAreas);
      _pendingDataAreas.clear();
      unawaited(_loadPendingSyncState());

      const homeAreas = {
        AppDataArea.profile,
        AppDataArea.church,
        AppDataArea.meetings,
        AppDataArea.classes,
        AppDataArea.members,
        AppDataArea.assignments,
        AppDataArea.attendance,
      };
      const churchAreas = {
        AppDataArea.profile,
        AppDataArea.church,
        AppDataArea.assignments,
        AppDataArea.invitations,
      };

      if (areas.any(homeAreas.contains)) _homeBloc.add(LoadHomeData());
      if (areas.any(churchAreas.contains)) {
        _churchBloc.add(LoadChurchContext());
      }

      setState(() {
        for (final index in _tabsAffectedBy(areas)) {
          if (index == _currentIndex) continue;
          _refreshTokens[index]++;
          _tabBodies[index] = null;
        }
      });
    });
  }

  Set<int> _tabsAffectedBy(Set<AppDataArea> areas) {
    final tabs = <int>{};
    if (areas.any(
      {
        AppDataArea.meetings,
        AppDataArea.classes,
        AppDataArea.members,
        AppDataArea.assignments,
        AppDataArea.attendance,
      }.contains,
    )) {
      tabs.add(1);
    }
    if (areas.any(
      {AppDataArea.meetings, AppDataArea.classes, AppDataArea.members}.contains,
    )) {
      tabs.add(2);
    }
    if (areas.any(
      {
        AppDataArea.profile,
        AppDataArea.church,
        AppDataArea.meetings,
        AppDataArea.classes,
        AppDataArea.assignments,
        AppDataArea.invitations,
      }.contains,
    )) {
      tabs.add(3);
    }
    return tabs;
  }

  @override
  void dispose() {
    _appLifecycleObserver.dispose();
    _dataChangeDebounce?.cancel();
    _dataChangeSubscription?.cancel();
    ConnectivityService.instance.isOnline.removeListener(
      _onConnectivityChanged,
    );
    _homeBloc.close();
    _churchBloc.close();
    super.dispose();
  }

  void _selectTab(int index) {
    final sameTab = _currentIndex == index;
    if (sameTab) {
      _refreshTokens[index]++;
      _tabBodies[index] = null;
    }
    setState(() {
      _currentIndex = index;
      _ensureTabBuilt(index);
    });
    if (index == 0) {
      _homeBloc.add(LoadHomeData());
      _churchBloc.add(LoadChurchContext());
    }
  }

  Widget _rootForIndex(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(onStartAttendance: () => _selectTab(1));
      case 1:
        return const WeeklyAttendanceScreen();
      case 2:
        return const MembersListScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _ensureTabBuilt(int index) {
    _tabBodies[index] ??= RepaintBoundary(
      child: TabNavigator(
        key: ValueKey('tab_$index'),
        refreshToken: _refreshTokens[index],
        root: _rootForIndex(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _churchBloc),
        BlocProvider.value(value: _homeBloc),
      ],
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: ConnectivityService.instance.isOnline,
                builder: (context, online, _) {
                  if (online) return const SizedBox.shrink();
                  return OfflineBanner(hasPendingSync: _hasPendingSync);
                },
              ),
              Expanded(
                child: _tabBodies[_currentIndex] ?? const SizedBox.shrink(),
              ),
            ],
          ),
          bottomNavigationBar: AppBubbleBottomBar(
            currentIndex: _currentIndex,
            onTap: _selectTab,
            items: _navItems,
          ),
        ),
      ),
    );
  }
}
