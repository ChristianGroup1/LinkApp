import 'dart:async';
import 'dart:io';

import 'connectivity_service.dart';

/// Short-circuits Supabase reads when offline or when the network is slow.
class OfflineNetworkPolicy {
  static const requestTimeout = Duration(seconds: 4);

  static Future<void> ensureReady() =>
      ConnectivityService.instance.ensureInitialized();

  static bool get isConnectivityOffline =>
      !ConnectivityService.instance.isOnline.value;

  static bool looksLikeNetworkFailure(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('clientexception') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('host lookup') ||
        message.contains('failed host') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('offline') ||
        message.contains('internet');
  }

  static Future<T> run<T>({
    required Future<T> Function() online,
    required Future<T> Function() offline,
    Duration timeout = requestTimeout,
    bool fallbackOnTimeout = true,
  }) async {
    await ensureReady();
    if (isConnectivityOffline) {
      return offline();
    }
    try {
      return await online().timeout(timeout);
    } on TimeoutException {
      if (fallbackOnTimeout) return offline();
      rethrow;
    } catch (error) {
      // Prefer a stale local roster over a blank screen on flaky networks.
      if (fallbackOnTimeout && looksLikeNetworkFailure(error)) {
        return offline();
      }
      rethrow;
    }
  }
}
