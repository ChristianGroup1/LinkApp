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
  bool _syncing = false;
  Timer? _retryTimer;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_trySync()),
    );
  }

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
    if (!_wasOffline) unawaited(_trySync());
  }

  void _onConnectivityChanged() {
    if (!mounted) return;

    final online = ConnectivityService.instance.isOnline.value;
    if (online) unawaited(_trySync());
    _wasOffline = !online;
  }

  Future<void> _trySync() async {
    if (!mounted || !_initialized || _syncing) return;
    _retryTimer?.cancel();
    await ConnectivityService.instance.ensureInitialized();
    if (!mounted || !ConnectivityService.instance.isOnline.value) return;

    _syncing = true;
    try {
      final repository = context.read<DatabaseRepository>();
      if (!await repository.hasPendingOfflineData()) return;
      await repository.syncPendingOfflineData();
      if (!mounted) return;
      final stillPending = await repository.hasPendingOfflineData();
      if (!mounted) return;
      if (stillPending) {
        _scheduleRetry();
        return;
      }
      context.read<AuthBloc>().add(AuthCheckRequested());
    } catch (_) {
      // Pending operations stay queued for the next connectivity/resume retry.
      _scheduleRetry();
    } finally {
      _syncing = false;
    }
  }

  void _scheduleRetry() {
    if (!mounted || !ConnectivityService.instance.isOnline.value) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(
      const Duration(seconds: 20),
      () => unawaited(_trySync()),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _lifecycleListener.dispose();
    ConnectivityService.instance.isOnline.removeListener(
      _onConnectivityChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
