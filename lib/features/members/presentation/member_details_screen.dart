import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../logic/members_bloc.dart';
import 'add_edit_member_screen.dart';
import 'member_attendance_history_screen.dart';

class MemberDetailsScreen extends StatelessWidget {
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;
  final bool canManage;

  const MemberDetailsScreen({
    super.key,
    required this.member,
    required this.classes,
    required this.meetings,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MembersBloc, MembersState>(
      builder: (context, state) {
        final currentMember = state is MembersLoaded
            ? state.allMembers
                      .where((item) => item.id == member.id)
                      .firstOrNull ??
                  member
            : member;

        return _MemberDetailsView(
          member: currentMember,
          classes: classes,
          meetings: meetings,
          canManage: canManage,
        );
      },
    );
  }
}

class _MemberDetailsView extends StatelessWidget {
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;
  final bool canManage;

  const _MemberDetailsView({
    required this.member,
    required this.classes,
    required this.meetings,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final destination = _destinationDetails();
    final primaryContact = member.phone ?? member.parentPhone;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'بيانات العضو',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            if (canManage)
              IconButton(
                tooltip: 'تعديل البيانات',
                onPressed: () => _openEditScreen(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _MemberProfileHeader(
              member: member,
              destinationLabel: destination.label,
              destinationIcon: destination.icon,
              accent: destination.color,
            ),
            if (primaryContact != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.phone_in_talk_outlined,
                      label: 'اتصال',
                      color: AppTheme.secondary,
                      onTap: () => _callNumber(primaryContact),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'واتساب',
                      color: AppTheme.accentSky,
                      onTap: () => _openWhatsApp(primaryContact),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _DetailsSection(
              icon: Icons.badge_outlined,
              color: AppTheme.primary,
              title: 'البيانات الأساسية',
              children: [
                // 1. الاسم الكامل
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'الاسم الكامل',
                  value: member.fullName,
                ),
                // 2. رقم هاتف العضو
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'رقم هاتف العضو',
                  value: member.phone,
                  onTap: member.phone == null
                      ? null
                      : () => _callNumber(member.phone!),
                ),
                // 3. تاريخ الميلاد
                _DetailRow(
                  icon: Icons.cake_outlined,
                  label: 'تاريخ الميلاد',
                  value: _birthDateLabel(member.birthDate),
                  supportingValue: _ageLabel(member.birthDate),
                ),
                // 4. الكود التعريفي
                _DetailRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'الكود التعريفي',
                  value: member.code,
                  isLast: member.notes == null || member.notes!.isEmpty,
                ),
                // 5. السنة الدراسية / المرحلة
                if (member.notes != null && member.notes!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.school_outlined,
                    label: 'السنة الدراسية / المرحلة',
                    value: member.notes,
                    isLast: true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailsSection(
              icon: Icons.account_tree_outlined,
              color: destination.color,
              title: 'التبعية والخدمة',
              children: [
                _DetailRow(
                  icon: member.scope == MemberScope.sundaySchoolClass
                      ? Icons.school_outlined
                      : Icons.groups_2_outlined,
                  label: member.scope == MemberScope.sundaySchoolClass
                      ? 'فصل مدارس الأحد'
                      : 'الاجتماع المباشر',
                  value: destination.label,
                ),
                _DetailRow(
                  icon: member.isActive
                      ? Icons.verified_user_outlined
                      : Icons.person_off_outlined,
                  label: 'حالة العضو',
                  value: member.isActive ? 'نشط' : 'غير نشط',
                  valueColor: member.isActive
                      ? AppTheme.secondary
                      : AppTheme.accentRed,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MemberAttendanceSection(
              memberId: member.id,
              member: member,
              classes: classes,
              meetings: meetings,
            ),
            const SizedBox(height: 14),
            _DetailsSection(
              icon: Icons.contact_phone_outlined,
              color: AppTheme.accentOrange,
              title: 'التواصل والعائلة',
              children: [
                _DetailRow(
                  icon: Icons.family_restroom_rounded,
                  label: 'اسم ولي الأمر',
                  value: member.parentName,
                ),
                _DetailRow(
                  icon: Icons.phone_iphone_rounded,
                  label: 'هاتف ولي الأمر',
                  value: member.parentPhone,
                  onTap: member.parentPhone == null
                      ? null
                      : () => _callNumber(member.parentPhone!),
                  isLast: true,
                ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: Text(
                  'حذف العضو',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRed,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppTheme.accentRed.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({String label, IconData icon, Color color}) _destinationDetails() {
    if (member.scope == MemberScope.sundaySchoolClass) {
      final selectedClass = classes
          .where((item) => item.id == member.sundaySchoolClassId)
          .firstOrNull;
      return (
        label: selectedClass?.nameAr ?? 'فصل مدارس الأحد',
        icon: Icons.school_outlined,
        color: AppTheme.primary,
      );
    }

    final selectedMeeting = meetings
        .where((item) => item.id == member.meetingId)
        .firstOrNull;
    return (
      label: selectedMeeting?.nameAr ?? 'اجتماع مباشر',
      icon: Icons.groups_2_outlined,
      color: AppTheme.secondary,
    );
  }

  Future<void> _openEditScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MembersBloc>(),
          child: AddEditMemberScreen(member: member),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.accentRed,
            size: 44,
          ),
          title: Text(
            'حذف العضو نهائيًا؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'سيتم حذف بيانات ${member.fullName} وسجلاته المرتبطة، ولا يمكن التراجع عن هذه الخطوة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<MembersBloc>().add(DeleteMemberEvent(member.id));
    Navigator.pop(context, true);
  }

  String? _birthDateLabel(DateTime? date) {
    if (date == null) return null;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String? _ageLabel(DateTime? birthDate) {
    if (birthDate == null) return null;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= 0 ? '$age سنة' : null;
  }

  Future<void> _callNumber(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.isEmpty) return;

    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _openWhatsApp(String number) async {
    var cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.isEmpty) return;

    if (cleanNumber.startsWith('01') && cleanNumber.length == 11) {
      cleanNumber = '2$cleanNumber';
    }

    final urls = [
      'whatsapp://send?phone=$cleanNumber',
      'https://wa.me/$cleanNumber',
      'https://api.whatsapp.com/send?phone=$cleanNumber',
    ];

    for (final urlStr in urls) {
      try {
        final uri = Uri.parse(urlStr);
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }
}

class _MemberAttendanceSection extends StatefulWidget {
  final String memberId;
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;

  const _MemberAttendanceSection({
    required this.memberId,
    required this.member,
    required this.classes,
    required this.meetings,
  });

  @override
  State<_MemberAttendanceSection> createState() =>
      _MemberAttendanceSectionState();
}

class _MemberAttendanceSectionState extends State<_MemberAttendanceSection> {
  late Future<List<MemberAttendanceHistoryEntry>> _historyFuture;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant _MemberAttendanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberId != widget.memberId) {
      _showAll = false;
      _loadHistory();
    }
  }

  void _loadHistory() {
    _historyFuture = context
        .read<DatabaseRepository>()
        .getMemberAttendanceHistory(widget.memberId);
  }

  void _retry() {
    setState(_loadHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: AppTheme.softShadow,
      ),
      child: FutureBuilder<List<MemberAttendanceHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الحضور والغياب',
                    style: GoogleFonts.cairo(
                      color: AppTheme.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (snapshot.hasError)
                _AttendanceLoadError(onRetry: _retry)
              else
                _buildHistory(snapshot.data ?? const []),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistory(List<MemberAttendanceHistoryEntry> history) {
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: AppTheme.textLight.withValues(alpha: 0.65),
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد سجلات حضور لهذا العضو حتى الآن',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppTheme.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final present = history
        .where((entry) => entry.status == AttendanceStatus.present)
        .length;
    final absent = history
        .where((entry) => entry.status == AttendanceStatus.absent)
        .length;
    final excused = history
        .where((entry) => entry.status == AttendanceStatus.excused)
        .length;
    final percentage = history.isEmpty ? 0 : (present * 100 / history.length);
    final previewHistory = history.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AttendanceStatCard(
                label: 'حضر',
                value: present,
                color: AppTheme.secondary,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttendanceStatCard(
                label: 'غاب',
                value: absent,
                color: AppTheme.accentRed,
                icon: Icons.cancel_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AttendanceStatCard(
                label: 'معتذر',
                value: excused,
                color: AppTheme.accentOrange,
                icon: Icons.info_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نسبة الحضور',
                    style: GoogleFonts.cairo(
                      color: AppTheme.textDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${percentage.round()}٪',
                    style: GoogleFonts.cairo(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 7,
                  color: AppTheme.secondary,
                  backgroundColor: AppTheme.border,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Header with Full Screen Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سجل الحضور الأخير',
              style: GoogleFonts.cairo(
                color: AppTheme.textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberAttendanceHistoryScreen(
                      member: widget.member,
                      history: history,
                      classes: widget.classes,
                      meetings: widget.meetings,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'التفاصيل والفلترة (${history.length})',
                      style: GoogleFonts.cairo(
                        color: AppTheme.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...previewHistory.map(_buildHistoryRow),
        if (history.length > 4) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemberAttendanceHistoryScreen(
                    member: widget.member,
                    history: history,
                    classes: widget.classes,
                    meetings: widget.meetings,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.filter_list_rounded, size: 16),
            label: Text(
              'فتح كامل سجلات الحضور (${history.length}) والفلترة',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryRow(MemberAttendanceHistoryEntry entry) {
    final statusDetails = switch (entry.status) {
      AttendanceStatus.present => (
        label: 'حاضر',
        icon: Icons.check_rounded,
        color: AppTheme.secondary,
      ),
      AttendanceStatus.absent => (
        label: 'غائب',
        icon: Icons.close_rounded,
        color: AppTheme.accentRed,
      ),
      AttendanceStatus.excused => (
        label: 'معتذر',
        icon: Icons.info_outline_rounded,
        color: AppTheme.accentOrange,
      ),
    };
    final meeting = widget.meetings
        .where((item) => item.id == entry.meetingId)
        .firstOrNull;
    final classEntity = widget.classes
        .where((item) => item.id == entry.classId)
        .firstOrNull;
    final destination = classEntity?.nameAr ?? meeting?.nameAr ?? 'اجتماع';

    // Register Name (اسم السجل)
    final registerName = entry.sessionTitle?.trim().isNotEmpty == true
        ? entry.sessionTitle!
        : 'سجل $destination';

    final day = entry.sessionDate.day.toString().padLeft(2, '0');
    final month = entry.sessionDate.month.toString().padLeft(2, '0');
    final date = '$day/$month/${entry.sessionDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusDetails.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusDetails.icon,
              size: 18,
              color: statusDetails.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Register Name (اسم السجل)
                Text(
                  registerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                // Meeting / Class & Date Subtitle
                Text(
                  '$destination · $date',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusDetails.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusDetails.label,
              style: GoogleFonts.cairo(
                color: statusDetails.color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _AttendanceStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _AttendanceLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.accentRed,
            size: 32,
          ),
          const SizedBox(height: 7),
          Text(
            'تعذر تحميل سجل الحضور',
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _MemberProfileHeader extends StatelessWidget {
  final MemberEntity member;
  final String destinationLabel;
  final IconData destinationIcon;
  final Color accent;

  const _MemberProfileHeader({
    required this.member,
    required this.destinationLabel,
    required this.destinationIcon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final initial = member.fullName.trim().isEmpty
        ? '?'
        : member.fullName.trim().characters.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Text(
              initial,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            member.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              _HeaderTag(icon: destinationIcon, label: destinationLabel),
              _HeaderTag(
                icon: member.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                label: member.isActive ? 'عضو نشط' : 'غير نشط',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;

  const _DetailsSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? supportingValue;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.supportingValue,
    this.valueColor,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppTheme.border.withValues(alpha: 0.65),
                  ),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textLight, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      color: AppTheme.textLight,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hasValue ? value! : 'غير مسجل',
                    style: GoogleFonts.cairo(
                      color: hasValue
                          ? valueColor ?? AppTheme.textDark
                          : AppTheme.textLight,
                      fontSize: 12.5,
                      fontWeight: hasValue ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (supportingValue != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrangeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  supportingValue!,
                  style: GoogleFonts.cairo(
                    color: AppTheme.accentOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (onTap != null)
              const Icon(
                Icons.call_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
