import 'package:flutter/material.dart';

/// Arabic-first layout helpers.
abstract final class AppDirection {
  static const TextDirection textDirection = TextDirection.rtl;

  static Widget wrap(Widget child) {
    return Directionality(
      textDirection: textDirection,
      child: child,
    );
  }
}
