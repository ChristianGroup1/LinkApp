import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/database_repository.dart';
import '../../logic/auth/auth_bloc.dart';
import '../widgets/auth_widgets.dart';

// RegistrationScreen
part 'registration_screen.dart';
// ForgotPasswordScreen
part 'forgot_password_screen.dart';
// ResetPasswordScreen
part 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? invitationToken;
  final String? activationCode;

  const LoginScreen({
    super.key,
    this.initialEmail,
    this.invitationToken,
    this.activationCode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rememberKey = 'login_remember_me';
  static const _emailKey = 'login_remembered_email';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool remember = false;
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    } else {
      _loadRememberedCredentials();
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRemember = prefs.getBool(_rememberKey) ?? false;
    final savedEmail = prefs.getString(_emailKey) ?? '';
    if (!mounted) return;
    setState(() {
      remember = shouldRemember;
      if (shouldRemember && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
    });
  }

  Future<void> _persistRememberPreference(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    if (remember) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    final email = _emailController.text.trim();
    // Copying a password from messages or email can include an invisible
    // trailing space/newline. Remove only trailing whitespace so intentional
    // leading characters are preserved.
    final password = _passwordController.text.trimRight();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'أدخل البريد الإلكتروني وكلمة المرور أولاً',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    _persistRememberPreference(email);
    context.read<AuthBloc>().add(
      LoginRequested(email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              final inviteToken = widget.invitationToken;
              if (inviteToken != null && inviteToken.isNotEmpty) {
                context
                    .read<DatabaseRepository>()
                    .acceptInvitationLink(inviteToken)
                    .then((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تسجيل الدخول وتفعيل الدعوة بنجاح 🎉',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    })
                    .catchError((_) {});
              }
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, style: GoogleFonts.cairo()),
                  backgroundColor: AppTheme.accentRed,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(height: 12),
                // Top App Logo & Branding Header
                Column(
                  children: [
                    const AuthLogoMark(size: 130),
                    const SizedBox(height: 14),
                  ],
                ),
                const SizedBox(height: 24),
                // Main Floating White Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل البريد الإلكتروني وكلمة المرور للبدء',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Email Soft Grey Input
                      const AuthFieldLabel('البريد الإلكتروني'),
                      AuthSoftTextField(
                        controller: _emailController,
                        hint: 'البريد الإلكتروني أو اسم المستخدم',
                        icon: Icons.alternate_email_rounded,
                        latinInput: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      // Password Soft Grey Input
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: AuthFieldLabel('كلمة المرور')),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'نسيت كلمة المرور؟',
                              style: GoogleFonts.cairo(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AuthSoftTextField(
                        controller: _passwordController,
                        hint: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        obscureText: obscure,
                        trailing: IconButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: remember,
                              onChanged: isLoading
                                  ? null
                                  : (value) => setState(
                                      () => remember = value ?? false,
                                    ),
                              activeColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setState(() => remember = !remember),
                            child: Text(
                              'تذكرني',
                              style: GoogleFonts.cairo(
                                color: const Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Vibrant Blue Pill Button
                      FilledButton(
                        onPressed: isLoading ? null : _submitLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 4,
                          shadowColor: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.35),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'تسجيل الدخول',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 20),
                      // Registration Link Prompt inside card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            'ليس لديك حساب؟ ',
                            style: GoogleFonts.cairo(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegistrationScreen(),
                                    ),
                                  ),
                            child: Text(
                              'إنشاء حساب',
                              style: GoogleFonts.cairo(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'LinkApp © 2026 جميع الحقوق محفوظة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}
