import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/offline/connectivity_service.dart';

Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final isOffline = !ConnectivityService.instance.isOnline.value;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.edit_note_rounded,
            color: AppTheme.accentOrange,
          ),
          title: Text(
            'تجاهل التغييرات؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            isOffline
                ? 'أنت تعمل بدون اتصال، وهذه التغييرات لم تُحفظ على الجهاز بعد. إذا رجعت الآن سيتم تجاهلها.'
                : 'لديك تغييرات غير محفوظة. إذا رجعت الآن سيتم تجاهلها.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'متابعة التعديل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: Text(
                'تجاهل التغييرات',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

class OfflineEditingNotice extends StatelessWidget {
  const OfflineEditingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, _) {
        if (isOnline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppTheme.accentOrange.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'وضع بدون اتصال — عند الحفظ ستُحفظ التغييرات على الجهاز وتتم مزامنتها تلقائياً لاحقاً',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UnsavedChangesNotice extends StatelessWidget {
  final bool isDirty;
  final bool savedOffline;

  const UnsavedChangesNotice({
    super.key,
    required this.isDirty,
    this.savedOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDirty && !savedOffline) return const SizedBox.shrink();
    final icon = savedOffline
        ? Icons.cloud_done_outlined
        : Icons.edit_note_rounded;
    final color = savedOffline ? AppTheme.secondary : AppTheme.accentOrange;
    final text = savedOffline
        ? 'محفوظ على الجهاز — في انتظار المزامنة'
        : 'تغييرات غير محفوظة';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
