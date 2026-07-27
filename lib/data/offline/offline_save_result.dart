class OfflineSaveResult<T> {
  final T data;
  final bool syncedToServer;

  const OfflineSaveResult({
    required this.data,
    required this.syncedToServer,
  });
}
