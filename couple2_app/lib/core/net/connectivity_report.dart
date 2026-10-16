/// Last outcome reported before [connectivityReport] was registered.
bool? pendingConnectivity;

/// Installed by the connectivity provider. HTTP and cached reads call it.
void Function(bool online)? connectivityReport;

/// Records whether the last request reached the network.
///
/// [online] false is an offline failure. A timeout is not offline: the caller
/// leaves the flag alone so a slow read can still finish.
void reportConnectivity(bool online) {
  final report = connectivityReport;
  if (report == null) {
    pendingConnectivity = online;
    return;
  }
  report(online);
}
