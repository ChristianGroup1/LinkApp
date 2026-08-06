import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/in_app_spotlight_overlay.dart';
import 'app_tour_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/notifications/meeting_reminder_service.dart';
import '../../features/attendance/logic/auto_attendance_session_service.dart';
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
  static final GlobalKey<State<MainNavigationWrapper>> wrapperKey =
      GlobalKey<State<MainNavigationWrapper>>();

  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    _selectTab(index);
  }

  bool _showInAppTour = false;
  int _inAppTourStep = 0;

  final GlobalKey _meetingsKey = GlobalKey();
  final GlobalKey _recordsKey = GlobalKey();
  final GlobalKey _followUpKey = GlobalKey();
  final GlobalKey _reportsKey = GlobalKey();
  final GlobalKey _servantsKey = GlobalKey();
  final List<int> _refreshTokens = [0, 0, 0, 0];
  final List<Widget?> _tabBodies = List<Widget?>.filled(4, null);
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;
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
      unawaited(
        AutoAttendanceSessionService.instance.autoCreateSessionsOneDayInAdvance(
          dbRepo,
        ),
      );
      unawaited(_checkPendingReceivedInvitations());
      unawaited(_checkFirstLaunchAppTour());
    }

    if (!_offlineListenersAttached) {
      _offlineListenersAttached = true;
      unawaited(ConnectivityService.instance.ensureInitialized());
      ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
      unawaited(_loadPendingSyncState());
    }
  }

  Future<void> _checkFirstLaunchAppTour() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.profile.id : null;
    final completed = await AppTourScreen.isTourCompleted(userId: userId);
    if (!completed && mounted) {
      setState(() {
        _showInAppTour = true;
        _inAppTourStep = 0;
        _selectTab(0);
      });
    }
  }

  Future<void> _checkPendingReceivedInvitations() async {
    try {
      final dbRepo = context.read<DatabaseRepository>();
      final invitations = await dbRepo.getUserReceivedInvitations();
      final pendingList = invitations.where((i) {
        final isUsed = i['is_used'] == true;
        final isDeclined = i['declined_at'] != null;
        return !isUsed && !isDeclined;
      }).toList();

      if (pendingList.isNotEmpty && mounted) {
        final firstInvite = pendingList.first;
        final churchMap = firstInvite['churches'] as Map?;
        final churchName =
            churchMap?['name_ar'] ?? churchMap?['name'] ?? 'الكنيسة';
        final token = firstInvite['invite_token'] as String? ?? '';
        final scope = firstInvite['assignment_scope'] as String?;

        await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: Color(0xFF2563EB),
                  size: 36,
                ),
              ),
              title: Text(
                'دعوة خادم جديدة 🚀',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تمت دعوتك للانضمام للخدمة في $churchName',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      height: 1.5,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (scope != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'نطاق الخدمة: $scope',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton.icon(
                  onPressed: () async {
                    final authBloc = context.read<AuthBloc>();
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await dbRepo.acceptInvitationLink(token);
                    if (mounted) {
                      authBloc.add(AuthCheckRequested());
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم قبول الدعوة بنجاح 🎉',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    'قبول الدعوة 🚀',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await dbRepo.declineInvitationByToken(token);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم رفض الدعوة',
                            style: GoogleFonts.cairo(),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'رفض',
                    style: GoogleFonts.cairo(color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
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
    } else {
      _tabHistory.remove(index);
      _tabHistory.add(index);
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

  Future<void> _handleBackPress() async {
    final currentNav = _navigatorKeys[_currentIndex].currentState;
    if (currentNav != null && currentNav.canPop()) {
      currentNav.pop();
      return;
    }

    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        final prevTab = _tabHistory.last;
        _currentIndex = prevTab;
        _ensureTabBuilt(prevTab);
      });
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اضغط مرة أخرى للخروج من التطبيق 🚪',
            style: GoogleFonts.cairo(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    await SystemNavigator.pop();
  }

  void _startInAppTour() {
    setState(() {
      _showInAppTour = true;
      _inAppTourStep = 0;
      _selectTab(0);
    });
  }

  List<SpotlightTargetData> get _spotlightSteps => [
    const SpotlightTargetData(
      title: 'الشاشة الرئيسية 💒',
      description:
          'شاشتك الرئيسية التي تجد فيها كافة أدوات وملخصات وإحصائيات الخدمة.',
      navIndex: 0,
      icon: Icons.home_rounded,
    ),
    const SpotlightTargetData(
      title: 'تسجيل وتغطية الحضور 📋',
      description:
          'اضغط هنا لبدء التقاط غياب وحضور الأعضاء والخدام في الاجتماعات والفصول بسهولة.',
      navIndex: 1,
      icon: Icons.checklist_rounded,
    ),
    const SpotlightTargetData(
      title: 'قائمة الأعضاء والخدام 👥',
      description:
          'إدارة قوائم المخدومين، إضافة أعضاء جدد، ودعوة الخدام وتحديد أدوارهم.',
      navIndex: 2,
      icon: Icons.groups_rounded,
    ),
    const SpotlightTargetData(
      title: 'الإعدادات والدعوات ⚙️',
      description:
          'بياناتك الشخصية، الدعوات الواردة من الكنائس والخدمات، وتفضيلات الحساب.',
      navIndex: 3,
      icon: Icons.person_rounded,
    ),
    SpotlightTargetData(
      title: '١. قسم الاجتماعات 📅',
      description:
          'أدر وتصفح جميع الاجتماعات والفصول التابعة لها واعرف مواعيد الحضور المباشرة.',
      key: _meetingsKey,
      icon: Icons.event_rounded,
    ),
    SpotlightTargetData(
      title: '٢. سجلات الحضور 📖',
      description:
          'تصفح وراجع كشوفات ومحاضر الحضور السابقة وعدّلها عند الحاجة بسهولة.',
      key: _recordsKey,
      icon: Icons.history_rounded,
    ),
    SpotlightTargetData(
      title: '٣. متابعة الغياب 📞',
      description:
          'سجل متابعة وافتقاد الأعضاء الغائبين واحتفظ بتفاصيل التواصل أولاً بأول.',
      key: _followUpKey,
      icon: Icons.support_agent_rounded,
    ),
    SpotlightTargetData(
      title: '٤. التقارير والإحصائيات 📊',
      description:
          'اعرف نسب حضور كل مخدوم وخادم ومعدلات الالتزام وأيام التسجيل بنظرة واحدة.',
      key: _reportsKey,
      icon: Icons.analytics_outlined,
    ),
    SpotlightTargetData(
      title: '٥. الخدام والصلاحيات 🛡️',
      description:
          'ادع خدام جدد لخدمتك، حدد أدوارهم في المجموعات والفصول، وإدارة صلاحيات الحضور.',
      key: _servantsKey,
      icon: Icons.admin_panel_settings_outlined,
    ),
  ];

  Widget _rootForIndex(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          onStartAttendance: () => _selectTab(1),
          meetingsKey: _meetingsKey,
          recordsKey: _recordsKey,
          followUpKey: _followUpKey,
          reportsKey: _reportsKey,
          servantsKey: _servantsKey,
        );
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
        navigatorKey: _navigatorKeys[index],
        refreshToken: _refreshTokens[index],
        root: _rootForIndex(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InAppTourNotifier(
      startTour: _startInAppTour,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _churchBloc),
          BlocProvider.value(value: _homeBloc),
        ],
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  await _handleBackPress();
                },
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
                        child:
                            _tabBodies[_currentIndex] ??
                            const SizedBox.shrink(),
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
              if (_showInAppTour)
                InAppSpotlightOverlay(
                  currentStep: _inAppTourStep,
                  steps: _spotlightSteps,
                  onStepChanged: (step) {
                    setState(() {
                      _inAppTourStep = step;
                      if (step < 4) {
                        _selectTab(step);
                      } else {
                        _selectTab(0);
                      }
                    });
                  },
                  onDismiss: () async {
                    final authState = context.read<AuthBloc>().state;
                    final userId = authState is AuthAuthenticated
                        ? authState.profile.id
                        : null;
                    await AppTourScreen.setTourCompleted(userId: userId);
                    if (mounted) {
                      setState(() {
                        _showInAppTour = false;
                        _selectTab(0);
                      });
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
