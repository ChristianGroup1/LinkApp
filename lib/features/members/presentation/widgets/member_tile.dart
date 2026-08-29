import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';

/// Card shown for each member in the members list.
class MemberTile extends StatelessWidget {
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MemberTile({
    super.key,
    required this.member,
    required this.classes,
    required this.meetings,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return fullName.isNotEmpty ? fullName[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    String destinationLabel = '';
    IconData destinationIcon = Icons.class_rounded;
    if (member.scope == MemberScope.sundaySchoolClass) {
      final cls = classes
          .where((c) => c.id == member.sundaySchoolClassId)
          .firstOrNull;
      destinationLabel = cls?.nameAr ?? 'فصل';
      destinationIcon = Icons.class_rounded;
    } else {
      final mtg = meetings.where((m) => m.id == member.meetingId).firstOrNull;
      destinationLabel = mtg?.nameAr ?? 'اجتماع';
      destinationIcon = Icons.groups_3_rounded;
    }

    final accent = member.scope == MemberScope.sundaySchoolClass
        ? AppTheme.primary
        : AppTheme.secondary;
    final accentLight = member.scope == MemberScope.sundaySchoolClass
        ? AppTheme.primaryLight
        : AppTheme.secondaryLight;
    final initials = _getInitials(member.fullName);
    final birthDateLabel = member.birthDate == null
        ? null
        : '${member.birthDate!.day.toString().padLeft(2, '0')}/'
              '${member.birthDate!.month.toString().padLeft(2, '0')}/'
              '${member.birthDate!.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent strip
                Container(height: 4, color: accent),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withValues(alpha: 0.2),
                                  accent.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. الاسم (Name)
                                Text(
                                  member.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                    color: AppTheme.textDark,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 5),

                                // 2. تاريخ الميلاد (Birth Date)
                                if (birthDateLabel != null) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.cake_outlined,
                                        size: 14,
                                        color: AppTheme.accentOrange,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'تاريخ الميلاد: $birthDateLabel',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                // 3. رقم هاتف العضو (Member Phone)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: member.phone != null
                                          ? AppTheme.secondary
                                          : AppTheme.textLight,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      member.phone != null
                                          ? 'رقم التليفون: ${member.phone}'
                                          : 'رقم التليفون: غير مسجل',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: member.phone != null
                                            ? AppTheme.textDark
                                            : AppTheme.textLight,
                                      ),
                                    ),
                                    if (member.phone != null) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _callNumber(member.phone!),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Icon(
                                            Icons.phone_in_talk_outlined,
                                            size: 15,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () =>
                                            _openWhatsApp(member.phone!),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 15,
                                            color: AppTheme.accentSky,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // 4. كود التعريفي (Identification Code)
                                if (member.code != null &&
                                    member.code!.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_rounded,
                                        size: 14,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'الكود التعريفي: ${member.code}',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                const SizedBox(height: 2),

                                // Tags Row (Scope, Parent Name & Parent Phone)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _MemberTag(
                                      icon: destinationIcon,
                                      label: destinationLabel,
                                      color: accent,
                                      backgroundColor: accentLight,
                                    ),
                                    if (member.notes != null &&
                                        member.notes!.isNotEmpty)
                                      _MemberTag(
                                        icon: Icons.school_outlined,
                                        label: 'المرحلة: ${member.notes}',
                                        color: AppTheme.secondary,
                                        backgroundColor:
                                            AppTheme.secondaryLight,
                                      ),
                                    if (member.parentName != null)
                                      _MemberTag(
                                        icon: Icons.family_restroom_outlined,
                                        label:
                                            'ولي الأمر: ${member.parentName}',
                                        color: AppTheme.accentPurple,
                                        backgroundColor: AppTheme.accentPurple
                                            .withValues(alpha: 0.08),
                                      ),
                                    if (member.parentPhone != null)
                                      InkWell(
                                        onTap: () =>
                                            _callNumber(member.parentPhone!),
                                        borderRadius: BorderRadius.circular(8),
                                        child: _MemberTag(
                                          icon: Icons.phone_iphone_rounded,
                                          label:
                                              'هاتف ولي الأمر: ${member.parentPhone}',
                                          color: AppTheme.accentOrange,
                                          backgroundColor:
                                              AppTheme.accentOrangeLight,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: AppTheme.border.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _MemberQuickAction(
                                tooltip: 'تعديل ${member.fullName}',
                                icon: Icons.edit_outlined,
                                label: 'تعديل',
                                color: AppTheme.primary,
                                onTap: onEdit,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MemberQuickAction(
                                tooltip: 'حذف ${member.fullName}',
                                icon: Icons.delete_outline_rounded,
                                label: 'حذف',
                                color: AppTheme.accentRed,
                                onTap: onDelete,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _callNumber(String number) async {
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

  void _openWhatsApp(String number) async {
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

class _MemberQuickAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MemberQuickAction({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _MemberTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4.5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
