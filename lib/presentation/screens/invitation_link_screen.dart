import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/errors/arabic_error_text.dart';
import '../../core/invitations/invitation_identity.dart';
import '../../core/invitations/invitation_preview.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/database_repository.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../shared/ui/app_states.dart';
import 'login_screen.dart';

class InvitationLinkScreen extends StatefulWidget {
  final String inviteToken;

  const InvitationLinkScreen({super.key, required this.inviteToken});

  @override
  State<InvitationLinkScreen> createState() => _InvitationLinkScreenState();
}

class _InvitationLinkScreenState extends State<InvitationLinkScreen> {
  InvitationPreview? _preview;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Object? _error;

  bool _matchesAuthenticatedAccount(AuthState state) {
    if (state is! AuthAuthenticated) return false;
    return invitationEmailMatchesAccount(
      invitationEmail: _preview?.email,
      accountEmail: state.profile.email,
    );
  }

  bool _hasMismatchedAuthenticatedAccount(AuthState state) =>
      state is AuthAuthenticated && !_matchesAuthenticatedAccount(state);

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = context.read<DatabaseRepository>();
      final preview = await repo.getInvitationPreview(widget.inviteToken);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _decline() async {
    final authState = context.read<AuthBloc>().state;
    if (!_matchesAuthenticatedAccount(authState)) {
      await _switchAccountAndOpen(login: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رفض الدعوة؟', style: GoogleFonts.cairo()),
        content: Text(
          'لن تتمكن من استخدام هذا الرابط مرة أخرى.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'رفض الدعوة',
              style: GoogleFonts.cairo(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<DatabaseRepository>();
      await repo.declineInvitationByToken(widget.inviteToken);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رفض الدعوة', style: GoogleFonts.cairo())),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _accept() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (!_matchesAuthenticatedAccount(authState)) {
        await _switchAccountAndOpen(login: false);
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        final repo = context.read<DatabaseRepository>();
        await repo.acceptInvitationLink(widget.inviteToken);
        if (!mounted) return;
        context.read<AuthBloc>().add(AuthCheckRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم قبول الدعوة بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(arabicErrorText(error), style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: RegistrationScreen(
            invitationToken: widget.inviteToken,
            initialName: _preview?.inviteeName,
            initialEmail: _preview?.email,
          ),
        ),
      ),
    );
  }

  Future<void> _switchAccountAndOpen({required bool login}) async {
    final preview = _preview;
    if (preview == null || !preview.valid) return;

    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthAuthenticated) {
      setState(() => _isSubmitting = true);
      authBloc.add(SwitchToInvitationAccountRequested());
      try {
        await authBloc.stream.firstWhere(
          (state) => state is AuthInvitationAccountReady || state is AuthError,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: authBloc,
        child: login
            ? LoginScreen(
                initialEmail: preview.email,
                invitationToken: widget.inviteToken,
              )
            : RegistrationScreen(
                invitationToken: widget.inviteToken,
                initialName: preview.inviteeName,
                initialEmail: preview.email,
              ),
      ),
    );

    await Navigator.pushReplacement(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'دعوة للانضمام',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return AppErrorState(message: _error.toString(), onRetry: _loadPreview);
    }

    final preview = _preview;
    if (preview == null || !preview.valid) {
      final message = switch (preview?.status) {
        'declined' => 'تم رفض هذه الدعوة مسبقاً.',
        'used' => 'تم استخدام هذه الدعوة بالفعل.',
        _ => 'رابط الدعوة غير صالح أو منتهي.',
      };
      return AppEmptyState(icon: Icons.link_off_rounded, message: message);
    }

    final authState = context.read<AuthBloc>().state;
    final accountMismatch = _hasMismatchedAuthenticatedAccount(authState);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.75),
              ),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.churchName ?? 'الكنيسة',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'دعوة للانضمام كخادم عبر Link',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'الاسم', value: preview.inviteeName ?? '—'),
                if (preview.email != null && preview.email!.trim().isNotEmpty)
                  _InfoRow(label: 'البريد', value: preview.email!),
                _InfoRow(label: 'نطاق الخدمة', value: preview.scopeLabel),
                _InfoRow(
                  label: 'الصلاحيات',
                  value: preview.permissions.join(' • '),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'بعد القبول ستحصل على صلاحيات العمل في المكان المحدد داخل التطبيق.',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppTheme.textLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          if (accountMismatch) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(
                invitationAccountMismatchMessage(preview.email),
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _isSubmitting ? null : _accept,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    accountMismatch
                        ? 'تسجيل الخروج وإنشاء حساب المدعو'
                        : authState is AuthAuthenticated
                        ? 'قبول والانضمام'
                        : 'إنشاء حساب لقبول الدعوة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _isSubmitting ? null : _decline,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
              side: const BorderSide(color: AppTheme.accentRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              accountMismatch
                  ? 'تسجيل الخروج والدخول بحساب المدعو'
                  : authState is AuthAuthenticated
                  ? 'رفض الدعوة'
                  : 'لدي حساب بالفعل',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
