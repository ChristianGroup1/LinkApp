import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/invitations/invitation_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';

/// Data model used internally in the screen
class ServantsPermissionsData {
  final List<AppProfile> servants;
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final List<HelperInvitation> pendingInvitations;
  final Map<String, List<Map<String, dynamic>>> classAssignmentsByUserId;
  final Map<String, List<Map<String, dynamic>>> meetingAssignmentsByUserId;

  const ServantsPermissionsData({
    required this.servants,
    required this.meetings,
    required this.classes,
    this.pendingInvitations = const [],
    this.classAssignmentsByUserId = const {},
    this.meetingAssignmentsByUserId = const {},
  });

  ServantsPermissionsData copyWith({
    List<AppProfile>? servants,
    List<MeetingEntity>? meetings,
    List<SundaySchoolClassEntity>? classes,
    List<HelperInvitation>? pendingInvitations,
    Map<String, List<Map<String, dynamic>>>? classAssignmentsByUserId,
    Map<String, List<Map<String, dynamic>>>? meetingAssignmentsByUserId,
  }) {
    return ServantsPermissionsData(
      servants: servants ?? this.servants,
      meetings: meetings ?? this.meetings,
      classes: classes ?? this.classes,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      classAssignmentsByUserId:
          classAssignmentsByUserId ?? this.classAssignmentsByUserId,
      meetingAssignmentsByUserId:
          meetingAssignmentsByUserId ?? this.meetingAssignmentsByUserId,
    );
  }

  int get totalAssignments {
    var count = 0;
    for (final items in classAssignmentsByUserId.values) {
      count += items.length;
    }
    for (final items in meetingAssignmentsByUserId.values) {
      count += items.length;
    }
    return count;
  }
}

enum AssignmentType { classRoom, meeting }

class ServantsHeroHeader extends StatelessWidget {
  final int totalServants;
  final int pendingInvitations;
  final int totalAssignments;
  final VoidCallback onInvite;

  const ServantsHeroHeader({
    super.key,
    required this.totalServants,
    required this.pendingInvitations,
    required this.totalAssignments,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primaryLight.withValues(alpha: 0.45),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة الخدام',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ادعُ خداماً جدداً، اسند لهم الفصول والاجتماعات، وحدد صلاحيات الحضور والتقارير.',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.textLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStatChip(
                  icon: Icons.person_outline_rounded,
                  label: 'خدام',
                  value: '$totalServants',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatChip(
                  icon: Icons.mail_outline_rounded,
                  label: 'دعوات',
                  value: '$pendingInvitations',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatChip(
                  icon: Icons.assignment_outlined,
                  label: 'إسنادات',
                  value: '$totalAssignments',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onInvite,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(
              'دعوة خادم جديد',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class ServantsSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  const ServantsSearchBox({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.cairo(),
      decoration: InputDecoration(
        hintText: 'ابحث باسم الخادم أو البريد أو الهاتف',
        hintStyle: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppTheme.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ServantsFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const ServantsFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppTheme.primary : AppTheme.textLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.primary : AppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServantsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? count;

  const ServantsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ServantsEmptyState extends StatelessWidget {
  final String query;

  const ServantsEmptyState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        children: [
          Icon(
            query.isEmpty ? Icons.groups_outlined : Icons.search_off_rounded,
            size: 42,
            color: AppTheme.textLight.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            query.isEmpty ? 'لا يوجد خدام مسجلين حالياً.' : 'لا توجد نتائج للبحث.',
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ServantPermissionCard extends StatelessWidget {
  final AppProfile servant;
  final ServantsPermissionsData data;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onAddAssignment;
  final Future<void> Function() onRemoved;

  const ServantPermissionCard({
    super.key,
    required this.servant,
    required this.data,
    required this.onRoleChanged,
    required this.onAddAssignment,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(servant.role);
    final initial = servant.fullName.trim().isEmpty
        ? '?'
        : servant.fullName.trim().characters.first;
    final assignmentCount =
        (data.classAssignmentsByUserId[servant.id]?.length ?? 0) +
        (data.meetingAssignmentsByUserId[servant.id]?.length ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: roleColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  roleColor.withValues(alpha: 0.16),
                                  roleColor.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.14),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: GoogleFonts.cairo(
                                color: roleColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  servant.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  servant.email ??
                                      servant.phone ??
                                      'بدون بيانات تواصل',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RoleTag(role: servant.role, onChanged: onRoleChanged),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              assignmentCount == 0
                                  ? 'لا توجد مهام مسندة بعد'
                                  : 'المهام المسندة ($assignmentCount)',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onAddAssignment,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(
                              'إسناد',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      ServantAssignmentsPreview(
                        servant: servant,
                        classAssignments:
                            data.classAssignmentsByUserId[servant.id] ??
                            const [],
                        meetingAssignments:
                            data.meetingAssignmentsByUserId[servant.id] ??
                            const [],
                        onRemoved: onRemoved,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(AppRole role) {
    if (role == AppRole.churchAdmin || role == AppRole.superAdmin) {
      return const Color(0xFF0EA5E9);
    }
    if (role == AppRole.classLeader) {
      return const Color(0xFF10B981);
    }
    return AppTheme.accentOrange;
  }
}

class _RoleTag extends StatelessWidget {
  final AppRole role;
  final ValueChanged<AppRole> onChanged;

  const _RoleTag({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final displayRole = role == AppRole.superAdmin ? AppRole.churchAdmin : role;
    final color = switch (displayRole) {
      AppRole.churchAdmin => const Color(0xFF0EA5E9),
      AppRole.classLeader => const Color(0xFF10B981),
      _ => AppTheme.accentOrange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppRole>(
          value: displayRole,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more_rounded, size: 18, color: color),
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          items: const [
            DropdownMenuItem(value: AppRole.churchAdmin, child: Text('مدير')),
            DropdownMenuItem(value: AppRole.classLeader, child: Text('أمين فصل')),
            DropdownMenuItem(
              value: AppRole.attendanceOfficer,
              child: Text('مسؤول حضور'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class ServantAssignmentsPreview extends StatelessWidget {
  final AppProfile servant;
  final List<Map<String, dynamic>> classAssignments;
  final List<Map<String, dynamic>> meetingAssignments;
  final Future<void> Function() onRemoved;

  const ServantAssignmentsPreview({
    super.key,
    required this.servant,
    required this.classAssignments,
    required this.meetingAssignments,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<DatabaseRepository>();
    if (classAssignments.isEmpty && meetingAssignments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...classAssignments.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServantsAssignmentChip(
              assignment: a,
              type: AssignmentType.classRoom,
              onDeleted: () async {
                await repo.removeClassAssignment(a['id'] as String);
                await onRemoved();
              },
            ),
          ),
        ),
        ...meetingAssignments.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServantsAssignmentChip(
              assignment: a,
              type: AssignmentType.meeting,
              onDeleted: () async {
                await repo.removeMeetingAssignment(a['id'] as String);
                await onRemoved();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ServantsAssignmentChip extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final AssignmentType type;
  final Future<void> Function() onDeleted;

  const ServantsAssignmentChip({
    super.key,
    required this.assignment,
    required this.type,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final dataKey = type == AssignmentType.classRoom
        ? 'sunday_school_classes'
        : 'meetings';
    final target = assignment[dataKey] as Map<String, dynamic>?;
    final name = target?['name_ar'] as String? ?? 'غير محدد';
    final canTake = assignment['can_take_attendance'] as bool? ?? true;
    final canView = assignment['can_view_reports'] as bool? ?? true;
    final color = type == AssignmentType.classRoom
        ? AppTheme.primary
        : const Color(0xFF10B981);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              type == AssignmentType.classRoom
                  ? Icons.school_outlined
                  : Icons.groups_outlined,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PermissionTag(
                      label: canTake ? 'تسجيل حضور' : 'بدون حضور',
                      icon: Icons.fact_check_outlined,
                      color: canTake
                          ? const Color(0xFF10B981)
                          : AppTheme.textLight,
                      enabled: canTake,
                    ),
                    _PermissionTag(
                      label: canView ? 'تقارير ومتابعة' : 'بدون تقارير',
                      icon: Icons.bar_chart_rounded,
                      color: canView
                          ? const Color(0xFF0EA5E9)
                          : AppTheme.textLight,
                      enabled: canView,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppTheme.textLight.withValues(alpha: 0.85),
            ),
            onPressed: onDeleted,
            tooltip: 'إزالة الإسناد',
          ),
        ],
      ),
    );
  }
}

class _PermissionTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;

  const _PermissionTag({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.1) : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? color.withValues(alpha: 0.18)
              : AppTheme.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ServantsScopeOptionsList extends StatelessWidget {
  final String selectedScope;
  final ValueChanged<String> onScopeChanged;

  const ServantsScopeOptionsList({
    super.key,
    required this.selectedScope,
    required this.onScopeChanged,
  });

  static const _options = [
    (
      'class',
      'فصل واحد',
      'خادم على فصل مدرسة أحد محدد',
      Icons.school_outlined,
    ),
    (
      'meeting_classes',
      'كل فصول اجتماع',
      'خادم على كل الفصول داخل اجتماع واحد',
      Icons.view_module_outlined,
    ),
    (
      'meeting',
      'اجتماع مباشر',
      'خادم على اجتماع بدون تقسيم لفصول',
      Icons.groups_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ServantsScopeOptionCard(
            title: _options[i].$2,
            subtitle: _options[i].$3,
            icon: _options[i].$4,
            selected: selectedScope == _options[i].$1,
            onTap: () => onScopeChanged(_options[i].$1),
          ),
        ],
      ],
    );
  }
}

class ServantsScopeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const ServantsScopeOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : AppTheme.border.withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? AppTheme.primary : AppTheme.textLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selected ? AppTheme.primary : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppTheme.textLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppTheme.primary : AppTheme.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServantsAssignmentTargetDropdown extends StatelessWidget {
  final String assignmentScope;
  final String? selectedTargetId;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> directMeetings;
  final List<MeetingEntity> groupedMeetings;
  final ValueChanged<String?> onChanged;

  const ServantsAssignmentTargetDropdown({
    super.key,
    required this.assignmentScope,
    required this.selectedTargetId,
    required this.classes,
    required this.directMeetings,
    required this.groupedMeetings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (assignmentScope == 'class') {
      return _buildDropdown(
        label: 'اختر الفصل',
        emptyText: 'لا توجد فصول متاحة.',
        items: classes.map((c) => MapEntry(c.id, c.nameAr)).toList(),
      );
    }
    if (assignmentScope == 'meeting_classes') {
      return _buildDropdown(
        label: 'اختر الاجتماع المتقسم',
        emptyText: 'لا توجد اجتماعات متقسمة لفصول.',
        items: groupedMeetings.map((m) => MapEntry(m.id, m.nameAr)).toList(),
      );
    }
    return _buildDropdown(
      label: 'اختر الاجتماع المباشر',
      emptyText: 'لا توجد اجتماعات مباشرة.',
      items: directMeetings.map((m) => MapEntry(m.id, m.nameAr)).toList(),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String emptyText,
    required List<MapEntry<String, String>> items,
  }) {
    if (items.isEmpty) {
      return Text(
        emptyText,
        style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textLight),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedTargetId,
      decoration: InputDecoration(labelText: label),
      style: GoogleFonts.cairo(color: AppTheme.textDark),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.key,
              child: Text(item.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class ServantsGeneratedInviteLinkCard extends StatelessWidget {
  final String inviteLink;

  const ServantsGeneratedInviteLinkCard({super.key, required this.inviteLink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'ابعت الرابط للخادم — يفتح التطبيق ويقدر يقبل أو يرفض',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            inviteLink,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteLink));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم نسخ رابط الدعوة',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(
              'نسخ الرابط',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class ServantsGeneratedCodeCard extends StatelessWidget {
  final String code;

  const ServantsGeneratedCodeCard({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return ServantsGeneratedInviteLinkCard(inviteLink: code);
  }
}

class ServantsPendingInvitationsSection extends StatelessWidget {
  final List<HelperInvitation> invitations;
  final Future<void> Function(HelperInvitation invitation) onDelete;
  final Future<void> Function(HelperInvitation invitation)? onResendEmail;

  const ServantsPendingInvitationsSection({
    super.key,
    required this.invitations,
    required this.onDelete,
    this.onResendEmail,
  });

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: invitations.map((invitation) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.fullName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      invitation.inviteToken.isNotEmpty
                          ? buildInvitationLink(
                              inviteToken: invitation.inviteToken,
                            )
                          : invitation.code,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    if (invitation.email != null &&
                        invitation.email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        invitation.email!,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'نسخ الرابط',
                onPressed: () {
                  final link = invitation.inviteToken.isNotEmpty
                      ? buildInvitationLink(
                          inviteToken: invitation.inviteToken,
                        )
                      : invitation.code;
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم نسخ رابط الدعوة',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              if (onResendEmail != null &&
                  invitation.email != null &&
                  invitation.email!.trim().isNotEmpty)
                IconButton(
                  tooltip: 'إعادة إرسال البريد',
                  onPressed: () => onResendEmail!(invitation),
                  icon: const Icon(Icons.send_outlined, size: 18),
                ),
              IconButton(
                tooltip: 'حذف الدعوة',
                onPressed: () => onDelete(invitation),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.accentRed,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}