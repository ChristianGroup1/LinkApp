import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/database_repository.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../main.dart';
import '../../presentation/screens/invitation_link_screen.dart';
import 'invitation_link.dart';

class InvitationDeepLinkListener extends StatefulWidget {
  final Widget child;

  const InvitationDeepLinkListener({super.key, required this.child});

  @override
  State<InvitationDeepLinkListener> createState() =>
      _InvitationDeepLinkListenerState();
}

class _InvitationDeepLinkListenerState
    extends State<InvitationDeepLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastOpenedToken;
  String? _pendingToken;

  @override
  void initState() {
    super.initState();
    _initializeLinks();
  }

  Future<void> _initializeLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _queueInvitation(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _queueInvitation,
      onError: (_) {},
    );
  }

  void _queueInvitation(Uri uri) {
    final token = extractInvitationToken(uri);
    if (token == null || token.isEmpty) return;
    if (_lastOpenedToken == token) return;

    _pendingToken = token;
    unawaited(_openPendingInvitation());
  }

  Future<void> _openPendingInvitation() async {
    final token = _pendingToken;
    if (token == null) return;

    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 80 + attempt * 40));

      final navigator = MyApp.navigatorKey.currentState;
      final hostContext = MyApp.navigatorKey.currentContext;
      if (navigator == null ||
          hostContext == null ||
          !navigator.mounted ||
          !hostContext.mounted) {
        continue;
      }

      final repository = hostContext.read<DatabaseRepository>();
      final authBloc = hostContext.read<AuthBloc>();

      _pendingToken = null;
      _lastOpenedToken = token;

      await navigator.push(
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              RepositoryProvider<DatabaseRepository>.value(value: repository),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: InvitationLinkScreen(inviteToken: token),
          ),
        ),
      );

      _lastOpenedToken = null;
      return;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
