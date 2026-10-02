import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/data/app_data_changes.dart';

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
    ]);
    return _VisitData(
      members: values[0] as List<MemberEntity>,
      visits: (values[1] as List<FollowUpEntity>)
          .where((item) => item.activityType == 'visit')
          .toList(),
      servants: values[2] as List<AppProfile>,
    );
  }

  Future<void> _reload() async {
    final request = _load();
    setState(() => _data = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'الزيارات والافتقاد',
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
                .where((item) => item.id.startsWith('offline_'))
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
          'سجّل زيارة أو موعد افتقاد ليظهر هنا.',
          style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _visitCard(
    FollowUpEntity visit,
    MemberEntity? member,
    AppProfile? servant,
  ) {
    final isPlanned = visit.contactStatus == 'pending';
    final isPendingSync = visit.id.startsWith('offline_');
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

  Future<void> _showAddVisit() async {
    final data = await _data;
    if (!mounted || data.members.isEmpty) {
      if (mounted) _message('أضف مخدومًا أولًا لتسجيل الزيارة');
      return;
    }
    String memberId = data.members.first.id;
    final activeServants = data.servants
        .where((servant) => servant.isActive)
        .toList();
    String? servantId = activeServants.isEmpty ? null : activeServants.first.id;
    String status = 'pending';
    String type = 'زيارة منزلية';
    DateTime date = DateTime.now();
    final notes = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                'تسجيل زيارة أو افتقاد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: memberId,
                      decoration: const InputDecoration(labelText: 'المخدوم'),
                      isExpanded: true,
                      items: data.members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => memberId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'نوع الافتقاد',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'زيارة منزلية',
                          child: Text('زيارة منزلية'),
                        ),
                        DropdownMenuItem(
                          value: 'اتصال هاتفي',
                          child: Text('اتصال هاتفي'),
                        ),
                        DropdownMenuItem(value: 'رسالة', child: Text('رسالة')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => type = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('موعد قادم / لم تتم بعد'),
                        ),
                        DropdownMenuItem(
                          value: 'contacted',
                          child: Text('تمت الزيارة أو التواصل'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => status = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: servantId,
                      decoration: const InputDecoration(
                        labelText: 'الخادم المسؤول',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('غير محدد'),
                        ),
                        ...activeServants.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(
                              s.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => servantId = value),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'التاريخ: ${intl.DateFormat('yyyy/MM/dd').format(date)}',
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: child!,
                          ),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
                    ),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات أو نتيجة الزيارة',
                      ),
                      style: GoogleFonts.cairo(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text('حفظ', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (saved != true || !mounted) {
      notes.dispose();
      return;
    }
    final visitNotes = notes.text.trim();
    notes.dispose();
    setState(() => _saving = true);
    try {
      final synced = await context.read<DatabaseRepository>().addFollowUp(
        memberId: memberId,
        reason: type,
        contactStatus: status,
        result: visitNotes,
        responsibleUserId: servantId,
        followUpDate: date,
        activityType: 'visit',
      );
      if (!mounted) return;
      _message(
        synced
            ? 'تم حفظ الزيارة'
            : 'تم حفظ الزيارة على الجهاز وستتزامن عند عودة الإنترنت',
      );
      unawaited(_reload());
    } catch (error) {
      if (mounted) _message('تعذر حفظ الزيارة: $error', error: true);
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
  final List<MemberEntity> members;
  final List<FollowUpEntity> visits;
  final List<AppProfile> servants;
  const _VisitData({
    required this.members,
    required this.visits,
    required this.servants,
  });
}
