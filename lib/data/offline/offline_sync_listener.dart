import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_service.dart';
import '../repositories/database_repository.dart';
import '../../logic/auth/auth_bloc.dart';

class OfflineSyncListener extends StatefulWidget {
  final Widget child;

  const OfflineSyncListener({super.key, required this.child});

  @override
  State<OfflineSyncListener> createState() => _OfflineSyncListenerState();
}

class _OfflineSyncListenerState extends State<OfflineSyncListener> {
  bool _wasOffline = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await ConnectivityService.instance.ensureInitialized();
    if (!mounted) return;

    _wasOffline = !ConnectivityService.instance.isOnline.value;
    ConnectivityService.instance.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (!mounted) return;

    final online = ConnectivityService.instance.isOnline.value;
    if (online && _wasOffline) {
      final repository = context.read<DatabaseRepository>();
      unawaited(
        repository.syncPendingOfflineData().then((_) {
          if (!mounted) return;
          context.read<AuthBloc>().add(AuthCheckRequested());
        }),
      );
    }
    _wasOffline = !online;
  }

  @override
  void dispose() {
    ConnectivityService.instance.isOnline.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
