part of 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _destinationController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.rtl,
          children: [
            AuthBackButton(onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 28),
            const AuthLogoMark(size: 96),
            const SizedBox(height: 18),
            Text(
              'Link',
              style: GoogleFonts.outfit(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 44),
            AuthTitle(
              title: 'نسيت كلمة السر',
              subtitle:
                  'لا تقلق، أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة السر داخل التطبيق.',
            ),
            const SizedBox(height: 46),
            AuthFormSection(
              children: [
                const AuthFieldLabel('البريد الإلكتروني'),
                AuthSoftTextField(
                  controller: _destinationController,
                  hint: 'example@mail.com',
                  icon: Icons.alternate_email,
                  latinInput: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'إرسال رابط إعادة التعيين',
                  icon: Icons.send_outlined,
                  onTap: () async {
                    final destination = _destinationController.text.trim();
                    if (destination.isEmpty || !destination.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'أدخل بريد إلكتروني صحيح أولاً',
                            style: GoogleFonts.cairo(),
                          ),
                        ),
                      );
                      return;
                    }
                    context.read<AuthBloc>().add(
                      PasswordResetEmailRequested(email: destination),
                    );
                  },
                ),
              ],
            ),
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthPasswordResetEmailSent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني',
                        style: GoogleFonts.cairo(),
                      ),
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
              child: const SizedBox.shrink(),
            ),
            const SizedBox(height: 50),
            Text(
              'هل ما زلت تواجه مشكلة؟',
              style: GoogleFonts.cairo(color: AppTheme.textLight),
            ),
            const SizedBox(height: 8),
            Text(
              'تواصل مع الدعم الفني',
              style: GoogleFonts.cairo(
                color: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            const AuthPagerDots(),
          ],
        ),
      ),
    );
  }
}
