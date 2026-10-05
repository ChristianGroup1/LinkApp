import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/data/app_data_changes.dart';
import 'visit_edit_screen.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  late Future<_VisitData> _data;
  bool _saving = false;
  StreamSubscription<AppDataChange>? _dataChangesSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data = _load();
    _dataChangesSubscription ??= AppDataChanges.instance.stream
        .where((change) => change.affectsAny({AppDataArea.followUps}))
        .listen((_) => unawaited(_reload()));
  }

  @override
  void dispose() {
    _dataChangesSubscription?.cancel();
    super.dispose();
  }

  Future<_VisitData> _load() async {
    final repository = context.read<DatabaseRepository>();
    final values = await Future.wait([
      repository.getAllMembers(),
      repository.getAllFollowUps(),
      repository.getProfiles(),
      repository.getPendingFollowUpIds(),
    ]);
    return _VisitData(
      pendingIds: values[3] as Set<String>,
      members: values[0] as List<MemberEntity>,
      visits: (values[1] as List<FollowUpEntity>)
          .where((item) => item.activityType == 'visit')
          .toList(),
      servants: values[2] as List<AppProfile>,
    );
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final request = _load();
    setState(() => _data = request);
    try {
      await request;
    } catch (_) {
      /* FutureBuilder displays load errors. */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'الزيارات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _showAddVisit,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'تسجيل زيارة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
        body: FutureBuilder<_VisitData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تعذر تحميل سجل الزيارات',
                      style: GoogleFonts.cairo(color: AppTheme.accentRed),
                    ),
                    TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            final membersById = {
              for (final member in data.members) member.id: member,
            };
            final servantsById = {
              for (final servant in data.servants) servant.id: servant,
            };
            final visits = [...data.visits]
              ..sort((a, b) => b.followUpDate.compareTo(a.followUpDate));
            final upcoming = visits
                .where(
                  (item) =>
                      item.contactStatus == 'pending' &&
                      !_isBeforeToday(item.followUpDate),
                )
                .length;
            final pendingSync = visits
                .where((item) => data.pendingIds.contains(item.id))
                .length;
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _summaryCard(visits.length, upcoming, pendingSync),
                  const SizedBox(height: 16),
                  if (visits.isEmpty)
                    _emptyCard()
                  else
                    ...visits.map(
                      (visit) => _visitCard(
                        visit,
                        membersById[visit.memberId],
                        servantsById[visit.responsibleUserId],
                        data.pendingIds.contains(visit.id),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(int count, int upcoming, int pendingSync) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF4C45DA), Color(0xFF7167ED)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل الزيارات',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'زيارات مسجلة: $count  •  مواعيد قادمة: $upcoming',
                style: GoogleFonts.cairo(
                  color: Colors.white.withValues(alpha: .9),
                  fontSize: 12,
                ),
              ),
              if (pendingSync > 0)
                Text(
                  '$pendingSync سجل بانتظار المزامنة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _emptyCard() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(Icons.event_note_rounded, color: AppTheme.textLight, size: 42),
        const SizedBox(height: 8),
        Text(
          'لا توجد زيارات مسجلة بعد',
          style: GoogleFonts.cairo(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'سجّل زيارة أو موعدًا قادمًا ليظهر هنا.',
          style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _visitCard(
    FollowUpEntity visit,
    MemberEntity? member,
    AppProfile? servant,
    bool isPendingSync,
  ) {
    final isPlanned = visit.contactStatus == 'pending';
    final date = intl.DateFormat('yyyy/MM/dd').format(visit.followUpDate);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(17),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.secondary.withValues(alpha: .12),
                child: const Icon(
                  Icons.person_pin_circle_outlined,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member?.fullName ?? 'مخدوم غير متاح',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              _statusChip(
                isPendingSync
                    ? 'بانتظار المزامنة'
                    : isPlanned
                    ? 'موعد قادم'
                    : 'تمت الزيارة',
                isPendingSync || isPlanned,
                icon: isPendingSync ? Icons.cloud_upload_outlined : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _detail(Icons.calendar_month_outlined, date),
              _detail(
                Icons.home_work_outlined,
                visit.reason?.isNotEmpty == true ? visit.reason! : 'زيارة',
              ),
              _detail(Icons.person_outline, servant?.fullName ?? 'غير محدد'),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => _showVisitDetails(
                      visit,
                      member,
                      servant,
                      isPendingSync,
                    ),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('التفاصيل والتعديل'),
            ),
          ),
          if (visit.result?.isNotEmpty == true) ...[
            const Divider(height: 20),
            Text(
              visit.result!,
              style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textLight),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppTheme.textLight),
      const SizedBox(width: 4),
      Text(
        text,
        style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textLight),
      ),
    ],
  );

  Widget _statusChip(String text, bool pending, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: (pending ? AppTheme.accentOrange : AppTheme.secondary).withValues(
        alpha: .12,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: AppTheme.accentOrange),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: pending ? AppTheme.accentOrange : AppTheme.secondary,
          ),
        ),
      ],
    ),
  );

  Future<void> _showAddVisit({FollowUpEntity? existing}) async {
    if (_saving) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitEditScreen(visit: existing),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _showVisitDetails(
    FollowUpEntity visit,
    MemberEntity? member,
    AppProfile? servant,
    bool pendingSync,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تفاصيل الزيارة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _visitDetail('المخدوم', member?.fullName ?? 'غير متاح'),
                _visitDetail('الخادم المسؤول', servant?.fullName ?? 'غير محدد'),
                _visitDetail(
                  'التاريخ',
                  intl.DateFormat('yyyy/MM/dd').format(visit.followUpDate),
                ),
                _visitDetail('نوع الزيارة', visit.reason ?? 'زيارة'),
                _visitDetail(
                  'الحالة',
                  visit.contactStatus == 'pending'
                      ? 'لم تتم بعد'
                      : 'تمت الزيارة أو التواصل',
                ),
                if (pendingSync)
                  _visitDetail(
                    'المزامنة',
                    'محفوظة على الجهاز وبانتظار المزامنة',
                  ),
                _visitDetail(
                  'الملاحظات والنتيجة',
                  visit.result?.isNotEmpty == true
                      ? visit.result!
                      : 'لا توجد ملاحظات',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل الزيارة'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف الزيارة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || _saving) return;
    if (action == 'edit') await _showAddVisit(existing: visit);
    if (action == 'delete') await _deleteVisit(visit);
  }

  Widget _visitDetail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textLight),
        ),
        Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Future<void> _deleteVisit(FollowUpEntity visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الزيارة؟'),
          content: const Text(
            'سيتم حذف سجل هذه الزيارة وملاحظاتها. لا يمكن التراجع عن الحذف.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      final synced = await context.read<DatabaseRepository>().deleteFollowUp(
        visit.id,
      );
      if (!mounted) return;
      _message(
        synced
            ? 'تم حذف الزيارة'
            : 'تم حذف الزيارة من الجهاز وستتم مزامنة الحذف عند الاتصال',
      );
      await _reload();
    } catch (_) {
      if (mounted) {
        _message(
          'تعذر حذف الزيارة. تحقق من صلاحياتك وحاول مرة أخرى',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isBeforeToday(DateTime value) {
    final today = DateTime.now();
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, style: GoogleFonts.cairo()),
          backgroundColor: error ? AppTheme.accentRed : AppTheme.secondary,
        ),
      );
}

class _VisitData {
  final Set<String> pendingIds;
  final List<MemberEntity> members;
  final List<FollowUpEntity> visits;
  final List<AppProfile> servants;
  const _VisitData({
    required this.pendingIds,
    required this.members,
    required this.visits,
    required this.servants,
  });
}
