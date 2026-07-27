import 'package:flutter/material.dart';

/// Keeps [Navigator.push] inside a tab so the app shell bottom bar stays visible.
class TabNavigator extends StatefulWidget {
  final Widget root;
  final int refreshToken;

  const TabNavigator({
    super.key,
    required this.root,
    required this.refreshToken,
  });

  @override
  State<TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<TabNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void didUpdateWidget(covariant TabNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => widget.root,
        );
      },
    );
  }
}
