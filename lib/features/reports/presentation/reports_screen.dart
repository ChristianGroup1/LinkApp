import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/connectivity_service.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/ui/offline_banner.dart';
import '../logic/reports_bloc.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportsBloc? _reportsBloc;
  final _searchController = TextEditingController();
  String _memberQuery = '';
  bool _offlineListenersAttached = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportsBloc ??= ReportsBloc(repository: context.read<DatabaseRepository>())
      ..add(LoadReportsData());

    if (!_offlineListenersAttached) {
      _offlineListenersAttached = true;
      unawaited(ConnectivityService.instance.ensureInitialized());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _reportsBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsBloc = _reportsBloc;
    if (reportsBloc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return BlocProvider.value(
      value: reportsBloc,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'التقارير والإحصائيات',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textLight,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'سجل الأعضاء'),
              Tab(text: 'نسب الاجتماعات'),
              Tab(text: 'المقارنة الشهرية'),
            ],
          ),
        ),
        body: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: ConnectivityService.instance.isOnline,
              builder: (context, online, _) {
                if (online) return const SizedBox.shrink();
                return const OfflineBanner();
              },
            ),
            Expanded(
              child: BlocBuilder<ReportsBloc, ReportsState>(
                builder: (context, state) {
                  if (state is ReportsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (state is ReportsError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: GoogleFonts.cairo(color: AppTheme.accentRed),
                      ),
                    );
                  }
                  if (state is! ReportsLoaded) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildYearlyMembersTab(state),
                      _buildMeetingsTab(state),
                      _buildMonthlyTab(state),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyMembersTab(ReportsLoaded state) {
    var filtered = state.memberStats;
    if (_memberQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (s) => (s['member'] as MemberEntity).fullName
                .toLowerCase()
                .contains(_memberQuery.toLowerCase()),
          )
          .toList();
    }

    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.cairo(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم لتصفية التقرير السنوي...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() => _memberQuery = val.trim());
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد بيانات للأعضاء',
                    style: GoogleFonts.cairo(),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final member = row['member'] as MemberEntity;
                    final pct = row['percentage'] as double;
                    final days =
                        row['days'] as List<MemberAttendanceDay>? ?? [];

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showMemberAttendanceDetails(
                        context,
                        member,
                        row,
                        days,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    member.fullName,
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getProgressColor(
                                      pct,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$pct%',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: _getProgressColor(pct),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الأسابيع المسجلة: ${row['recordedWeeks']}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    'حضور: ${row['presentWeeks']} • غياب: ${row['absentWeeks']} • استئذان: ${row['excusedWeeks']}',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(pct),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 5,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_note,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'اضغط لعرض أيام الحضور والغياب',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMeetingsTab(ReportsLoaded state) {
    final meetings = state.meetingStats;
    if (meetings.isEmpty) {
      return Center(
        child: Text(
          'لا توجد إحصائيات اجتماعات متوفرة.',
          style: GoogleFonts.cairo(color: AppTheme.textLight),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final row = meetings[index];
        final pct = row['percentage'] as double;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row['name'] as String,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'نوع الاجتماع: ${row['kind'] == MeetingKind.sundaySchool ? "اجتماع أسبوعي" : "اجتماع مباشر"} • الأعضاء: ${row['membersCount']}',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981),
                ),
                borderRadius: BorderRadius.circular(6),
                minHeight: 7,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyTab(ReportsLoaded state) {
    final months = state.monthlyStats;
    if (months.isEmpty) {
      return Center(
        child: Text(
          'لم يتم تسجيل حضور كافي لحساب المقارنة الشهرية.',
          style: GoogleFonts.cairo(color: AppTheme.textLight),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final row = months[index];
        final pct = row['percentage'] as double;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['month'] as String,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'إجمالي الحضور: ${row['presentCount']} من ${row['totalCount']} فرصة تحضير',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  void _showMemberAttendanceDetails(
    BuildContext context,
    MemberEntity member,
    Map<String, dynamic> row,
    List<MemberAttendanceDay> days,
  ) {
    final presentDays = days
        .where((day) => day.status == AttendanceStatus.present)
        .toList();
    final absentDays = days
        .where((day) => day.status == AttendanceStatus.absent)
        .toList();
    final excusedDays = days
        .where((day) => day.status == AttendanceStatus.excused)
        .toList();
    final recordedWeeks = days.isNotEmpty
        ? days.length
        : row['recordedWeeks'] as int;
    final presentWeeks = days.isNotEmpty
        ? presentDays.length
        : row['presentWeeks'] as int;
    final absentWeeks = days.isNotEmpty
        ? absentDays.length
        : row['absentWeeks'] as int;
    final excusedWeeks = days.isNotEmpty
        ? excusedDays.length
        : row['excusedWeeks'] as int;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    member.fullName,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إجمالي التسجيلات: $recordedWeeks',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountTile(
                          'حضور',
                          presentWeeks,
                          AppTheme.secondary,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCountTile(
                          'غياب',
                          absentWeeks,
                          AppTheme.accentRed,
                          Icons.cancel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCountTile(
                          'استئذان',
                          excusedWeeks,
                          AppTheme.accentOrange,
                          Icons.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (days.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Text(
                          'لا توجد أيام مسجلة لهذا العضو.',
                          style: GoogleFonts.cairo(color: AppTheme.textLight),
                        ),
                      ),
                    )
                  else ...[
                    _buildDaysSection('أيام الحضور', presentDays),
                    _buildDaysSection('أيام الغياب', absentDays),
                    _buildDaysSection('أيام الاستئذان', excusedDays),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCountTile(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSection(String title, List<MemberAttendanceDay> days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            '$title (${days.length})',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
        ),
        if (days.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'لا يوجد',
              style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textLight),
            ),
          )
        else
          ...days.map(_buildDayRow),
      ],
    );
  }

  Widget _buildDayRow(MemberAttendanceDay day) {
    final color = _statusColor(day.status);
    final dateLabel = intl.DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(day.date);
    final targetLabel = day.className == null
        ? day.meetingName
        : '${day.meetingName} • ${day.className}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$targetLabel • الأسبوع ${day.weekNumber}',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
                if (day.title != null && day.title!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    day.title!,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _statusLabel(day.status),
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppTheme.secondary;
      case AttendanceStatus.absent:
        return AppTheme.accentRed;
      case AttendanceStatus.excused:
        return AppTheme.accentOrange;
    }
  }

  String _statusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'حضور';
      case AttendanceStatus.absent:
        return 'غياب';
      case AttendanceStatus.excused:
        return 'مستأذن';
    }
  }
}
