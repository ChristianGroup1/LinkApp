import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/data/app_models.dart';

class MemberAttendanceHistoryScreen extends StatefulWidget {
  final MemberEntity member;
  final List<MemberAttendanceHistoryEntry> history;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;

  const MemberAttendanceHistoryScreen({
    super.key,
    required this.member,
    required this.history,
    required this.classes,
    required this.meetings,
  });

  @override
  State<MemberAttendanceHistoryScreen> createState() =>
      _MemberAttendanceHistoryScreenState();
}

class _MemberAttendanceHistoryScreenState
    extends State<MemberAttendanceHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'present', 'absent', 'excused'
  bool _sortNewestFirst = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MemberAttendanceHistoryEntry> get _filteredHistory {
    return widget.history.where((entry) {
      // 1. Status Filter
      if (_selectedStatusFilter == 'present' &&
          entry.status != AttendanceStatus.present) {
        return false;
      }
      if (_selectedStatusFilter == 'absent' &&
          entry.status != AttendanceStatus.absent) {
        return false;
      }
      if (_selectedStatusFilter == 'excused' &&
          entry.status != AttendanceStatus.excused) {
        return false;
      }

      // 2. Search Query (matches Register Name, Meeting Name, Class Name, or Notes)
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final meeting = widget.meetings
            .where((item) => item.id == entry.meetingId)
            .firstOrNull;
        final classEntity = widget.classes
            .where((item) => item.id == entry.classId)
            .firstOrNull;
        final destination = classEntity?.nameAr ?? meeting?.nameAr ?? 'اجتماع';
        final registerName = entry.sessionTitle?.trim().isNotEmpty == true
            ? entry.sessionTitle!
            : 'سجل $destination';

        final matchRegister = registerName.toLowerCase().contains(query);
        final matchDestination = destination.toLowerCase().contains(query);
        final matchNotes = entry.notes?.toLowerCase().contains(query) ?? false;
        final dateStr =
            '${entry.sessionDate.day}/${entry.sessionDate.month}/${entry.sessionDate.year}';
        final matchDate = dateStr.contains(query);

        if (!matchRegister &&
            !matchDestination &&
            !matchNotes &&
            !matchDate) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) => _sortNewestFirst
          ? b.sessionDate.compareTo(a.sessionDate)
          : a.sessionDate.compareTo(b.sessionDate));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.history.length;
    final presentCount = widget.history
        .where((e) => e.status == AttendanceStatus.present)
        .length;
    final absentCount = widget.history
        .where((e) => e.status == AttendanceStatus.absent)
        .length;
    final excusedCount = widget.history
        .where((e) => e.status == AttendanceStatus.excused)
        .length;
    final percentage = total == 0 ? 0 : (presentCount * 100 / total).round();

    final filtered = _filteredHistory;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          title: Column(
            children: [
              Text(
                'سجل حضور العضو',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                widget.member.fullName,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Top Summary Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatCard(
                          label: 'حضر',
                          value: '$presentCount',
                          color: AppTheme.secondary,
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatCard(
                          label: 'غاب',
                          value: '$absentCount',
                          color: AppTheme.accentRed,
                          icon: Icons.cancel_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatCard(
                          label: 'معتذر',
                          value: '$excusedCount',
                          color: AppTheme.accentOrange,
                          icon: Icons.info_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatCard(
                          label: 'النسبة',
                          value: '$percentage٪',
                          color: AppTheme.primary,
                          icon: Icons.pie_chart_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : presentCount / total,
                      minHeight: 6,
                      color: AppTheme.secondary,
                      backgroundColor: AppTheme.border,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  // Search Input
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.cairo(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم السجل، الاجتماع، التاريخ أو الملاحظات...',
                      hintStyle: GoogleFonts.cairo(
                        color: AppTheme.textLight.withValues(alpha: 0.7),
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppTheme.border.withValues(alpha: 0.8),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips & Sort Button Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل ($total)', 'all'),
                        const SizedBox(width: 6),
                        _buildFilterChip('حاضر ($presentCount)', 'present',
                            color: AppTheme.secondary),
                        const SizedBox(width: 6),
                        _buildFilterChip('غاب ($absentCount)', 'absent',
                            color: AppTheme.accentRed),
                        const SizedBox(width: 6),
                        _buildFilterChip('معتذر ($excusedCount)', 'excused',
                            color: AppTheme.accentOrange),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _sortNewestFirst = !_sortNewestFirst;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _sortNewestFirst
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortNewestFirst ? 'الأحدث' : 'الأقدم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Attendance List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 48,
                              color: AppTheme.textLight.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد سجلات حضور تطابق الفلتر أو البحث',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildAttendanceCard(filtered[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedStatusFilter == value;
    final activeColor = color ?? AppTheme.primary;

    return ChoiceChip(
      showCheckmark: false,
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatusFilter = value;
          });
        }
      },
      selectedColor: activeColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? activeColor
            : AppTheme.border.withValues(alpha: 0.9),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      label: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(MemberAttendanceHistoryEntry entry) {
    final statusDetails = switch (entry.status) {
      AttendanceStatus.present => (
          label: 'حاضر',
          icon: Icons.check_circle_rounded,
          color: AppTheme.secondary,
          bg: AppTheme.secondary.withValues(alpha: 0.08),
        ),
      AttendanceStatus.absent => (
          label: 'غائب',
          icon: Icons.cancel_rounded,
          color: AppTheme.accentRed,
          bg: AppTheme.accentRed.withValues(alpha: 0.08),
        ),
      AttendanceStatus.excused => (
          label: 'معتذر',
          icon: Icons.info_rounded,
          color: AppTheme.accentOrange,
          bg: AppTheme.accentOrange.withValues(alpha: 0.08),
        ),
    };

    final meeting = widget.meetings
        .where((item) => item.id == entry.meetingId)
        .firstOrNull;
    final classEntity = widget.classes
        .where((item) => item.id == entry.classId)
        .firstOrNull;
    final destination = classEntity?.nameAr ?? meeting?.nameAr ?? 'اجتماع';

    // Register name (اسم السجل)
    final registerName = entry.sessionTitle?.trim().isNotEmpty == true
        ? entry.sessionTitle!
        : 'سجل $destination';

    // Formatted date string
    final dt = entry.sessionDate;
    final dateFormatted =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    String dayName = '';
    try {
      dayName = intl.DateFormat('EEEE', 'ar').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusDetails.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusDetails.icon,
                  color: statusDetails.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Main Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Register Name (اسم السجل) - Primary Title
                    Text(
                      registerName,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Meeting / Class Name & Date Subtitle
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            destination,
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dayName.isNotEmpty ? '$dayName • $dateFormatted' : dateFormatted,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusDetails.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusDetails.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  statusDetails.label,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusDetails.color,
                  ),
                ),
              ),
            ],
          ),

          // Notes Section if present
          if (entry.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 15,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.notes!,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
