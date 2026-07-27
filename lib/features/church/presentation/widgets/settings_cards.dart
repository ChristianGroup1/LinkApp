import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../../../logic/auth/auth_bloc.dart';
import '../invite_servant_screen.dart';
import 'settings_dialogs.dart';

class UserProfileCard extends StatelessWidget {
  final AppProfile profile;

  const UserProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    String roleLabel = 'خادم';
    if (profile.role == AppRole.superAdmin || profile.role == AppRole.churchAdmin) {
      roleLabel = 'أمين الخدمة / مسؤول الكنيسة';
    } else if (profile.role == AppRole.classLeader) {
      roleLabel = 'أمين فصل';
    } else if (profile.role == AppRole.attendanceOfficer) {
      roleLabel = 'مسؤول حضور';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              radius: 26,
              child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleLabel,
                    style: GoogleFonts.cairo(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (profile.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.email!,
                    style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChurchProfileCard extends StatelessWidget {
  final Church church;
  final bool isAdmin;

  const ChurchProfileCard({super.key, required this.church, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بيانات الكنيسة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primary)),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                  onPressed: () => showEditChurchDialog(context, church),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.church, color: AppTheme.textLight, size: 18),
            const SizedBox(width: 8),
            Text(church.nameAr, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ]),
          if (church.phone != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.phone, color: AppTheme.textLight, size: 18),
              const SizedBox(width: 8),
              Text(church.phone!, style: GoogleFonts.cairo(color: AppTheme.textDark)),
            ]),
          ],
          if (church.address != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: AppTheme.textLight, size: 18),
              const SizedBox(width: 8),
              Text(church.address!, style: GoogleFonts.cairo(color: AppTheme.textLight)),
            ]),
          ],
        ],
      ),
    );
  }
}

class ServantsPermissionsEntryCard extends StatelessWidget {
  final Widget destination;

  const ServantsPermissionsEntryCard({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepositoryProvider.value(
              value: context.read<DatabaseRepository>(),
              child: destination,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الخدام والصلاحيات', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textDark)),
                  const SizedBox(height: 2),
                  Text('إدارة الأدوار، الدعوات، الفصول، وصلاحيات الحضور.', style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textLight)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.textLight, size: 16),
          ],
        ),
      ),
    );
  }
}

class SettingsFallbackScaffold extends StatelessWidget {
  final String message;
  final bool isLoading;

  const SettingsFallbackScaffold({
    super.key,
    required this.message,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'إعدادات الحساب والخدمة',
            style: GoogleFonts.cairo(color: AppTheme.textDark, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 42),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: isLoading ? AppTheme.textLight : AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
                    icon: const Icon(Icons.logout),
                    label: Text('تسجيل خروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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

class ServantsManagementCard extends StatelessWidget {
  final AppProfile currentProfile;
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final Future<List<AppProfile>> servantsFuture;
  final VoidCallback onRefresh;

  const ServantsManagementCard({
    super.key,
    required this.currentProfile,
    required this.meetings,
    required this.classes,
    required this.servantsFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dbRepo = context.read<DatabaseRepository>();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أعضاء الكنيسة وإدارة الأدوار (خدام)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primary),
              ),
              TextButton.icon(
                onPressed: () => openInviteServantScreen(context),
                icon: const Icon(Icons.add_link, size: 16),
                label: Text('دعوة خادم مساعد', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 20),
          FutureBuilder<List<AppProfile>>(
            future: servantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              final servants = snapshot.data ?? [];
              if (servants.isEmpty) {
                return Text('لا يوجد خدام مسجلين حالياً.', style: GoogleFonts.cairo());
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: servants.length,
                itemBuilder: (context, index) {
                  final s = servants[index];
                  if (s.id == currentProfile.id) return const SizedBox.shrink();
                  return _ServantTile(
                    servant: s,
                    meetings: meetings,
                    classes: classes,
                    dbRepo: dbRepo,
                    onRefresh: onRefresh,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServantTile extends StatelessWidget {
  final AppProfile servant;
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final DatabaseRepository dbRepo;
  final VoidCallback onRefresh;

  const _ServantTile({
    required this.servant,
    required this.meetings,
    required this.classes,
    required this.dbRepo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(servant.fullName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(servant.email ?? servant.phone ?? '', style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textLight)),
              trailing: DropdownButton<AppRole>(
                value: servant.role,
                underline: const SizedBox.shrink(),
                style: GoogleFonts.cairo(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: AppRole.churchAdmin, child: Text('مدير كنيسة')),
                  DropdownMenuItem(value: AppRole.classLeader, child: Text('أمين فصل')),
                  DropdownMenuItem(value: AppRole.attendanceOfficer, child: Text('مسؤول حضور')),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    try {
                      await dbRepo.updateProfileRole(servant.id, val);
                      onRefresh();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'فشل تحديث الدور: ${e.toString()}',
                            style: GoogleFonts.cairo(),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            _ServantAssignmentsSection(servant: servant, dbRepo: dbRepo, meetings: meetings, classes: classes, onRefresh: onRefresh),
          ],
        ),
      ),
    );
  }
}

class _ServantAssignmentsSection extends StatelessWidget {
  final AppProfile servant;
  final DatabaseRepository dbRepo;
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final VoidCallback onRefresh;

  const _ServantAssignmentsSection({
    required this.servant,
    required this.dbRepo,
    required this.meetings,
    required this.classes,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        dbRepo.getUserClassAssignments(servant.id),
        dbRepo.getUserMeetingAssignments(servant.id),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 10, child: LinearProgressIndicator(color: AppTheme.primary));
        }
        final classAssigns = snapshot.data![0] as List<Map<String, dynamic>>;
        final meetingAssigns = snapshot.data![1] as List<Map<String, dynamic>>;

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFC), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التكليفات والمسؤوليات الحالية:', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              if (classAssigns.isEmpty && meetingAssigns.isEmpty)
                Text('لا توجد فصول أو اجتماعات مسندة لهذا الخادم.', style: GoogleFonts.cairo(fontSize: 10, color: AppTheme.textLight)),
              if (classAssigns.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 4, children: classAssigns.map((a) {
                  final classData = a['sunday_school_classes'] as Map<String, dynamic>?;
                  final className = classData?['name_ar'] ?? 'فصل';
                  final canTake = a['can_take_attendance'] as bool? ?? true;
                  final canView = a['can_view_reports'] as bool? ?? true;
                  return Chip(
                    label: Text('$className • ${canTake ? "حضور" : "بدون حضور"} • ${canView ? "تقارير" : "بدون تقارير"}', style: GoogleFonts.cairo(fontSize: 10)),
                    backgroundColor: AppTheme.primary.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 12, color: AppTheme.accentRed),
                    onDeleted: () async {
                      await dbRepo.removeClassAssignment(a['id'] as String);
                      onRefresh();
                    },
                  );
                }).toList()),
              if (meetingAssigns.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 4, children: meetingAssigns.map((a) {
                  final meetingData = a['meetings'] as Map<String, dynamic>?;
                  final meetingName = meetingData?['name_ar'] ?? 'اجتماع';
                  final canTake = a['can_take_attendance'] as bool? ?? true;
                  final canView = a['can_view_reports'] as bool? ?? true;
                  return Chip(
                    label: Text('$meetingName • ${canTake ? "حضور" : "بدون حضور"} • ${canView ? "تقارير" : "بدون تقارير"}', style: GoogleFonts.cairo(fontSize: 10)),
                    backgroundColor: Colors.teal.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 12, color: AppTheme.accentRed),
                    onDeleted: () async {
                      await dbRepo.removeMeetingAssignment(a['id'] as String);
                      onRefresh();
                    },
                  );
                }).toList()),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => showAddAssignmentDialog(context, servant, meetings, classes, onRefresh),
                  icon: const Icon(Icons.add, size: 12),
                  label: Text('إسناد مهمة جديدة', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
