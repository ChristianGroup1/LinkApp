part of 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _emailSent = false;

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
    context.read<AuthBloc>().add(PasswordResetEmailRequested(email: email));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        builder: (context) => BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthPasswordResetEmailSent) {
              setState(() => _emailSent = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال رابط إعادة التعيين بنجاح إلى بريدك الإلكتروني 📩',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: AppTheme.secondary,
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
                const AuthScreenHeader(),
                const SizedBox(height: 24),
                AuthFormCard(
                  children: [
                    if (_emailSent) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              color: AppTheme.secondary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تحقق من بريدك الإلكتروني وافتح الرابط لإكمال تعيين كلمة المرور.',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    AuthScreenTitle(
                      title: _emailSent
                          ? 'تم إرسال الرابط'
                          : 'إعادة تعيين كلمة المرور',
                      subtitle: _emailSent
                          ? 'إذا لم يصلك البريد خلال دقائق، تحقق من مجلد الرسائل غير المرغوب فيها.'
                          : 'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
                      titleSize: 20,
                    ),
                    if (!_emailSent) ...[
                      const AuthFieldLabel('البريد الإلكتروني'),
                      AuthSoftTextField(
                        controller: _emailController,
                        hint: 'example@domain.com',
                        icon: Icons.alternate_email_rounded,
                        latinInput: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 4,
                            shadowColor: AppTheme.primaryAccent.withValues(
                              alpha: 0.35,
                            ),
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
                    ] else ...[
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() => _emailSent = false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryAccent,
                            side: BorderSide(
                              color: AppTheme.primaryAccent.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: Text(
                            'إرسال رابط جديد',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'العودة لتسجيل الدخول',
                          style: GoogleFonts.cairo(
                            color: AppTheme.textLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
