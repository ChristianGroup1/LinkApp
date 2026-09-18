import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  /// Changes still waiting for the server because the device has no connection.
  final bool hasPendingSync;

  /// Changes the server refused for good. They stay on the device, so the
  /// servant has to be told rather than left believing they were saved.
  final int rejectedCount;

  /// Acknowledges the refused changes and hides the warning. Without it the
  /// red banner would stay forever, even after the servant re-entered the data.
  final VoidCallback? onDismissRejected;

  const OfflineBanner({
    super.key,
    this.hasPendingSync = false,
    this.rejectedCount = 0,
    this.onDismissRejected,
  });

  @override
  Widget build(BuildContext context) {
    if (rejectedCount > 0) {
      return _BannerShell(
        icon: Icons.report_gmailerrorred_rounded,
        color: AppTheme.accentRed,
        message:
            'لم تُرفع $rejectedCount تغييرات إلى الخادم. راجع صلاحيتك على '
            'الاجتماع أو الفصل ثم أعد الحفظ.',
        onDismiss: onDismissRejected,
      );
    }

    return _BannerShell(
      icon: Icons.cloud_off_outlined,
      color: AppTheme.accentOrange,
      message: hasPendingSync
          ? 'وضع بدون اتصال — سيتم رفع التغييرات عند عودة الإنترنت'
          : 'وضع بدون اتصال — تعرض البيانات المحفوظة محلياً',
    );
  }
}

class _BannerShell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onDismiss;

  const _BannerShell({
    required this.icon,
    required this.color,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'إخفاء التنبيه',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: color, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
