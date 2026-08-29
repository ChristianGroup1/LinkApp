part of 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'كلمة المرور يجب أن تكون ٦ أحرف على الأقل',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'كلمتا المرور غير متطابقتين',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(PasswordUpdateRequested(password: password));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthPasswordUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تحديث كلمة المرور بنجاح 🎉',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              // Return to AuthenticationGate instead of replacing it with a
              // standalone LoginScreen. The gate owns the transition to the
              // dashboard after the next successful login.
              Navigator.of(context).popUntil((route) => route.isFirst);
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
            final isLoading = state is AuthPasswordUpdateLoading;

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
                  children: [AuthLogoMark(size: 130), SizedBox(height: 14)],
                ),
                const SizedBox(height: 24),
                // Main Floating White Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
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
                        'تعيين كلمة مرور جديدة',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل كلمة المرور الجديدة لحسابك لتأكيد التغيير',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // New Password Input
                      const AuthFieldLabel('كلمة المرور الجديدة'),
                      AuthSoftTextField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        trailing: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password Input
                      const AuthFieldLabel('تأكيد كلمة المرور'),
                      AuthSoftTextField(
                        controller: _confirmController,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                      ),
                      const SizedBox(height: 28),
                      // Save Pill Button
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
                                  'حفظ كلمة المرور الجديدة 🔒',
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
