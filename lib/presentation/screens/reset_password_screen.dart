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
            'كلمة السر يجب أن تكون ٦ أحرف على الأقل',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('كلمتا السر غير متطابقتين', style: GoogleFonts.cairo()),
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
                    'تم تحديث كلمة السر بنجاح',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
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
            final isLoading = state is AuthPasswordUpdateLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                AuthBackButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                ),
                const SizedBox(height: 36),
                const AuthLogoMark(size: 96),
                const SizedBox(height: 30),
                AuthTitle(
                  title: 'تعيين كلمة سر جديدة',
                  subtitle:
                      'اكتب كلمة السر الجديدة لحسابك. سيتم حفظها مباشرة بعد فتح رابط الاسترداد من البريد.',
                ),
                const SizedBox(height: 42),
                AuthFormSection(
                  children: [
                    const AuthFieldLabel('كلمة السر الجديدة'),
                    AuthSoftTextField(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      trailing: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const AuthFieldLabel('تأكيد كلمة السر'),
                    AuthSoftTextField(
                      controller: _confirmController,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 28),
                    AuthPrimaryButton(
                      label: isLoading ? 'جاري الحفظ...' : 'حفظ كلمة السر',
                      icon: isLoading ? null : Icons.save_outlined,
                      onTap: isLoading ? () {} : _submit,
                    ),
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
