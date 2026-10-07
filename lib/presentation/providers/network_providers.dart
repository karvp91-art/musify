import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/network_service.dart';

/// Provider for the singleton NetworkStatusService instance
final networkServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for live NetworkStatus updates (online, offline, checking)
final networkStatusStreamProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.onStatusChanged;
});

/// Reactive provider for current NetworkStatus
final networkStatusProvider = Provider<NetworkStatus>((ref) {
  final asyncStatus = ref.watch(networkStatusStreamProvider);
  return asyncStatus.value ?? ref.watch(networkServiceProvider).currentStatus;
});

/// Convenience boolean provider to determine if device is currently offline
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status == NetworkStatus.offline;
});

/// Convenience boolean provider to determine if device is currently online
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status == NetworkStatus.online;
});

/// Connectivity type provider (WiFi, Mobile, None, etc.)
final connectivityTypeProvider = Provider<List<ConnectivityResult>>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.currentConnectivity;
});
