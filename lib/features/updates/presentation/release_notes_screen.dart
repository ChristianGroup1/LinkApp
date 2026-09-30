import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../data/app_release_notes_service.dart';

class ReleaseNotesScreen extends StatefulWidget {
  const ReleaseNotesScreen({super.key});

  @override
  State<ReleaseNotesScreen> createState() => _ReleaseNotesScreenState();
}

class _ReleaseNotesScreenState extends State<ReleaseNotesScreen> {
  late Future<List<AppReleaseNote>> _notes;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _notes = AppReleaseNotesService.load();
    _packageInfo = PackageInfo.fromPlatform();
  }

  void _reload() => setState(() => _notes = AppReleaseNotesService.load());

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'تحديثات التطبيق',
          style: GoogleFonts.cairo(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<List<AppReleaseNote>>(
        future: _notes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.wifi_off_rounded,
              message:
                  'تعذر تحميل سجل التحديثات. تحقق من اتصالك وحاول مرة أخرى.',
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            );
          }
          final notes = snapshot.data ?? const <AppReleaseNote>[];
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                _CurrentVersionCard(packageInfo: _packageInfo),
                const SizedBox(height: 22),
                Text(
                  'إيه الجديد؟',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                if (notes.isEmpty)
                  const _MessageState(
                    icon: Icons.new_releases_outlined,
                    message:
                        'لا توجد تفاصيل منشورة للتحديثات حتى الآن. ستظهر هنا ملاحظات كل إصدار جديد.',
                  )
                else
                  ...notes.map((note) => _ReleaseCard(note: note)),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _CurrentVersionCard extends StatelessWidget {
  final Future<PackageInfo> packageInfo;
  const _CurrentVersionCard({required this.packageInfo});

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: packageInfo,
    builder: (context, snapshot) {
      final version = snapshot.data?.version;
      return Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              color: AppTheme.primary,
              size: 28,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نسخة التطبيق الحالية',
                    style: GoogleFonts.cairo(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    version == null ? 'جارٍ التحقق...' : 'الإصدار $version',
                    style: GoogleFonts.cairo(
                      color: AppTheme.textLight,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReleaseCard extends StatelessWidget {
  final AppReleaseNote note;
  const _ReleaseCard({required this.note});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: GoogleFonts.cairo(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _VersionBadge(version: note.version),
          ],
        ),
        if (note.publishedAt != null) ...[
          const SizedBox(height: 3),
          Text(
            '${note.publishedAt!.year}/${note.publishedAt!.month.toString().padLeft(2, '0')}/${note.publishedAt!.day.toString().padLeft(2, '0')}',
            style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 12),
          ),
        ],
        if (note.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            note.summary,
            style: GoogleFonts.cairo(color: AppTheme.textDark, height: 1.6),
          ),
        ],
        if (note.changes.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...note.changes.map(
            (change) => Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      change,
                      style: GoogleFonts.cairo(
                        color: AppTheme.textLight,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _VersionBadge extends StatelessWidget {
  final String version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'v$version',
      textDirection: TextDirection.ltr,
      style: GoogleFonts.cairo(
        color: AppTheme.primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const _MessageState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: AppTheme.textLight, height: 1.6),
          ),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
