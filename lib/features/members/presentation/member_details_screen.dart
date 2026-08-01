import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../logic/members_bloc.dart';
import 'add_edit_member_screen.dart';

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
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'الاسم الكامل',
                  value: member.fullName,
                ),
                _DetailRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'الكود التعريفي',
                  value: member.code,
                ),
                _DetailRow(
                  icon: Icons.cake_outlined,
                  label: 'تاريخ الميلاد',
                  value: _birthDateLabel(member.birthDate),
                  supportingValue: _ageLabel(member.birthDate),
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
            _DetailsSection(
              icon: Icons.contact_phone_outlined,
              color: AppTheme.accentOrange,
              title: 'التواصل والعائلة',
              children: [
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'هاتف العضو',
                  value: member.phone,
                  onTap: member.phone == null
                      ? null
                      : () => _callNumber(member.phone!),
                ),
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
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    var cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('01')) {
      cleanNumber = '2$cleanNumber';
    }
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
