import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  final bool hasPendingSync;

  const OfflineBanner({super.key, this.hasPendingSync = false});

  @override
  Widget build(BuildContext context) {
    final message = hasPendingSync
        ? 'وضع بدون اتصال — سيتم رفع التغييرات عند عودة الإنترنت'
        : 'وضع بدون اتصال — تعرض البيانات المحفوظة محلياً';

    return Material(
      color: AppTheme.accentOrange.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppTheme.accentOrange,
                size: 20,
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
