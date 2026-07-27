import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

String sessionTitle(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return 'كشف حضور $day/$month/${date.year}';
}

Future<DateTime?> pickAttendanceDate(
  BuildContext context, {
  required int? meetingWeekday,
  List<AttendanceSessionEntity> existingSessions = const [],
}) async {
  final now = DateTime.now();
  var visibleMonth = DateTime(now.year, now.month);
  final today = DateTime(now.year, now.month, now.day);
  final weekdays = const ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
  final monthNames = const [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final firstOfMonth =
                DateTime(visibleMonth.year, visibleMonth.month);
            final daysInMonth =
                DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
            final leadingEmptyDays = firstOfMonth.weekday - 1;

            return AlertDialog(
              title: Text(
                'اختار تاريخ تسجيل الغياب',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              visibleMonth = DateTime(
                                visibleMonth.year,
                                visibleMonth.month - 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                        Text(
                          '${monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              visibleMonth = DateTime(
                                visibleMonth.year,
                                visibleMonth.month + 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final weekday in weekdays)
                          Center(
                            child: Text(
                              weekday,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                        for (var i = 0; i < leadingEmptyDays; i++)
                          const SizedBox.shrink(),
                        for (var day = 1; day <= daysInMonth; day++)
                          Builder(
                            builder: (context) {
                              final date = DateTime(
                                visibleMonth.year,
                                visibleMonth.month,
                                day,
                              );
                              final isMeetingDay =
                                  meetingWeekday != null &&
                                  date.weekday == meetingWeekday;
                              final isToday =
                                  date.year == today.year &&
                                  date.month == today.month &&
                                  date.day == today.day;
                              final isFuture = date.isAfter(today);
                              final hasSession = existingSessions.any(
                                (s) =>
                                    s.sessionDate.year == date.year &&
                                    s.sessionDate.month == date.month &&
                                    s.sessionDate.day == date.day,
                              );

                              return Padding(
                                padding: const EdgeInsets.all(3),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    if (isFuture) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'لا يمكن إنشاء كشف لتاريخ مستقبلي',
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: AppTheme.accentRed,
                                          duration:
                                              const Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    if (hasSession) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'يوجد كشف مسبقاً لهذا اليوم',
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: AppTheme.accentRed,
                                          duration:
                                              const Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(dialogContext, date);
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: hasSession
                                          ? Colors.green.withOpacity(0.2)
                                          : isMeetingDay && !isFuture
                                          ? AppTheme.primary
                                                .withOpacity(0.14)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      border: Border.all(
                                        color: hasSession
                                            ? Colors.green
                                            : isMeetingDay && !isFuture
                                            ? AppTheme.primary
                                            : isToday
                                            ? AppTheme.textLight
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$day',
                                          style: GoogleFonts.cairo(
                                            color: isFuture
                                                ? Colors.grey
                                                      .withOpacity(0.4)
                                                : hasSession
                                                ? Colors.green[800]
                                                : isMeetingDay || isToday
                                                ? AppTheme.primary
                                                : AppTheme.textDark,
                                            fontWeight:
                                                (isMeetingDay ||
                                                        isToday ||
                                                        hasSession) &&
                                                    !isFuture
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (hasSession)
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    if (meetingWeekday != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.14),
                              border: Border.all(color: AppTheme.primary),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الأيام المحددة هي أيام الاجتماع الأسبوعية',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
