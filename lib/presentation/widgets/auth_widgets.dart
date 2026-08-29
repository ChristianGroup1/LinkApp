import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

const String kLogoAsset = 'assets/images/link_logo.png';

class AuthShell extends StatelessWidget {
  final Widget child;
  final bool compact;

  const AuthShell({super.key, required this.child, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final desktop = AppTheme.isNativeDesktop;
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFF7F7FF),
                  Color(0xFFEEF2FF),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),
          Positioned(
            top: compact ? -60 : -40,
            right: compact ? -40 : -60,
            child: AuthGlow(
              size: compact ? 220 : 280,
              color: const Color(0xFF8DBDFF).withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            bottom: compact ? -60 : -50,
            left: compact ? -50 : -60,
            child: AuthGlow(
              size: compact ? 240 : 300,
              color: AppTheme.primary.withValues(alpha: 0.22),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                desktop ? 48 : 22,
                desktop ? 32 : 12,
                desktop ? 48 : 22,
                desktop ? 48 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktop ? 640 : double.infinity,
                    minHeight: compact
                        ? 0
                        : MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.vertical -
                              (desktop ? 80 : 24),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر رجوع — أيقونة فقط أعلى اليمين.
class AuthBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AuthBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: AppTheme.cardBackground,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthLogoMark extends StatelessWidget {
  final double size;

  const AuthLogoMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          kLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'شعار تطبيق لينك',
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppTheme.textDark,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: AppTheme.textLight,
            height: 1.6,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2, end: 2),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: GoogleFonts.cairo(
          color: AppTheme.textDark,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class AuthFormSection extends StatelessWidget {
  final List<Widget> children;

  const AuthFormSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: children,
      ),
    );
  }
}

class AuthSoftTextField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final Widget? trailing;
  final bool obscureText;
  final bool latinInput;
  final bool readOnly;
  final TextInputType? keyboardType;

  const AuthSoftTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.trailing,
    this.obscureText = false,
    this.latinInput = false,
    this.readOnly = false,
    this.keyboardType,
  });

  @override
  State<AuthSoftTextField> createState() => _AuthSoftTextFieldState();
}

class _AuthSoftTextFieldState extends State<AuthSoftTextField> {
  bool _focused = false;

  static const _fieldBg = Color(0xFFF8FAFC);
  static const _fieldBorder = Color(0xFFE2E8F0);
  static final _borderRadius = BorderRadius.circular(16);

  InputBorder _outlineBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: _borderRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldDirection = widget.latinInput
        ? TextDirection.ltr
        : TextDirection.rtl;
    const fieldAlign = TextAlign.right;
    final borderColor = _focused ? AppTheme.primary : _fieldBorder;
    final borderWidth = _focused ? 1.5 : 1.0;
    final outline = _outlineBorder(borderColor, borderWidth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            readOnly: widget.readOnly,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textDirection: fieldDirection,
            textAlign: fieldAlign,
            cursorColor: AppTheme.primary,
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintTextDirection: fieldDirection,
              alignLabelWithHint: true,
              hintStyle: GoogleFonts.cairo(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              filled: true,
              fillColor: _fieldBg,
              prefixIcon: Icon(
                widget.icon,
                color: _focused ? AppTheme.primary : AppTheme.textLight,
                size: 21,
              ),
              suffixIcon: widget.trailing,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: outline,
              enabledBorder: outline,
              focusedBorder: outline,
              disabledBorder: outline,
              errorBorder: outline,
              focusedErrorBorder: outline,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGlow extends StatelessWidget {
  final double size;
  final Color color;

  const AuthGlow({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.12), Colors.transparent],
        ),
      ),
    );
  }
}

class AuthPagerDots extends StatelessWidget {
  const AuthPagerDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Container(
          width: index == 0 ? 18 : 8,
          height: 8,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: index == 0 ? 0.35 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class AuthModeToggle extends StatelessWidget {
  final bool useActivationCode;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const AuthModeToggle({
    super.key,
    required this.useActivationCode,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: RegisterModeButton(
              label: 'كنيسة جديدة',
              selected: !useActivationCode,
              onTap: isLoading ? null : () => onChanged(false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RegisterModeButton(
              label: 'عندي كود دعوة',
              selected: useActivationCode,
              onTap: isLoading ? null : () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const RegisterModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.15))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? AppTheme.primary : AppTheme.textLight,
          ),
        ),
      ),
    );
  }
}
