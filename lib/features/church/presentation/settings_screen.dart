import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../shared/ui/app_widgets.dart';
import '../logic/church_bloc.dart';
import 'servants_permissions_screen.dart';
import 'widgets/settings_cards.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChurchBloc, ChurchState>(
      listener: (context, state) {
        if (state is ChurchError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is ChurchLoading) {
          return const SettingsFallbackScaffold(
            message: 'جاري تحميل بيانات الخدمة...',
            isLoading: true,
          );
        }
        if (state is ChurchError) {
          return SettingsFallbackScaffold(message: state.message);
        }
        if (state is! ChurchContextLoaded) {
          return const SettingsFallbackScaffold(
            message: 'تعذر تحميل بيانات الخدمة.',
          );
        }

        final profile = state.profile;
        final church = state.church;
        final isAdmin =
            profile.role == AppRole.superAdmin ||
            profile.role == AppRole.churchAdmin;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'إعدادات الحساب والخدمة',
                style: GoogleFonts.cairo(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
            body: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async =>
                  context.read<ChurchBloc>().add(LoadChurchContext()),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  UserProfileCard(profile: profile),
                  const SizedBox(height: 10),
                  _ProfileActionsCard(profile: profile),
                  if (church != null) ...[
                    const SizedBox(height: 20),
                    const AppSectionHeader(title: 'بيانات الخدمة'),
                    const SizedBox(height: 9),
                    ChurchProfileCard(church: church, isAdmin: isAdmin),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    const AppSectionHeader(title: 'الإدارة والصلاحيات'),
                    const SizedBox(height: 9),
                    ServantsPermissionsEntryCard(
                      destination: const ServantsPermissionsScreen(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const AppSectionHeader(title: 'الحساب'),
                  const SizedBox(height: 9),
                  _SignOutCard(
                    onTap: () =>
                        context.read<AuthBloc>().add(LogoutRequested()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileActionsCard extends StatelessWidget {
  final AppProfile profile;
  const _ProfileActionsCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
    ),
    child: Column(
      children: [
        _ProfileActionRow(
          icon: Icons.edit_outlined,
          title: 'تعديل البيانات الشخصية',
          subtitle: 'الاسم ورقم الهاتف',
          onTap: () => _showEditProfileDialog(context, profile),
        ),
        Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.7)),
        _ProfileActionRow(
          icon: Icons.lock_outline_rounded,
          title: 'تغيير كلمة المرور',
          subtitle: 'اختر كلمة مرور جديدة لحسابك',
          onTap: () => _showChangePasswordDialog(context),
        ),
      ],
    ),
  );

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AppProfile profile,
  ) async {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'تعديل البيانات الشخصية',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                await context.read<DatabaseRepository>().updateCurrentProfile(
                  fullName: name,
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                context.read<ChurchBloc>().add(LoadChurchContext());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حفظ بيانات البروفايل',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذر حفظ البيانات، حاول مرة أخرى.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                }
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'تغيير كلمة المرور',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.length < 6 ||
                  passwordController.text != confirmController.text)
                return;
              try {
                await context.read<DatabaseRepository>().updatePassword(
                  passwordController.text,
                );
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تغيير كلمة المرور بنجاح',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذر تغيير كلمة المرور.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                }
              }
            },
            child: Text('تحديث', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
    passwordController.dispose();
    confirmController.dispose();
  }
}

class _ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppTheme.primary, size: 20),
    ),
    title: Text(
      title,
      style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13),
    ),
    subtitle: Text(
      subtitle,
      style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 10),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppTheme.textLight,
    ),
  );
}

class _SignOutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.24)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.accentRedLight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.accentRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تسجيل الخروج',
                style: GoogleFonts.cairo(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.accentRed),
          ],
        ),
      ),
    ),
  );
}
