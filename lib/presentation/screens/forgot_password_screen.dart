part of 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى كتابة البريد الإلكتروني الصحيح أولاً',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    context.read<AuthBloc>().add(
          PasswordResetEmailRequested(email: email),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthPasswordResetEmailSent) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال رابط إعادة التعيين بنجاح إلى بريدك الإلكتروني 📩',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AuthPasswordResetError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, style: GoogleFonts.cairo()),
                  backgroundColor: AppTheme.accentRed,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthPasswordResetEmailLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                AuthBackButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                // Top App Logo Header
                const Column(
                  children: [
                    AuthLogoMark(size: 130),
                    SizedBox(height: 14),
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
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'إعادة تعيين كلمة المرور',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
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
                        hint: 'example@domain.com',
                        icon: Icons.alternate_email_rounded,
                        latinInput: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 28),
                      // Submit Pill Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                                  'إرسال رابط إعادة التعيين 📩',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
