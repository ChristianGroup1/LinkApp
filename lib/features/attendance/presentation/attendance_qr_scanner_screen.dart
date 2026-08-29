import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/attendance/camera_permission_guidance.dart';
import '../../../core/attendance/member_qr_scan_session.dart';
import '../../../core/attendance/qr_attendance_preview.dart';
import '../../../core/attendance/qr_attendance_scan_result.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/connectivity_service.dart';

class AttendanceQrScannerScreen extends StatefulWidget {
  final List<MemberEntity> members;
  final Map<String, AttendanceStatus> initialStatuses;

  const AttendanceQrScannerScreen({
    super.key,
    required this.members,
    this.initialStatuses = const {},
  });

  @override
  State<AttendanceQrScannerScreen> createState() =>
      _AttendanceQrScannerScreenState();
}

class _AttendanceQrScannerScreenState extends State<AttendanceQrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 350,
    autoZoom: true,
  );
  late final MemberQrScanSession _scanSession = MemberQrScanSession(
    widget.members,
  );
  String? _lastRawValue;
  DateTime? _lastDetectionAt;
  bool _markUnscannedAbsent = true;
  bool _dialogOpen = false;
  String _message = 'ضع QR الخاص بالعضو داخل الإطار';
  Color _messageColor = Colors.white;
  IconData _messageIcon = Icons.qr_code_scanner_rounded;

  Set<String> get _scannedIds => _scanSession.scannedIds;
  List<String> get _scannedOrder => _scanSession.scannedOrder;

  QrAttendancePreview get _preview => QrAttendancePreview.calculate(
    members: widget.members,
    initialStatuses: widget.initialStatuses,
    scannedIds: _scannedIds,
    markUnscannedAbsent: _markUnscannedAbsent,
  );

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    String? rawValue;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue;
      if (candidate == null || candidate.trim().isEmpty) continue;
      final recentlyHandled =
          _lastRawValue == candidate &&
          _lastDetectionAt != null &&
          now.difference(_lastDetectionAt!) < const Duration(seconds: 2);
      if (!recentlyHandled) {
        rawValue = candidate;
        break;
      }
    }
    if (rawValue == null) return;
    _lastRawValue = rawValue;
    _lastDetectionAt = now;

    final attempt = _scanSession.scan(rawValue);
    switch (attempt.status) {
      case MemberQrScanStatus.invalidPayload:
        _showMessage(
          'هذا ليس QR صالحًا من LinkApp',
          color: AppTheme.accentRed,
          icon: Icons.error_outline_rounded,
        );
        HapticFeedback.heavyImpact();
      case MemberQrScanStatus.notInSheet:
        _showMessage(
          'هذا العضو غير موجود في كشف الحضور الحالي',
          color: AppTheme.accentOrange,
          icon: Icons.person_off_outlined,
        );
        HapticFeedback.heavyImpact();
      case MemberQrScanStatus.duplicate:
        _showMessage(
          '${attempt.member!.fullName} مسجل حاضر بالفعل',
          color: AppTheme.accentOrange,
          icon: Icons.info_outline_rounded,
        );
        HapticFeedback.selectionClick();
      case MemberQrScanStatus.accepted:
        setState(() {});
        _showMessage(
          'تم تسجيل ${attempt.member!.fullName} حاضر',
          color: AppTheme.secondary,
          icon: Icons.check_circle_rounded,
        );
        HapticFeedback.mediumImpact();
    }
  }

  void _showMessage(
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

  void _removeMember(String memberId) {
    final member = _scanSession.memberById(memberId);
    setState(() {
      _scanSession.remove(memberId);
      _message = member == null
          ? 'تم التراجع عن آخر مسح'
          : 'تم إلغاء حضور ${member.fullName}';
      _messageColor = AppTheme.accentOrange;
      _messageIcon = Icons.undo_rounded;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _showScannedMembers() async {
    if (_scannedOrder.isEmpty) return;
    try {
      await _controller.stop();
    } catch (_) {
      // The list remains usable if the camera has not initialized yet.
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.65,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الأعضاء الممسوحون (${_scannedIds.length})',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _scannedOrder.isEmpty
                              ? null
                              : () {
                                  final ids = List<String>.from(_scannedOrder);
                                  setState(() {
                                    _scanSession.clear();
                                    _message = 'تم مسح القائمة';
                                    _messageColor = AppTheme.accentOrange;
                                    _messageIcon = Icons.undo_rounded;
                                  });
                                  setSheetState(() {});
                                  if (ids.isNotEmpty) {
                                    HapticFeedback.selectionClick();
                                  }
                                },
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: Text('مسح الكل', style: GoogleFonts.cairo()),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _scannedOrder.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'لا يوجد أعضاء ممسوحون حالياً',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: _scannedOrder.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: AppTheme.border),
                            itemBuilder: (context, index) {
                              final memberId = _scannedOrder.reversed.elementAt(
                                index,
                              );
                              final member = _scanSession.memberById(memberId)!;
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.secondary,
                                  foregroundColor: Colors.white,
                                  child: Icon(Icons.check_rounded),
                                ),
                                title: Text(
                                  member.fullName,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: member.code == null
                                    ? null
                                    : Text(
                                        'الكود: ${member.code}',
                                        style: GoogleFonts.cairo(),
                                      ),
                                trailing: IconButton(
                                  tooltip: 'إلغاء الحضور',
                                  onPressed: () {
                                    _removeMember(memberId);
                                    setSheetState(() {});
                                  },
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
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      try {
        await _controller.start();
      } catch (_) {
        // MobileScanner will render the latest camera error if restart fails.
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    if (_dialogOpen) return false;
    _dialogOpen = true;
    try {
      try {
        await _controller.stop();
      } catch (_) {
        // The confirmation must remain usable even if camera startup failed.
      }
      if (!mounted) return false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(message, style: GoogleFonts.cairo(height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('رجوع', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true && mounted) {
        try {
          await _controller.start();
        } catch (_) {
          // MobileScanner's errorBuilder will keep showing the camera error.
        }
      }
      return confirmed == true;
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _finish() async {
    if (_scannedIds.isEmpty && !_markUnscannedAbsent) {
      Navigator.of(context).pop();
      return;
    }

    final preview = _preview;
    if (_markUnscannedAbsent && preview.willBeAbsent > 0) {
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
      if (!await _confirm(
        title: _scannedIds.isEmpty
            ? 'تسجيل الجميع غائبين؟'
            : 'مراجعة نتيجة مسح QR',
        message: summary.toString(),
        confirmLabel: 'تطبيق النتيجة',
      )) {
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      QrAttendanceScanResult(
        scannedMemberIds: _scannedIds,
        markUnscannedAbsent: _markUnscannedAbsent,
      ),
    );
  }

  Future<void> _cancel() async {
    if (_scannedIds.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final shouldDiscard = await _confirm(
      title: 'إلغاء المسح؟',
      message:
          'تم مسح ${_scannedIds.length} عضو. عند الإلغاء لن يتم حفظ أي تغيير.',
      confirmLabel: 'إلغاء المسح',
    );
    if (shouldDiscard && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              'تسجيل الحضور بـ QR',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
            leading: IconButton(
              onPressed: _cancel,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              if (_scannedOrder.isNotEmpty)
                IconButton(
                  tooltip: 'عرض الأعضاء الممسوحين',
                  onPressed: _showScannedMembers,
                  icon: Badge.count(
                    count: _scannedIds.length,
                    child: const Icon(Icons.people_alt_outlined),
                  ),
                ),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, _) => IconButton(
                  tooltip: 'الفلاش',
                  onPressed: state.isInitialized
                      ? () => _controller.toggleTorch()
                      : null,
                  icon: Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, _) => IconButton(
                  tooltip: 'تبديل الكاميرا',
                  onPressed: state.isInitialized
                      ? () => _controller.switchCamera()
                      : null,
                  icon: const Icon(Icons.cameraswitch_rounded),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) =>
                    _CameraError(error: error, onRetry: _controller.start),
              ),
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'حاضر بالـ QR: ${_preview.scannedPresent}  •  متبقي: ${_preview.totalMembers - _preview.scannedPresent}',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: ConnectivityService.instance.isOnline,
                        builder: (context, isOnline, _) {
                          if (isOnline) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(top: 7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'بدون اتصال — الحفظ سيكون على الجهاز',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _messageColor.withValues(alpha: 0.7),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Row(
                            key: ValueKey(_message),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_messageIcon, color: _messageColor),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  _message,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_scannedOrder.isNotEmpty) ...[
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _scannedOrder.length > 4
                                ? 4
                                : _scannedOrder.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final memberId = _scannedOrder.reversed.elementAt(
                                index,
                              );
                              final member = _scanSession.memberById(memberId)!;
                              return InputChip(
                                backgroundColor: AppTheme.cardBackground,
                                deleteIconColor: AppTheme.accentRed,
                                onDeleted: () => _removeMember(memberId),
                                label: Text(
                                  member.fullName,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _markUnscannedAbsent,
                          activeThumbColor: AppTheme.secondary,
                          onChanged: (value) =>
                              setState(() => _markUnscannedAbsent = value),
                          title: Text(
                            'اعتبر غير الممسوح غائبًا',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            _markUnscannedAbsent
                                ? 'سيتم تسجيل ${_preview.willBeAbsent} غائب مع الحفاظ على المعتذرين'
                                : 'لن تتغير حالة الأعضاء غير الممسوحين',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _finish,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppTheme.primary,
                        ),
                        icon: const Icon(Icons.done_all_rounded),
                        label: Text(
                          _scannedIds.isEmpty
                              ? (_markUnscannedAbsent
                                    ? 'تسجيل الجميع غائبين'
                                    : 'إنهاء بدون تغيير')
                              : _markUnscannedAbsent
                              ? 'مراجعة: ${_preview.scannedPresent} حاضر • ${_preview.willBeAbsent} غائب'
                              : 'حفظ حضور ${_preview.scannedPresent} عضو',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
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

class _CameraError extends StatefulWidget {
  final MobileScannerException error;
  final Future<void> Function() onRetry;

  const _CameraError({required this.error, required this.onRetry});

  @override
  State<_CameraError> createState() => _CameraErrorState();
}

class _CameraErrorState extends State<_CameraError>
    with WidgetsBindingObserver {
  bool _isRetrying = false;
  bool _isOpeningSettings = false;
  bool _retryWhenResumed = false;

  bool get _permissionDenied =>
      widget.error.errorCode == MobileScannerErrorCode.permissionDenied;

  String get _message => switch (widget.error.errorCode) {
    MobileScannerErrorCode.permissionDenied => cameraPermissionDeniedMessage(),
    MobileScannerErrorCode.unsupported =>
      'لا توجد كاميرا متاحة لمسح QR على هذا الجهاز.',
    _ =>
      'تعذر فتح الكاميرا. تأكد من عدم استخدامها في تطبيق آخر ثم حاول مجددًا.',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _retryWhenResumed) {
      _retryWhenResumed = false;
      unawaited(_retry());
    }
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // The scanner will rebuild this error state with the latest reason.
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _openSettings() async {
    if (_isOpeningSettings) return;
    setState(() => _isOpeningSettings = true);
    _retryWhenResumed = true;
    try {
      await AppSettings.openAppSettings();
    } catch (_) {
      _retryWhenResumed = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر فتح الإعدادات تلقائيًا. افتح إعدادات الجهاز ثم LinkApp وفعّل الكاميرا.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 54,
              ),
              const SizedBox(height: 14),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              if (_permissionDenied && supportsCameraAppSettings()) ...[
                FilledButton.icon(
                  onPressed: _isOpeningSettings ? null : _openSettings,
                  icon: _isOpeningSettings
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.settings_rounded),
                  label: Text(
                    'فتح إعدادات التطبيق',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _isRetrying ? null : _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: _isRetrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _permissionDenied ? 'طلب الإذن مجددًا' : 'المحاولة مرة أخرى',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
