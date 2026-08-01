import 'package:flutter/material.dart';

/// Keeps [Navigator.push] inside a tab so the app shell bottom bar stays visible.
class TabNavigator extends StatefulWidget {
  final Widget root;
  final int refreshToken;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TabNavigator({
    super.key,
    required this.root,
    required this.refreshToken,
    this.navigatorKey,
  });

  @override
  State<TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<TabNavigator> {
  late final GlobalKey<NavigatorState> _localKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> get _effectiveKey =>
      widget.navigatorKey ?? _localKey;

  @override
  void didUpdateWidget(covariant TabNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _effectiveKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _effectiveKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => widget.root,
        );
      },
    );
  }
}
