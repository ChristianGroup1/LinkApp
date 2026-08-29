import 'dart:async';

Future<T?> retryNullableLoad<T>({
  required Future<T?> Function() load,
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 350),
}) async {
  if (attempts < 1) {
    throw ArgumentError.value(attempts, 'attempts', 'must be at least 1');
  }

  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      final value = await load();
      if (value != null) return value;
    } catch (_) {
      if (attempt == attempts) rethrow;
    }

    if (attempt < attempts && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  return null;
}
