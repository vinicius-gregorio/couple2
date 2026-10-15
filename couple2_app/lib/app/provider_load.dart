/// Home reads should fail into an error state instead of retrying forever.
const providerTimeout = Duration(seconds: 12);

Duration? noProviderRetry(int retryCount, Object error) => null;

Future<T> loadOrTimeout<T>(Future<T> future) {
  return future.timeout(providerTimeout);
}
