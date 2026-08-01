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
  final _activationCodeController = TextEditingController();
  bool _useActivationCode = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

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
    if (_isInvitationLinkFlow) {
      _useActivationCode = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _churchController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final churchName = _churchController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final activationCode = _activationCodeController.text.trim();

    if (name.isEmpty ||
        (!_isInvitationLinkFlow && !_useActivationCode && churchName.isEmpty) ||
        (!_isInvitationLinkFlow &&
            _useActivationCode &&
            activationCode.isEmpty) ||
        email.isEmpty ||
        !email.contains('@') ||
        password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isInvitationLinkFlow
                ? 'أدخل الاسم والبريد وكلمة مرور من ٦ أحرف'
                : _useActivationCode
                ? 'أدخل الاسم وكود الدعوة والبريد وكلمة مرور من ٦ أحرف'
                : 'أدخل الاسم واسم الكنيسة والبريد وكلمة مرور من ٦ أحرف',
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
    } else if (_useActivationCode) {
      context.read<AuthBloc>().add(
        SignUpWithActivationCodeRequested(
          name: name,
          email: email,
          password: password,
          phone: phone.isEmpty ? null : phone,
          activationCode: activationCode,
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
        child: BlocConsumer<AuthBloc, AuthState>(
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
              final isUserAlreadyExists = msg.contains('already registered') ||
                  msg.contains('already exists') ||
                  msg.contains('موجود بالفعل') ||
                  msg.contains('مسجل بالفعل');

              if (isUserAlreadyExists) {
                _showExistingUserDialog(
                  email: _emailController.text.trim(),
                  activationCode: _activationCodeController.text.trim(),
                );
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
                const SizedBox(height: 24),
                Center(
                  child: Image.asset(
                    kLogoAsset,
                    width: 110,
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                AuthTitle(
                  title: _isInvitationLinkFlow
                      ? 'إكمال الانضمام'
                      : 'إنشاء حساب جديد',
                  subtitle: _isInvitationLinkFlow
                      ? 'أنشئ كلمة مرور لحسابك وانضم للكنيسة'
                      : _useActivationCode
                      ? 'استخدم كود الدعوة الذي أرسله مسؤول الخدمة'
                      : 'أنشئ كنيسة جديدة أو استخدم كود دعوة من مسؤول الخدمة',
                ),
                const SizedBox(height: 24),
                if (!_isInvitationLinkFlow)
                  AuthModeToggle(
                    useActivationCode: _useActivationCode,
                    isLoading: isLoading,
                    onChanged: (useCode) => setState(() {
                      _useActivationCode = useCode;
                      if (useCode) {
                        _churchController.clear();
                      } else {
                        _activationCodeController.clear();
                      }
                    }),
                  ),
                if (!_isInvitationLinkFlow) const SizedBox(height: 20),
                AuthFormSection(
                  children: [
                    const AuthFieldLabel('الاسم الكامل'),
                    AuthSoftTextField(
                      controller: _nameController,
                      hint: 'أدخل اسمك الكامل',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 18),
                    if (!_isInvitationLinkFlow && _useActivationCode) ...[
                      const AuthFieldLabel('كود الدعوة'),
                      AuthSoftTextField(
                        controller: _activationCodeController,
                        hint: 'ACT-123456',
                        icon: Icons.vpn_key_outlined,
                        latinInput: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اطلب الكود من مسؤول الكنيسة من شاشة الخدام والصلاحيات.',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else if (!_isInvitationLinkFlow) ...[
                      const AuthFieldLabel('اسم الكنيسة'),
                      AuthSoftTextField(
                        controller: _churchController,
                        hint: 'أدخل اسم الكنيسة',
                        icon: Icons.church_outlined,
                      ),
                      const SizedBox(height: 18),
                    ],
                    const AuthFieldLabel('البريد الإلكتروني'),
                    AuthSoftTextField(
                      controller: _emailController,
                      hint: 'example@domain.com',
                      icon: Icons.mail_outline,
                      latinInput: true,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    const AuthFieldLabel('رقم الهاتف (اختياري)'),
                    AuthSoftTextField(
                      controller: _phoneController,
                      hint: '05xxxxxxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      latinInput: true,
                    ),
                    const SizedBox(height: 18),
                    const AuthFieldLabel('كلمة المرور'),
                    AuthSoftTextField(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
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
                              : Icons.visibility_off,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.rtl,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: isLoading
                              ? null
                              : (value) => setState(
                                  () => _acceptedTerms = value ?? false,
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text.rich(
                              TextSpan(
                                text: 'أوافق على ',
                                children: [
                                  TextSpan(
                                    text: 'شروط الخدمة وسياسة الخصوصية',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const TextSpan(text: ' الخاصة بـ Link'),
                                ],
                              ),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: isLoading ? 'جاري إنشاء الحساب...' : 'إنشاء حساب',
                      icon: isLoading ? null : Icons.person_add_alt,
                      onTap: isLoading ? () {} : _submit,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: GoogleFonts.cairo(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '• متصلين بمحبة، ننمو معاً •',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.textLight.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showExistingUserDialog({
    required String email,
    required String activationCode,
  }) {
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
                      activationCode:
                          activationCode.isNotEmpty ? activationCode : null,
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
