import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/offline/member_import_history.dart';
import '../../data/member_excel_service.dart';

/// What the user chose from the import result dialog.
enum ImportResultAction { close, retryFailed, undo }

/// Accumulates everything created/changed across import runs (including
/// retries), so one undo can revert the whole session.
class MemberImportUndoData {
  final createdMemberIds = <String>[];
  final updatedPrevious = <MemberEntity>[];
  final createdClassIds = <String>[];
  final createdMeetingIds = <String>[];

  bool get isNotEmpty =>
      createdMemberIds.isNotEmpty ||
      updatedPrevious.isNotEmpty ||
      createdClassIds.isNotEmpty ||
      createdMeetingIds.isNotEmpty;

  void absorb(MemberImportSaveResult result) {
    createdMemberIds.addAll(result.createdMemberIds);
    updatedPrevious.addAll(result.updatedMemberPreviousVersions);
    for (final id in result.createdClassIds) {
      if (!createdClassIds.contains(id)) createdClassIds.add(id);
    }
    for (final id in result.createdMeetingIds) {
      if (!createdMeetingIds.contains(id)) createdMeetingIds.add(id);
    }
  }
}

/// The choices confirmed by the user in the import preview dialog.
class MemberImportConfirmation {
  final Map<String, int> meetingWeekdays;
  final Map<int, MemberImportDuplicateAction> duplicateActions;

  const MemberImportConfirmation({
    required this.meetingWeekdays,
    required this.duplicateActions,
  });
}

typedef MemberImportRunner =
    Future<MemberImportSaveResult> Function({
      required void Function(MemberImportProgress progress) onProgress,
      required bool Function() isCancelled,
    });

/// Preview dialog shown before an import starts. Returns the confirmed
/// choices, or null when the user cancels.
Future<MemberImportConfirmation?> showMemberImportPreviewDialog(
  BuildContext context,
  MemberImportParseResult result, {
  required Future<void> Function(
    BuildContext dialogContext,
    List<MemberImportIssue> issues,
  )
  onSaveIssues,
}) {
  const weekdays = <(int, String)>[
    (1, 'الاثنين'),
    (2, 'الثلاثاء'),
    (3, 'الأربعاء'),
    (4, 'الخميس'),
    (5, 'الجمعة'),
    (6, 'السبت'),
    (7, 'الأحد'),
  ];
  final meetingWeekdays = {
    for (final name in result.meetingNamesToCreate) name: 5,
  };
  final duplicateActions = {
    for (final duplicate in result.duplicates)
      duplicate.row.sourceRow: MemberImportDuplicateAction.skip,
  };

  return showDialog<MemberImportConfirmation>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'معاينة استيراد الأعضاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ImportCountCard(
                          label: 'جاهز للاستيراد',
                          count: result.validRows.length,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ImportCountCard(
                          label: 'صفوف بها أخطاء',
                          count: result.issues.length,
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                  ),
                  if (meetingWeekdays.isNotEmpty ||
                      result.classNamesToCreate.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ImportDestinationsSection(
                      meetingWeekdays: meetingWeekdays,
                      classNames: result.classNamesToCreate,
                      weekdays: weekdays,
                      onWeekdayChanged: (name, value) {
                        setDialogState(() => meetingWeekdays[name] = value);
                      },
                    ),
                  ],
                  if (result.duplicates.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ImportDuplicatesSection(
                      duplicates: result.duplicates,
                      actions: duplicateActions,
                      onActionChanged: (row, value) {
                        setDialogState(() => duplicateActions[row] = value);
                      },
                      onApplyToAll: (value) {
                        setDialogState(() {
                          for (final duplicate in result.duplicates) {
                            duplicateActions[duplicate.row.sourceRow] = value;
                          }
                        });
                      },
                    ),
                  ],
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Text(
                            'تحذيرات لا تمنع الاستيراد (${result.warnings.length})',
                            style: GoogleFonts.cairo(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                          ...result.warnings
                              .take(8)
                              .map(
                                (warning) => Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    'صف ${warning.row}: ${warning.message}',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.accentOrange,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          if (result.warnings.length > 8)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                'وهناك ${result.warnings.length - 8} تحذيرات أخرى',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.textLight,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (result.issues.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 210),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: result.issues
                            .take(10)
                            .map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  'صف ${issue.row}: ${issue.message}',
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.accentRed,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (result.issues.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'وهناك ${result.issues.length - 10} أخطاء أخرى',
                          style: GoogleFonts.cairo(
                            color: AppTheme.textLight,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (result.issues.isNotEmpty || result.warnings.isNotEmpty)
              TextButton.icon(
                onPressed: () => onSaveIssues(dialogContext, [
                  ...result.issues,
                  ...result.warnings,
                ]),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  'تنزيل الأخطاء (Excel)',
                  style: GoogleFonts.cairo(),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: result.validRows.isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      MemberImportConfirmation(
                        meetingWeekdays: Map<String, int>.from(meetingWeekdays),
                        duplicateActions:
                            Map<int, MemberImportDuplicateAction>.from(
                              duplicateActions,
                            ),
                      ),
                    ),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(
                'استيراد ${result.validRows.length} عضو',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Result dialog shown after an import run finishes or is cancelled.
Future<ImportResultAction?> showMemberImportResultDialog(
  BuildContext context,
  MemberImportSaveResult result, {
  required bool canUndo,
  required Future<void> Function(
    BuildContext dialogContext,
    List<MemberImportIssue> issues,
  )
  onSaveIssues,
}) {
  return showDialog<ImportResultAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        icon: Icon(
          result.issues.isEmpty
              ? Icons.check_circle_rounded
              : Icons.info_outline_rounded,
          color: result.issues.isEmpty
              ? AppTheme.secondary
              : AppTheme.accentOrange,
          size: 44,
        ),
        title: Text(
          result.cancelled ? 'تم إيقاف الاستيراد بأمان' : 'نتيجة الاستيراد',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ImportResultLine(
                  label: 'تم إنشاء أعضاء',
                  value: result.createdMembers,
                  color: AppTheme.secondary,
                ),
                ImportResultLine(
                  label: 'تم تحديث أعضاء',
                  value: result.updatedMembers,
                  color: AppTheme.primary,
                ),
                ImportResultLine(
                  label: 'تم تخطي مكررين',
                  value: result.skippedMembers,
                  color: AppTheme.textLight,
                ),
                ImportResultLine(
                  label: 'صفوف تحتاج مراجعة',
                  value: result.failedRows.length,
                  color: AppTheme.accentRed,
                ),
                if (result.createdMeetings > 0 || result.createdClasses > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'تم إنشاء ${result.createdMeetings} اجتماع و${result.createdClasses} فصل.',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (result.removedEmptyMeetings > 0 ||
                    result.removedEmptyClasses > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'تم تنظيف ${result.removedEmptyMeetings} اجتماع فارغ و${result.removedEmptyClasses} فصل فارغ.',
                      style: GoogleFonts.cairo(
                        color: AppTheme.textLight,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (result.savedOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'تم الحفظ محليًا وسيتم المزامنة عند عودة الاتصال.',
                      style: GoogleFonts.cairo(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (result.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...result.issues
                      .take(8)
                      .map(
                        (issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            '${issue.row == 0 ? 'تنظيف' : 'صف ${issue.row}'}: ${issue.message}',
                            style: GoogleFonts.cairo(
                              color: AppTheme.accentRed,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (result.issues.isNotEmpty)
            TextButton.icon(
              onPressed: () => onSaveIssues(dialogContext, result.issues),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                'تنزيل ملف الأخطاء (Excel)',
                style: GoogleFonts.cairo(),
              ),
            ),
          if (canUndo)
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, ImportResultAction.undo),
              icon: const Icon(Icons.undo_rounded, color: AppTheme.accentRed),
              label: Text(
                'تراجع عن الاستيراد',
                style: GoogleFonts.cairo(color: AppTheme.accentRed),
              ),
            ),
          if (result.failedRows.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () =>
                  Navigator.pop(dialogContext, ImportResultAction.retryFailed),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة محاولة الفاشل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, ImportResultAction.close),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    ),
  );
}

/// Shows past import runs stored on this device.
Future<void> showMemberImportHistoryDialog(
  BuildContext context,
  List<MemberImportHistoryEntry> entries,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          'سجل الاستيراد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 480,
          child: entries.isEmpty
              ? Text(
                  'لا توجد عمليات استيراد مسجلة لكنيستك على هذا الجهاز',
                  style: GoogleFonts.cairo(),
                )
              : SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (_, index) =>
                        ImportHistoryTile(entry: entries[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    ),
  );
}

/// Blocking dialog that runs the import and reports progress with safe cancel.
class MemberImportProgressDialog extends StatefulWidget {
  final List<MemberImportRow> rows;
  final MemberImportRunner run;

  const MemberImportProgressDialog({
    super.key,
    required this.rows,
    required this.run,
  });

  @override
  State<MemberImportProgressDialog> createState() =>
      _MemberImportProgressDialogState();
}

class _MemberImportProgressDialogState
    extends State<MemberImportProgressDialog> {
  late MemberImportProgress _progress = MemberImportProgress(
    processed: 0,
    total: widget.rows.length,
    imported: 0,
    failed: 0,
    skipped: 0,
  );
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final result = await widget.run(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        isCancelled: () => _cancelRequested,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(
        context,
        MemberImportSaveResult(
          imported: _progress.imported,
          cancelled: _cancelRequested,
          issues: [
            MemberImportIssue(
              row: 0,
              message: error.toString(),
              suggestion: 'حاول الاستيراد مرة أخرى',
            ),
          ],
          failedRows: widget.rows.skip(_progress.processed).toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _progress.total;
    final value = total == 0 ? 0.0 : _progress.processed / total;
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            _cancelRequested ? 'جارٍ الإيقاف بأمان...' : 'جارٍ استيراد الأعضاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: value.clamp(0, 1)),
                const SizedBox(height: 12),
                Text(
                  'تمت معالجة ${_progress.processed} من $total',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                if (_progress.currentRow != null)
                  Text(
                    'الصف الحالي: ${_progress.currentRow}',
                    style: GoogleFonts.cairo(color: AppTheme.textLight),
                  ),
                const SizedBox(height: 8),
                Text(
                  'نجح: ${_progress.imported}  •  فشل: ${_progress.failed}  •  تم تخطيه: ${_progress.skipped}',
                  style: GoogleFonts.cairo(fontSize: 11.5),
                ),
                if (_cancelRequested) ...[
                  const SizedBox(height: 8),
                  Text(
                    'سيتم التوقف بعد انتهاء الصف الجاري ولن تُحذف البيانات التي تم حفظها.',
                    style: GoogleFonts.cairo(
                      color: AppTheme.accentOrange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _cancelRequested
                  ? null
                  : () => setState(() => _cancelRequested = true),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text('إيقاف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blocking dialog that runs the undo operation and reports progress.
class MemberImportUndoProgressDialog extends StatefulWidget {
  final Future<MemberImportUndoResult> Function(
    void Function(int done, int total) onProgress,
  )
  run;

  const MemberImportUndoProgressDialog({super.key, required this.run});

  @override
  State<MemberImportUndoProgressDialog> createState() =>
      _MemberImportUndoProgressDialogState();
}

class _MemberImportUndoProgressDialogState
    extends State<MemberImportUndoProgressDialog> {
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final result = await widget.run((done, total) {
      if (mounted) {
        setState(() {
          _done = done;
          _total = total;
        });
      }
    });
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'جارٍ التراجع عن الاستيراد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: _total == 0 ? null : (_done / _total).clamp(0, 1),
                ),
                const SizedBox(height: 12),
                Text(
                  _total == 0 ? 'جارٍ التحضير...' : 'تم $_done من $_total',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImportHistoryTile extends StatelessWidget {
  final MemberImportHistoryEntry entry;

  const ImportHistoryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.fileName.isEmpty ? 'ملف استيراد' : entry.fileName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
            if (entry.undone)
              _ImportHistoryBadge(
                label: 'تم التراجع',
                color: AppTheme.accentRed,
              )
            else if (entry.cancelled)
              _ImportHistoryBadge(
                label: 'أُوقف بأمان',
                color: AppTheme.accentOrange,
              ),
          ],
        ),
        Text(
          formattedDate,
          style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 10.5),
        ),
        Text(
          'إنشاء ${entry.created} • تحديث ${entry.updated} • '
          'تخطي ${entry.skipped} • فشل ${entry.failed}',
          style: GoogleFonts.cairo(fontSize: 11),
        ),
      ],
    );
  }
}

class _ImportHistoryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ImportHistoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.cairo(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class ImportResultLine extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const ImportResultLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.cairo())),
        Text(
          value.toString(),
          style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class ImportDestinationsSection extends StatelessWidget {
  final Map<String, int> meetingWeekdays;
  final List<String> classNames;
  final List<(int, String)> weekdays;
  final void Function(String name, int weekday) onWeekdayChanged;

  const ImportDestinationsSection({
    super.key,
    required this.meetingWeekdays,
    required this.classNames,
    required this.weekdays,
    required this.onWeekdayChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 250),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          'سيتم الإنشاء تلقائيًا قبل إضافة الأعضاء',
          style: GoogleFonts.cairo(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        for (final entry in meetingWeekdays.entries) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: entry.value,
                underline: const SizedBox.shrink(),
                items: weekdays
                    .map(
                      (day) => DropdownMenuItem<int>(
                        value: day.$1,
                        child: Text(day.$2, style: GoogleFonts.cairo()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onWeekdayChanged(entry.key, value);
                },
              ),
            ],
          ),
        ],
        if (classNames.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'الفصول الجديدة:',
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w800,
            ),
          ),
          ...classNames.map(
            (name) => Text('• $name', style: GoogleFonts.cairo(fontSize: 11)),
          ),
        ],
      ],
    ),
  );
}

class ImportDuplicatesSection extends StatelessWidget {
  final List<MemberImportDuplicate> duplicates;
  final Map<int, MemberImportDuplicateAction> actions;
  final void Function(int row, MemberImportDuplicateAction action)
  onActionChanged;
  final void Function(MemberImportDuplicateAction action) onApplyToAll;

  const ImportDuplicatesSection({
    super.key,
    required this.duplicates,
    required this.actions,
    required this.onActionChanged,
    required this.onApplyToAll,
  });

  MemberImportDuplicateAction? get _sharedAction {
    final values = {
      for (final duplicate in duplicates) actions[duplicate.row.sourceRow],
    };
    return values.length == 1 ? values.single : null;
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 260),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.accentOrange.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.25)),
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          'أعضاء محتمل تكرارهم (${duplicates.length})',
          style: GoogleFonts.cairo(
            color: AppTheme.accentOrange,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (duplicates.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  'طبّق على الكل:',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<MemberImportDuplicateAction>(
                    value: _sharedAction,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(
                      'اختر إجراءً موحدًا',
                      style: GoogleFonts.cairo(fontSize: 11.5),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.skip,
                        child: Text('تخطي الكل', style: GoogleFonts.cairo()),
                      ),
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.update,
                        child: Text('تحديث الكل', style: GoogleFonts.cairo()),
                      ),
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.createNew,
                        child: Text(
                          'إنشاء الكل كجدد',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onApplyToAll(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ...duplicates.map(
          (duplicate) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'صف ${duplicate.row.sourceRow}: ${duplicate.row.fullName}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                Text(
                  'يطابق ${duplicate.existingMember.fullName} عن طريق ${duplicate.matchedBy.join('، ')}',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 11,
                  ),
                ),
                DropdownButtonFormField<MemberImportDuplicateAction>(
                  key: ValueKey(
                    '${duplicate.row.sourceRow}:'
                    '${actions[duplicate.row.sourceRow]}',
                  ),
                  initialValue: actions[duplicate.row.sourceRow],
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.skip,
                      child: Text(
                        'تخطي الصف (الأكثر أمانًا)',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.update,
                      child: Text(
                        'تحديث العضو الموجود',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.createNew,
                      child: Text(
                        duplicate.codeMatched
                            ? 'إنشاء جديد بدون الكود المكرر'
                            : 'إنشاء كعضو جديد',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onActionChanged(duplicate.row.sourceRow, value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ImportCountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const ImportCountCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
