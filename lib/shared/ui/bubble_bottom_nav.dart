import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BubbleNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color bubbleColor;

  const BubbleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.bubbleColor,
  });
}

/// Pill bubble bottom bar — active tab shows icon + label, inactive icon only.
class AppBubbleBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BubbleNavItem> items;

  const AppBubbleBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  static const _inactiveColor = Color(0xFF334155);
  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = currentIndex == index;
                final accent = item.bubbleColor;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: Center(
                        child: AnimatedContainer(
                          duration: _duration,
                          curve: _curve,
                          padding: EdgeInsets.symmetric(
                            horizontal: selected ? 14 : 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 22,
                                color: selected ? accent : _inactiveColor,
                              ),
                              AnimatedSize(
                                duration: _duration,
                                curve: _curve,
                                alignment: Alignment.centerRight,
                                child: selected
                                    ? Padding(
                                        padding: const EdgeInsetsDirectional.only(
                                          start: 6,
                                        ),
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
            }),
          ),
        ),
      ),
    );
  }
}
