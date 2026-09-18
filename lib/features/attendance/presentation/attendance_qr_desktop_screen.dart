import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/attendance/member_qr_scan_session.dart';
import '../../../core/attendance/qr_attendance_preview.dart';
import '../../../core/attendance/qr_attendance_scan_result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/connectivity_service.dart';
import '../../../shared/ui/offline_editing.dart';

class AttendanceQrDesktopScreen extends StatefulWidget {
  final List<MemberEntity> members;
  final Map<String, AttendanceStatus> initialStatuses;

  const AttendanceQrDesktopScreen({
    super.key,
    required this.members,
    required this.initialStatuses,
  });

  @override
  State<AttendanceQrDesktopScreen> createState() =>
      _AttendanceQrDesktopScreenState();
}

class _AttendanceQrDesktopScreenState extends State<AttendanceQrDesktopScreen> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  late final MemberQrScanSession _scanSession = MemberQrScanSession(
    widget.members,
  );
  bool _markUnscannedAbsent = true;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  String _message = 'وصّل قارئ QR ثم امسح كارت العضو';
  Color _messageColor = AppTheme.primary;
  IconData _messageIcon = Icons.qr_code_scanner_rounded;

  QrAttendancePreview get _preview => QrAttendancePreview.calculate(
    members: widget.members,
    initialStatuses: widget.initialStatuses,
    scannedIds: _scanSession.scannedIds,
    markUnscannedAbsent: _markUnscannedAbsent,
  );

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submitRaw([String? submittedValue]) {
    final rawValue = (submittedValue ?? _inputController.text).trim();
    if (rawValue.isEmpty) {
      _setMessage(
        'امسح QR أو الصق الكود أولاً',
        color: AppTheme.accentOrange,
        icon: Icons.info_outline_rounded,
      );
      _refocusInput();
      return;
    }

    final attempt = _scanSession.scan(rawValue);
    switch (attempt.status) {
      case MemberQrScanStatus.accepted:
        _setMessage(
          'تم تسجيل ${attempt.member!.fullName} حاضر',
          color: AppTheme.secondary,
          icon: Icons.check_circle_rounded,
        );
      case MemberQrScanStatus.duplicate:
        _setMessage(
          '${attempt.member!.fullName} مسجل حاضر بالفعل',
          color: AppTheme.accentOrange,
          icon: Icons.info_outline_rounded,
        );
      case MemberQrScanStatus.invalidPayload:
        _setMessage(
          'هذا ليس QR صالحًا من LinkApp',
          color: AppTheme.accentRed,
          icon: Icons.error_outline_rounded,
        );
      case MemberQrScanStatus.notInSheet:
        _setMessage(
          'هذا العضو غير موجود في كشف الحضور الحالي',
          color: AppTheme.accentRed,
          icon: Icons.person_off_outlined,
        );
    }
    _inputController.clear();
    _refocusInput();
  }

  void _setMessage(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageColor = color;
      _messageIcon = icon;
    });
  }

  void _refocusInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    _inputController.text = value;
    _submitRaw(value);
  }

  void _removeMember(String memberId) {
    final member = _scanSession.memberById(memberId);
    _scanSession.remove(memberId);
    _setMessage(
      member == null ? 'تم إلغاء آخر مسح' : 'تم إلغاء حضور ${member.fullName}',
      color: AppTheme.accentOrange,
      icon: Icons.undo_rounded,
    );
  }

  Future<bool> _confirmResult() async {
    final preview = _preview;
    if (!_markUnscannedAbsent || preview.willBeAbsent == 0) return true;
    final offline = !ConnectivityService.instance.isOnline.value;
    final summary = StringBuffer(
      'سيتم تسجيل ${preview.scannedPresent} حاضر و${preview.willBeAbsent} غائب.',
    );
    if (preview.preservedExcused > 0) {
      summary.write(
        '\nسيتم الحفاظ على ${preview.preservedExcused} معتذر كما هو.',
      );
    }
    if (offline) {
      summary.write(
        '\nأنت بدون اتصال؛ ستُحفظ النتيجة على الجهاز وتتم مزامنتها لاحقاً.',
      );
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'مراجعة نتيجة مسح QR',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
            content: Text(summary.toString(), style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('رجوع', style: GoogleFonts.cairo()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'تطبيق النتيجة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _finish() async {
    if (_scanSession.scannedIds.isEmpty && !_markUnscannedAbsent) {
      Navigator.pop(context);
      return;
    }
    if (!await _confirmResult() || !mounted) return;
    _allowPop = true;
    Navigator.pop(
      context,
      QrAttendanceScanResult(
        scannedMemberIds: _scanSession.scannedIds,
        markUnscannedAbsent: _markUnscannedAbsent,
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_allowPop || _scanSession.scannedIds.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_discardDialogOpen) return;
    _discardDialogOpen = true;
    final discard = await confirmDiscardUnsavedChanges(context);
    _discardDialogOpen = false;
    if (discard && mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PopScope(
      canPop: _allowPop || _scanSession.scannedIds.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(
              'أخذ الحضور والغياب بالـ QR',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
            leading: IconButton(
              onPressed: _handleBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: Column(
            children: [
              const OfflineEditingNotice(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _DesktopScannerInput(
                            controller: _inputController,
                            focusNode: _inputFocus,
                            onSubmitted: _submitRaw,
                            onPaste: _pasteCode,
                            onAdd: _submitRaw,
                          ),
                          const SizedBox(height: 16),
                          _DesktopScanSummary(
                            preview: preview,
                            message: _message,
                            messageColor: _messageColor,
                            messageIcon: _messageIcon,
                            markUnscannedAbsent: _markUnscannedAbsent,
                            onMarkUnscannedAbsentChanged: (value) {
                              setState(() => _markUnscannedAbsent = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _DesktopScannedMembersList(
                              scannedOrder: _scanSession.scannedOrder,
                              memberById: _scanSession.memberById,
                              onRemove: _removeMember,
                              onClear: () {
                                _scanSession.clear();
                                _setMessage(
                                  'تم مسح القائمة',
                                  color: AppTheme.accentOrange,
                                  icon: Icons.undo_rounded,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: FilledButton.icon(
                    onPressed: _finish,
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(
                      _markUnscannedAbsent
                          ? 'مراجعة: ${preview.scannedPresent} حاضر • ${preview.willBeAbsent} غائب'
                          : 'حفظ حضور ${preview.scannedPresent} عضو',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopScannerInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPaste;
  final VoidCallback onAdd;

  const _DesktopScannerInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onPaste,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'قارئ QR على الكمبيوتر',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'وصّل قارئ QR عبر USB، ضع المؤشر في الحقل، ثم امسح الكارت. سيتم تسجيل العضو فور ضغط القارئ Enter.',
            style: GoogleFonts.cairo(color: AppTheme.textLight, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  onSubmitted: onSubmitted,
                  decoration: const InputDecoration(
                    labelText: 'بيانات QR',
                    hintText: 'امسح الكارت أو الصق الكود هنا',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_rounded),
                label: Text('لصق', style: GoogleFonts.cairo()),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text('تسجيل', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopScanSummary extends StatelessWidget {
  final QrAttendancePreview preview;
  final String message;
  final Color messageColor;
  final IconData messageIcon;
  final bool markUnscannedAbsent;
  final ValueChanged<bool> onMarkUnscannedAbsentChanged;

  const _DesktopScanSummary({
    required this.preview,
    required this.message,
    required this.messageColor,
    required this.messageIcon,
    required this.markUnscannedAbsent,
    required this.onMarkUnscannedAbsentChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated Container) so the SwitchListTile inside can
    // paint its ink on it without the framework flagging a hidden splash.
    return Material(
      color: AppTheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: messageColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(messageIcon, color: messageColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.cairo(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${preview.scannedPresent} حاضر بالـQR من ${preview.totalMembers}',
                    style: GoogleFonts.cairo(color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SwitchListTile.adaptive(
                value: markUnscannedAbsent,
                onChanged: onMarkUnscannedAbsentChanged,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'غير الممسوح غائب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  markUnscannedAbsent
                      ? '${preview.willBeAbsent} سيُسجلون غياب'
                      : 'لن تتغير حالتهم',
                  style: GoogleFonts.cairo(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopScannedMembersList extends StatelessWidget {
  final List<String> scannedOrder;
  final MemberEntity? Function(String id) memberById;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _DesktopScannedMembersList({
    required this.scannedOrder,
    required this.memberById,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated Container) so the scanned-member ListTiles can
    // paint their ink on it without the framework flagging a hidden splash.
    return Material(
      color: AppTheme.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'الأعضاء الممسوحون (${scannedOrder.length})',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: scannedOrder.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text('مسح الكل', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: scannedOrder.isEmpty
                ? Center(
                    child: Text(
                      'ابدأ بمسح كارت أول عضو',
                      style: GoogleFonts.cairo(color: AppTheme.textLight),
                    ),
                  )
                : ListView.builder(
                    itemCount: scannedOrder.length,
                    itemBuilder: (context, index) {
                      final id = scannedOrder.reversed.elementAt(index);
                      final member = memberById(id)!;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.secondary,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.check_rounded),
                        ),
                        title: Text(
                          member.fullName,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                        subtitle: member.code == null
                            ? null
                            : Text(
                                'الكود: ${member.code}',
                                style: GoogleFonts.cairo(),
                              ),
                        trailing: IconButton(
                          tooltip: 'إلغاء الحضور',
                          onPressed: () => onRemove(id),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppTheme.accentRed,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
