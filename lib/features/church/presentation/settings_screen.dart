import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../shared/ui/app_widgets.dart';
import '../logic/church_bloc.dart';
import '../../../presentation/widgets/in_app_spotlight_overlay.dart';
import '../../../presentation/screens/app_tour_screen.dart';
import '../../../presentation/screens/my_invitations_screen.dart';
import 'servants_permissions_screen.dart';
import 'widgets/compact_settings_dialog.dart';
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
        } else if (state is ChurchContextLoaded && state.flashMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.flashMessage!, style: GoogleFonts.cairo()),
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
          icon: Icons.mark_email_unread_outlined,
          title: 'الدعوات الواردة',
          subtitle: 'مراجعة وقبول أو رفض دعوات الخدمة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MyInvitationsScreen(),
            ),
          ),
        ),
        Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.7)),
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
        Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.7)),
        _ProfileActionRow(
          icon: Icons.auto_awesome_rounded,
          title: 'جولة في التطبيق 🚀',
          subtitle: 'عرض الجولة التعريفية المباشرة لميزات التطبيق',
          onTap: () async {
            await AppTourScreen.resetTourCompleted();
            if (context.mounted) {
              final tourNotifier = InAppTourNotifier.of(context);
              if (tourNotifier != null) {
                tourNotifier.startTour();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppTourScreen(),
                    fullscreenDialog: true,
                  ),
                );
              }
            }
          },
        ),
      ],
    ),
  );

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AppProfile profile,
  ) async {
    await showCompactSettingsDialog<void>(
      context: context,
      title: 'تعديل البيانات الشخصية',
      subtitle: 'حدّث اسمك ورقم التواصل',
      icon: Icons.manage_accounts_outlined,
      child: _EditProfileDialogForm(profile: profile, hostContext: context),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    await showCompactSettingsDialog<void>(
      context: context,
      title: 'تغيير كلمة المرور',
      subtitle: 'استخدم كلمة قوية لحماية حسابك',
      icon: Icons.lock_reset_rounded,
      child: _ChangePasswordDialogForm(hostContext: context),
    );
  }
}

class _EditProfileDialogForm extends StatefulWidget {
  final AppProfile profile;
  final BuildContext hostContext;

  const _EditProfileDialogForm({
    required this.profile,
    required this.hostContext,
  });

  @override
  State<_EditProfileDialogForm> createState() => _EditProfileDialogFormState();
}

class _EditProfileDialogFormState extends State<_EditProfileDialogForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.hostContext.read<DatabaseRepository>().updateCurrentProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (!widget.hostContext.mounted) return;
      widget.hostContext.read<ChurchBloc>().add(LoadChurchContext());
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text('تم حفظ البيانات الشخصية', style: GoogleFonts.cairo()),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'الاسم الكامل',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              prefixIconConstraints: BoxConstraints(minWidth: 42),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'الاسم الكامل مطلوب'
                : null,
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
              prefixIconConstraints: BoxConstraints(minWidth: 42),
            ),
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 15),
          CompactDialogActions(
            primaryLabel: 'حفظ التعديلات',
            onPrimary: _save,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialogForm extends StatefulWidget {
  final BuildContext hostContext;

  const _ChangePasswordDialogForm({required this.hostContext});

  @override
  State<_ChangePasswordDialogForm> createState() =>
      _ChangePasswordDialogFormState();
}

class _ChangePasswordDialogFormState extends State<_ChangePasswordDialogForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.hostContext.read<DatabaseRepository>().updatePassword(
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (!widget.hostContext.mounted) return;
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text(
            'تم تغيير كلمة المرور بنجاح',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text('تعذر تغيير كلمة المرور.', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _passwordController,
            autofocus: true,
            obscureText: _hidePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                ),
              ),
            ),
            validator: (value) => value == null || value.length < 6
                ? 'كلمة المرور يجب ألا تقل عن 6 أحرف'
                : null,
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: _confirmController,
            obscureText: _hideConfirmation,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _hideConfirmation = !_hideConfirmation),
                icon: Icon(
                  _hideConfirmation
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                ),
              ),
            ),
            validator: (value) => value != _passwordController.text
                ? 'كلمتا المرور غير متطابقتين'
                : null,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.textLight,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'استخدم 6 أحرف على الأقل',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CompactDialogActions(
            primaryLabel: 'تحديث كلمة المرور',
            onPrimary: _save,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
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
