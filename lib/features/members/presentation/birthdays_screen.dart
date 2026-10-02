import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../logic/members_bloc.dart';

class BirthdaysScreen extends StatelessWidget {
  const BirthdaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MembersBloc(repository: context.read<DatabaseRepository>())
            ..add(LoadMembers()),
      child: const _BirthdaysView(),
    );
  }
}

class _BirthdaysView extends StatefulWidget {
  const _BirthdaysView();

  @override
  State<_BirthdaysView> createState() => _BirthdaysViewState();
}

class _BirthdaysViewState extends State<_BirthdaysView> {
  late DateTime _from;
  late DateTime _to;
  int? _quickMonths = 3;

  @override
  void initState() {
    super.initState();
    _setQuickRange(3, rebuild: false);
  }

  void _setQuickRange(int months, {bool rebuild = true}) {
    final today = _dateOnly(DateTime.now());
    final end = _addMonths(today, months);
    void update() {
      _from = today;
      _to = end;
      _quickMonths = months;
    }

    if (rebuild && mounted) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'اختيار فترة أعياد الميلاد',
      saveText: 'تطبيق الفترة',
      cancelText: 'إلغاء',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _from = _dateOnly(selected.start);
      _to = _dateOnly(selected.end);
      _quickMonths = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'أعياد الميلاد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<MembersBloc, MembersState>(
          builder: (context, state) {
            if (state is MembersLoading || state is MembersInitial) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (state is MembersError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(color: AppTheme.accentRed),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            context.read<MembersBloc>().add(LoadMembers()),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is! MembersLoaded) return const SizedBox.shrink();

            final occurrences = _birthdaysInRange(state.allMembers);
            return Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: occurrences.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: occurrences.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (context, index) =>
                              _BirthdayCard(occurrence: occurrences[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final dateFormat = intl.DateFormat('d MMM yyyy', 'ar');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الفترة الزمنية',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: [
              for (final (months, label) in [
                (1, 'شهر'),
                (2, 'شهرين'),
                (3, '٣ شهور'),
              ])
                ChoiceChip(
                  label: Text(label, style: GoogleFonts.cairo(fontSize: 12)),
                  selected: _quickMonths == months,
                  onSelected: (_) => _setQuickRange(months),
                  selectedColor: AppTheme.primaryLight,
                  side: BorderSide(color: AppTheme.border),
                ),
            ],
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: _chooseRange,
            icon: const Icon(Icons.date_range_rounded),
            label: Text(
              'من ${dateFormat.format(_from)} إلى ${dateFormat.format(_to)}',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_outlined, size: 54, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(
            'لا توجد أعياد ميلاد في الفترة المحددة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  List<_BirthdayOccurrence> _birthdaysInRange(List<MemberEntity> members) {
    final found = <_BirthdayOccurrence>[];
    final firstYear = _from.year;
    final lastYear = _to.year;
    for (final member in members) {
      final birthDate = member.birthDate;
      if (!member.isActive || birthDate == null) continue;
      for (var year = firstYear; year <= lastYear; year++) {
        final day =
            birthDate.month == DateTime.february &&
                birthDate.day == 29 &&
                !_isLeapYear(year)
            ? 28
            : birthDate.day;
        final occurrence = DateTime(year, birthDate.month, day);
        if (!occurrence.isBefore(_from) && !occurrence.isAfter(_to)) {
          found.add(
            _BirthdayOccurrence(
              member: member,
              date: occurrence,
              age: year - birthDate.year,
            ),
          );
        }
      }
    }
    found.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : a.member.fullName.compareTo(b.member.fullName);
    });
    return found;
  }
}

class _BirthdayOccurrence {
  final MemberEntity member;
  final DateTime date;
  final int age;

  const _BirthdayOccurrence({
    required this.member,
    required this.date,
    required this.age,
  });
}

class _BirthdayCard extends StatelessWidget {
  final _BirthdayOccurrence occurrence;

  const _BirthdayCard({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final dateLabel = intl.DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(occurrence.date);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cake_rounded, color: AppTheme.accentOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.member.fullName,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  '$dateLabel • يتم ${occurrence.age} سنة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
                if (occurrence.member.phone?.trim().isNotEmpty == true)
                  Text(
                    occurrence.member.phone!,
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _addMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day.clamp(1, lastDay));
}

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
