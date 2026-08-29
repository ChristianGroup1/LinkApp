import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/password_recovery_link.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class PasswordRecoveryErrorScreen extends StatelessWidget {
  final PasswordRecoveryLinkError error;

  const PasswordRecoveryErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final expired = error.isExpiredOrUsed;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AuthShell(
        compact: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const AuthScreenHeader(logoSize: 90),
            const SizedBox(height: 24),
            AuthFormCard(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentRed.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.link_off_rounded,
                        color: AppTheme.accentRed,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  expired
                      ? 'رابط إعادة التعيين غير صالح'
                      : 'تعذر فتح رابط إعادة التعيين',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  expired
                      ? 'الرابط انتهت صلاحيته أو تم استخدامه من قبل. اطلب رابطاً جديداً لإكمال تغيير كلمة المرور.'
                      : 'حدث خطأ أثناء التحقق من الرابط. اطلب رابطاً جديداً ثم حاول مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      'طلب رابط جديد',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: AppTheme.textLight,
                  ),
                  label: Text(
                    'العودة لتسجيل الدخول',
                    style: GoogleFonts.cairo(
                      color: AppTheme.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
