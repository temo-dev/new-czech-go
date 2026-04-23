import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

enum ConnectivityStatus { online, offline }

/// Emits real connectivity changes via connectivity_plus.
/// OfflineBanner in AppShell reads this provider.
@riverpod
Stream<ConnectivityStatus> connectivity(Ref ref) {
  return Connectivity().onConnectivityChanged.map((results) =>
      results.contains(ConnectivityResult.none)
          ? ConnectivityStatus.offline
          : ConnectivityStatus.online);
}
