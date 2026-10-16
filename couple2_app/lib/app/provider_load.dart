/// Home reads should fail into an error state instead of retrying forever.
const providerTimeout = Duration(seconds: 12);

Duration? noProviderRetry(int retryCount, Object error) => null;

/// Overlapping callers share [current] so a burst cannot start a second load.
Future<T> shareInFlight<T>({
  required Future<T>? current,
  required Future<T>? Function() read,
  required void Function(Future<T>?) store,
  required Future<T> Function() start,
}) {
  if (current != null) return current;
  late final Future<T> flight;
  flight = start().whenComplete(() {
    if (identical(read(), flight)) store(null);
  });
  store(flight);
  return flight;
}

Future<T> loadOrTimeout<T>(Future<T> future) {
  return future.timeout(providerTimeout);
}
