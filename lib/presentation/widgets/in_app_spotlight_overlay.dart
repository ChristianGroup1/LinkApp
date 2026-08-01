import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InAppTourNotifier extends InheritedWidget {
  final VoidCallback startTour;

  const InAppTourNotifier({
    super.key,
    required this.startTour,
    required super.child,
  });

  static InAppTourNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InAppTourNotifier>();
  }

  @override
  bool updateShouldNotify(InAppTourNotifier oldWidget) => false;
}

class SpotlightTargetData {
  final String title;
  final String description;
  final GlobalKey? key;
  final int? navIndex;
  final IconData icon;

  const SpotlightTargetData({
    required this.title,
    required this.description,
    this.key,
    this.navIndex,
    required this.icon,
  });
}

class InAppSpotlightOverlay extends StatefulWidget {
  final int currentStep;
  final List<SpotlightTargetData> steps;
  final Function(int) onStepChanged;
  final VoidCallback onDismiss;

  const InAppSpotlightOverlay({
    super.key,
    required this.currentStep,
    required this.steps,
    required this.onStepChanged,
    required this.onDismiss,
  });

  @override
  State<InAppSpotlightOverlay> createState() => _InAppSpotlightOverlayState();
}

class _InAppSpotlightOverlayState extends State<InAppSpotlightOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
  }

  @override
  void didUpdateWidget(covariant InAppSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateTargetRect());
    }
  }

  void _updateTargetRect() async {
    if (!mounted) return;
    final step = widget.steps[widget.currentStep.clamp(0, widget.steps.length - 1)];

    if (step.navIndex != null) {
      final size = MediaQuery.of(context).size;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      final tabWidth = size.width / 4;
      // RTL: index 0 is rightmost, 3 is leftmost
      final targetX = size.width - (tabWidth * step.navIndex!) - (tabWidth / 2);
      final targetY = size.height - (bottomPadding > 0 ? bottomPadding + 28.0 : 34.0);

      setState(() {
        _targetRect = Rect.fromCenter(
          center: Offset(targetX, targetY),
          width: tabWidth - 10,
          height: 52,
        );
      });
      return;
    }

    if (step.key != null) {
      final targetContext = step.key!.currentContext;
      if (targetContext != null) {
        // Smoothly auto-scroll the target card into the center of the screen!
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
        final currentContext = step.key?.currentContext;
        if (currentContext != null && currentContext.mounted) {
          final renderBox = currentContext.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            setState(() {
              _targetRect = Rect.fromLTWH(
                position.dx - 6,
                position.dy - 6,
                size.width + 12,
                size.height + 12,
              );
            });
            return;
          }
        }
      }
    }

    setState(() {
      _targetRect = null;
    });
  }

  void _nextStep() {
    if (widget.currentStep < widget.steps.length - 1) {
      widget.onStepChanged(widget.currentStep + 1);
    } else {
      widget.onDismiss();
    }
  }

  void _prevStep() {
    if (widget.currentStep > 0) {
      widget.onStepChanged(widget.currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[widget.currentStep.clamp(0, widget.steps.length - 1)];
    final screenSize = MediaQuery.of(context).size;
    final rect = _targetRect;

    final isBottomTarget = rect != null && rect.top > screenSize.height * 0.55;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // Background Overlay with hole cutout for target
          Positioned.fill(
            child: GestureDetector(
              onTap: _nextStep,
              child: CustomPaint(
                painter: SpotlightPainter(targetRect: rect),
              ),
            ),
          ),

          // Glowing Target Border
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      rect.width == rect.height ? rect.width / 2 : 18,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tooltip Speech Bubble Card
          Positioned(
            left: 20,
            right: 20,
            top: (rect != null && !isBottomTarget) ? rect.bottom + 16 : null,
            bottom: (rect != null && isBottomTarget)
                ? (screenSize.height - rect.top + 16).clamp(90.0, screenSize.height - 250.0)
                : (rect == null ? 120.0 : null),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(step.icon, color: const Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text(
                                step.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'خطوة ${widget.currentStep + 1} من ${widget.steps.length}',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.description,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        height: 1.6,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: widget.onDismiss,
                          child: Text(
                            'تخطي الجولة',
                            style: GoogleFonts.cairo(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            if (widget.currentStep > 0) ...[
                              OutlinedButton(
                                onPressed: _prevStep,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  'رجوع',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton.icon(
                              onPressed: _nextStep,
                              label: Text(
                                widget.currentStep == widget.steps.length - 1
                                    ? 'فهمت ذلك! 🎉'
                                    : 'التالي',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  SpotlightPainter({this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()
      ..color = const Color(0xCC0F172A)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawPath(backgroundPath, paint);
      return;
    }

    final targetPath = Path();
    final r = targetRect!;
    if ((r.width - r.height).abs() < 4) {
      targetPath.addOval(r);
    } else {
      targetPath.addRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(18)),
      );
    }

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      targetPath,
    );

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
