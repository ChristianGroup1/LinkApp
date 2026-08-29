import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../logic/home/home_bloc.dart';
import '../../../presentation/screens/app_tour_screen.dart';
import '../../../presentation/widgets/in_app_spotlight_overlay.dart';
import '../../../shared/ui/app_states.dart';
import '../../../shared/ui/app_widgets.dart';
import '../../attendance/presentation/attendance_records_screen.dart';
import '../../follow_up/presentation/follow_up_screen.dart';
import '../../meetings/presentation/meetings_list_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../logic/church_bloc.dart';
import 'servants_permissions_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onStartAttendance;
  final GlobalKey? meetingsKey;
  final GlobalKey? recordsKey;
  final GlobalKey? followUpKey;
  final GlobalKey? reportsKey;
  final GlobalKey? servantsKey;

  const DashboardScreen({
    super.key,
    required this.onStartAttendance,
    this.meetingsKey,
    this.recordsKey,
    this.followUpKey,
    this.reportsKey,
    this.servantsKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChurchBloc, ChurchState>(
      builder: (context, churchState) {
        if (churchState is ChurchError) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.accentRed,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        churchState.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.read<ChurchBloc>().add(LoadChurchContext()),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (churchState is! ChurchContextLoaded) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        final profile = churchState.profile;
        final church = churchState.church;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: SafeArea(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, homeState) {
                  if (homeState is HomeLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (homeState is HomeError) {
                    return AppErrorState(
                      message: homeState.message,
                      onRetry: () =>
                          context.read<HomeBloc>().add(LoadHomeData()),
                    );
                  }
                  if (homeState is! HomeLoaded) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadHomeData());
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Custom Header
                        AppWelcomeHeader(
                          greeting: 'أهلاً بك، ${profile.fullName}',
                          subtitle: church?.nameAr ?? 'منصة لينك للخدمة',
                        ),
                        const SizedBox(height: 14),

                        // Quick Stats Grid
                        _buildStatsGrid(homeState),
                        const SizedBox(height: 14),

                        // 1. الاجتماعات
                        _buildUpcomingMeetingsCard(homeState.upcomingMeetings),
                        const SizedBox(height: 18),

                        if (homeState.canTakeAttendance) ...[
                          _buildQuickActionCard(context),
                          const SizedBox(height: 18),
                        ],

                        if (homeState.canViewReports ||
                            homeState.canManageServants) ...[
                          KeyedSubtree(
                            key: meetingsKey,
                            child: _buildMeetingsEntryCard(context),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 2. سجلات الحضور
                        if (homeState.canTakeAttendance ||
                            homeState.canViewReports) ...[
                          KeyedSubtree(
                            key: recordsKey,
                            child: _buildRecordsEntryCard(context),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 3. متابعة الغياب
                        if (homeState.canViewReports) ...[
                          KeyedSubtree(
                            key: followUpKey,
                            child: _buildFollowUpEntryCard(context),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 4. التقارير والإحصائيات
                        if (homeState.canViewReports) ...[
                          KeyedSubtree(
                            key: reportsKey,
                            child: _buildReportsEntryCard(context),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 5. الخدام والصلاحيات
                        if (homeState.canManageServants) ...[
                          KeyedSubtree(
                            key: servantsKey,
                            child: _buildServantsRolesEntryCard(context),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 6. جولة في التطبيق 🚀
                        _buildAppTourEntryTile(context),
                        const SizedBox(height: 18),

                        if (!homeState.canTakeAttendance &&
                            !homeState.canViewReports &&
                            !homeState.canManageServants)
                          _buildNoAccessCard(),

                        // Absences Alerts
                        if (homeState.repeatedAbsences.isNotEmpty) ...[
                          _buildAbsenceAlertsCard(
                            context,
                            homeState.repeatedAbsences,
                          ),
                          const SizedBox(height: 18),
                        ],

                        if (homeState.upcomingBirthdays.isNotEmpty)
                          _buildBirthdaysCard(homeState.upcomingBirthdays),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(HomeLoaded state) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        AppStatCard(
          value: '${state.totalMembersCount}',
          label: 'إجمالي الأعضاء',
          icon: Icons.groups_rounded,
          color: AppTheme.primary,
        ),
        AppStatCard(
          value: '${state.presentCount}',
          label: 'الحضور الأخير',
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.secondary,
        ),
        AppStatCard(
          value: '${state.meetingsTodayCount}',
          label: 'اجتماعات اليوم',
          icon: Icons.event_rounded,
          color: AppTheme.accentOrange,
        ),
      ],
    );
  }

  Future<void> _openAndRefreshHome(BuildContext context, Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ChurchBloc>()),
            BlocProvider.value(value: context.read<HomeBloc>()),
          ],
          child: screen,
        ),
      ),
    );
    if (!context.mounted) return;
    context.read<HomeBloc>().add(LoadHomeData());
    context.read<ChurchBloc>().add(LoadChurchContext());
  }

  Widget _buildBirthdaysCard(List<BirthdayReminder> birthdays) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF7E6), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentOrange.withValues(alpha: 0.22),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: AppTheme.accentOrange,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أعياد الميلاد القادمة',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'خلال الثلاثين يومًا القادمة',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${birthdays.length}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...birthdays.take(4).map((birthday) {
            final dateLabel = intl.DateFormat(
              'd MMMM',
              'ar',
            ).format(birthday.nextBirthday);
            final timingLabel = birthday.daysUntil == 0
                ? 'اليوم 🎉'
                : birthday.daysUntil == 1
                ? 'غدًا'
                : 'بعد ${birthday.daysUntil} يوم';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentOrange.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.accentOrange.withValues(
                      alpha: 0.12,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: AppTheme.accentOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          birthday.member.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '$dateLabel • العمر القادم ${birthday.turningAge} سنة',
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: birthday.daysUntil == 0
                          ? AppTheme.secondary.withValues(alpha: 0.13)
                          : AppTheme.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      timingLabel,
                      style: GoogleFonts.cairo(
                        color: birthday.daysUntil == 0
                            ? AppTheme.secondary
                            : AppTheme.accentOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (birthdays.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: Text(
                  'و${birthdays.length - 4} أعياد ميلاد أخرى قريبًا',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMeetingsAndRefreshHome(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChurchBloc>(),
          child: const MeetingsListScreen(),
        ),
      ),
    );
    if (!context.mounted) return;
    context.read<HomeBloc>().add(LoadHomeData());
    context.read<ChurchBloc>().add(LoadChurchContext());
  }

  Widget _buildQuickActionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بدء التحضير الأسبوعي',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'سجل حضور الأعضاء اليوم بسرعة وسهولة.',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onStartAttendance,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Text(
                        'افتح كشف الحضور',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checklist_rtl_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTourEntryTile(BuildContext context) {
    return AppActionTile(
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'جولة في التطبيق 🚀',
      subtitle: 'الشرح التفاعلي والمباشر لكافة أقسام وأزرار الخدمة.',
      onTap: () async {
        await AppTourScreen.resetTourCompleted();
        if (context.mounted) {
          final tourNotifier = InAppTourNotifier.of(context);
          tourNotifier?.startTour();
        }
      },
    );
  }

  Widget _buildReportsEntryCard(BuildContext context) {
    return AppActionTile(
      icon: Icons.analytics_outlined,
      iconColor: AppTheme.secondary,
      title: 'التقارير والإحصائيات',
      subtitle: 'اعرف حضور وغياب كل شخص وأيام التسجيل.',
      onTap: () => _openAndRefreshHome(context, const ReportsScreen()),
    );
  }

  Widget _buildNoAccessCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appIconBadgeBackground(AppTheme.accentOrange),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لم يتم إسناد خدمة لك بعد',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اطلب من مسؤول الكنيسة إسناد فصل أو اجتماع لك من شاشة الخدام والصلاحيات.',
            style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsEntryCard(BuildContext context) {
    return AppActionTile(
      icon: Icons.fact_check_outlined,
      iconColor: AppTheme.accentSky,
      title: 'الاجتماعات',
      subtitle: 'أدر الاجتماعات والفصول التابعة لها.',
      onTap: () => _openMeetingsAndRefreshHome(context),
    );
  }

  Widget _buildRecordsEntryCard(BuildContext context) {
    return AppActionTile(
      icon: Icons.history_rounded,
      iconColor: AppTheme.primary,
      title: 'سجلات الحضور',
      subtitle: 'راجع الكشوفات السابقة وعدلها عند الحاجة.',
      onTap: () =>
          _openAndRefreshHome(context, const AttendanceRecordsScreen()),
    );
  }

  Widget _buildServantsRolesEntryCard(BuildContext context) {
    return AppActionTile(
      icon: Icons.admin_panel_settings_outlined,
      iconColor: AppTheme.accentPurple,
      title: 'الخدام والصلاحيات',
      subtitle: 'ادع خدام وحدد الدور والمجموعات وصلاحيات الحضور.',
      onTap: () =>
          _openAndRefreshHome(context, const ServantsPermissionsScreen()),
    );
  }

  Widget _buildFollowUpEntryCard(BuildContext context) {
    return AppActionTile(
      icon: Icons.support_agent_rounded,
      iconColor: AppTheme.accentOrange,
      title: 'متابعة الغياب',
      subtitle: 'سجل تواصل ومتابعة حتى بعد غياب مرة واحدة.',
      onTap: () => _openAndRefreshHome(context, const FollowUpScreen()),
    );
  }

  Widget _buildAbsenceAlertsCard(
    BuildContext context,
    List<Map<String, dynamic>> absences,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notification_important,
                color: AppTheme.accentRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تنبيهات المتابعة العاجلة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppTheme.accentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...absences.take(3).map((item) {
            final member = item['member'] as MemberEntity;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    member.fullName,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'غائب لأسبوعين متتاليين (${item['className']})',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUpcomingMeetingsCard(List<Map<String, dynamic>> upcoming) {
    final List<String> weekdaysAr = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final visibleMeetings = upcoming.take(3).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'القادم هذا الأسبوع',
            trailing: '${upcoming.length} اجتماع',
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.softShadow,
              ),
              child: Text(
                'لا توجد اجتماعات قادمة.',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleMeetings.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final mtg = visibleMeetings[index];
                  final date = mtg['date'] as DateTime;
                  final dayLabel = weekdaysAr[(mtg['weekday'] as int) - 1];
                  final dateStr = intl.DateFormat('d MMMM', 'ar').format(date);
                  final isToday = DateUtils.isSameDay(date, DateTime.now());

                  return Container(
                    width: 164,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.primary.withValues(alpha: 0.28)
                            : AppTheme.border,
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 16,
                              color: isToday
                                  ? AppTheme.primary
                                  : AppTheme.textLight,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                mtg['nameAr'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                isToday ? 'اليوم' : dayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: isToday
                                      ? AppTheme.primary
                                      : AppTheme.textLight,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dateStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
