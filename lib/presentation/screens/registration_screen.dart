part of 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String? invitationToken;
  final String? initialName;
  final String? initialEmail;

  const RegistrationScreen({
    super.key,
    this.invitationToken,
    this.initialName,
    this.initialEmail,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _churchController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _isInvitationLinkFlow => widget.invitationToken != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _nameController.text = widget.initialName!.trim();
    }
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _churchController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final churchName = _churchController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    // Keep signup and login normalization identical. Pasted passwords can
    // contain an invisible trailing space/newline; storing that character and
    // later removing it during login makes the freshly created password fail.
    final password = _passwordController.text.trimRight();
    final confirmPassword = _confirmPasswordController.text.trimRight();

    if (name.isEmpty ||
        (!_isInvitationLinkFlow && churchName.isEmpty) ||
        email.isEmpty ||
        !email.contains('@') ||
        password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isInvitationLinkFlow
                ? 'أدخل الاسم والبريد وكلمة مرور من ٦ أحرف'
                : 'أدخل الاسم واسم الكنيسة والبريد وكلمة مرور من ٦ أحرف',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'كلمة المرور وتأكيد كلمة المرور غير متطابقين',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يجب الموافقة على شروط الخدمة وسياسة الخصوصية',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (_isInvitationLinkFlow) {
      context.read<AuthBloc>().add(
        SignUpWithInvitationTokenRequested(
          name: name,
          email: email,
          password: password,
          phone: phone.isEmpty ? null : phone,
          inviteToken: widget.invitationToken!,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        SignUpRequested(
          name: name,
          churchName: churchName,
          email: email,
          password: password,
          phone: phone.isEmpty ? null : phone,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        builder: (context) => BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (state is AuthSignUpConfirmationSent) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيد الحساب.',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );
              Navigator.pop(context);
            } else if (state is AuthError) {
              final msg = state.message.toLowerCase();
              final isUserAlreadyExists =
                  msg.contains('already registered') ||
                  msg.contains('already exists') ||
                  msg.contains('موجود بالفعل') ||
                  msg.contains('مسجل بالفعل');

              if (isUserAlreadyExists) {
                _showExistingUserDialog(email: _emailController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message, style: GoogleFonts.cairo()),
                    backgroundColor: AppTheme.accentRed,
                  ),
                );
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                AuthBackButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                // Top App Logo Header
                Column(
                  children: [
                    const AuthLogoMark(size: 130),
                    const SizedBox(height: 14),
                  ],
                ),
                const SizedBox(height: 24),
                AuthFormCard(
                  children: [
                    Text(
                      _isInvitationLinkFlow
                          ? 'إكمال الانضمام'
                          : 'إنشاء حساب جديد',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isInvitationLinkFlow
                          ? 'أنشئ كلمة مرور لحسابك وانضم للكنيسة'
                          : 'أدخل بياناتك لإنشاء حساب خادم جديد',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: AppTheme.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Name Input
                    const AuthFieldLabel('الاسم الكامل'),
                    AuthSoftTextField(
                      controller: _nameController,
                      hint: 'أدخل اسمك الكامل',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    // Church Name Input (if not invitation link flow)
                    if (!_isInvitationLinkFlow) ...[
                      const AuthFieldLabel('اسم الكنيسة'),
                      AuthSoftTextField(
                        controller: _churchController,
                        hint: 'أدخل اسم الكنيسة',
                        icon: Icons.church_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Email Input
                    const AuthFieldLabel('البريد الإلكتروني'),
                    AuthSoftTextField(
                      controller: _emailController,
                      hint: 'example@domain.com',
                      icon: Icons.alternate_email_rounded,
                      latinInput: true,
                      readOnly: _isInvitationLinkFlow,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Phone Input
                    const AuthFieldLabel('رقم الهاتف (اختياري)'),
                    AuthSoftTextField(
                      controller: _phoneController,
                      hint: '01xxxxxxxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      latinInput: true,
                    ),
                    const SizedBox(height: 16),
                    // Password Input
                    const AuthFieldLabel('كلمة المرور'),
                    AuthSoftTextField(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      trailing: IconButton(
                        onPressed: isLoading
                            ? null
                            : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textLight,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const AuthFieldLabel('تأكيد كلمة المرور'),
                    AuthSoftTextField(
                      controller: _confirmPasswordController,
                      hint: 'أعد إدخال كلمة المرور',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      trailing: IconButton(
                        onPressed: isLoading
                            ? null
                            : () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textLight,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Terms & Conditions Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.rtl,
                      children: [
                        AuthCheckbox(
                          value: _acceptedTerms,
                          onChanged: isLoading
                              ? null
                              : (value) => setState(
                                  () => _acceptedTerms = value ?? false,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () => setState(
                                    () => _acceptedTerms = !_acceptedTerms,
                                  ),
                            child: Text.rich(
                              TextSpan(
                                text: 'أوافق على ',
                                children: [
                                  TextSpan(
                                    text: 'شروط الخدمة وسياسة الخصوصية',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.primaryAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const TextSpan(text: ' الخاصة بـ LinkApp'),
                                ],
                              ),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Vibrant Blue Pill Button
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        minimumSize: const Size.fromHeight(52),
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
                              _isInvitationLinkFlow
                                  ? 'إكمال وتأكيد الانضمام'
                                  : 'إنشاء حساب جديد',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 20),
                    // Already Have Account Prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          'لديك حساب بالفعل؟ ',
                          style: GoogleFonts.cairo(
                            color: AppTheme.textLight,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : () {
                                  if (_isInvitationLinkFlow) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(
                                          initialEmail: widget.initialEmail,
                                          invitationToken:
                                              widget.invitationToken,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                          child: Text(
                            'تسجيل الدخول',
                            style: GoogleFonts.cairo(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'LinkApp © 2026 جميع الحقوق محفوظة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
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

  void _showExistingUserDialog({required String email}) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.account_circle_rounded,
            color: AppTheme.primary,
            size: 48,
          ),
          title: Text(
            'لديك حساب بالفعل!',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'هذا البريد الإلكتروني مسجل مسبقاً في التطبيق. قم بتسجيل الدخول وسنربط حسابك بالدعوة تلقائياً.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(height: 1.5, fontSize: 13),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      initialEmail: email,
                      invitationToken: widget.invitationToken,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'تسجيل الدخول وتفعيل الدعوة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
