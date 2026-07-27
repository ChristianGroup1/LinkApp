import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../logic/auth/auth_bloc.dart';
import '../widgets/auth_widgets.dart';

// RegistrationScreen
part 'registration_screen.dart';
// ForgotPasswordScreen
part 'forgot_password_screen.dart';
// ResetPasswordScreen
part 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    _loadRememberedCredentials();
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
    final password = _passwordController.text;

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
            if (state is AuthError) {
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
                const SizedBox(height: 16),
                const Center(child: AuthLogoMark(size: 96)),
                const SizedBox(height: 16),
                Text(
                  'LINK',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'إدارة الكنيسة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  'أهلاً بك',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سجل دخولك للوصول إلى لوحة إدارة الحضور والخدمة في لينك',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                AuthFormSection(
                  children: [
                      const AuthFieldLabel('البريد الإلكتروني'),
                      AuthSoftTextField(
                        controller: _emailController,
                        hint: 'example@link.org',
                        icon: Icons.mail_outline,
                        latinInput: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: AuthFieldLabel('كلمة المرور'),
                          ),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                            child: Text(
                              'نسيت كلمة السر؟',
                              style: GoogleFonts.cairo(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AuthSoftTextField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: obscure,
                        trailing: IconButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Switch(
                            value: remember,
                            onChanged: isLoading
                                ? null
                                : (value) =>
                                      setState(() => remember = value),
                            activeTrackColor: AppTheme.primary,
                          ),
                          Text(
                            'تذكرني',
                            style: GoogleFonts.cairo(
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AuthPrimaryButton(
                        label: isLoading
                            ? 'جاري تسجيل الدخول...'
                            : 'تسجيل الدخول',
                        icon: isLoading ? null : Icons.login,
                        onTap: isLoading ? () {} : _submitLogin,
                      ),
                    ],
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      'ليس لديك حساب؟ ',
                      style: GoogleFonts.cairo(color: AppTheme.textLight),
                    ),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegistrationScreen(),
                              ),
                            ),
                      child: Text(
                        'إنشاء حساب',
                        style: GoogleFonts.cairo(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  '© LINK 2026 جميع الحقوق محفوظة\nالإصدار 1.0.0',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFA8B0C2),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
