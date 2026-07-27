import 'dart:async';

import 'connectivity_service.dart';

/// Short-circuits Supabase reads when offline or when the network is slow.
class OfflineNetworkPolicy {
  static const requestTimeout = Duration(seconds: 4);

  static Future<void> ensureReady() =>
      ConnectivityService.instance.ensureInitialized();

  static bool get isConnectivityOffline =>
      !ConnectivityService.instance.isOnline.value;

  static Future<T> run<T>({
    required Future<T> Function() online,
    required Future<T> Function() offline,
  }) async {
    await ensureReady();
    if (isConnectivityOffline) {
      return offline();
    }
    try {
      return await online().timeout(requestTimeout);
    } on TimeoutException {
      return offline();
    } catch (_) {
      return offline();
    }
  }
}
