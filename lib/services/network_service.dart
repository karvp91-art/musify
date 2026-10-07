import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus {
  online,
  offline,
  checking,
}

/// Production-grade network connectivity and internet reachability monitoring service.
/// Features dual-layer detection (hardware interface changes + actual socket DNS reachability checks)
/// with intelligent debouncing and active retry capabilities.
class NetworkStatusService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;
  List<ConnectivityResult> _currentConnectivity = const [ConnectivityResult.other];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounceTimer;
  bool _isChecking = false;

  NetworkStatusService() {
    _initialize();
  }

  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus == NetworkStatus.offline;
  List<ConnectivityResult> get currentConnectivity => _currentConnectivity;
  bool get isWifi => _currentConnectivity.contains(ConnectivityResult.wifi);
  bool get isCellular => _currentConnectivity.contains(ConnectivityResult.mobile);

  Stream<NetworkStatus> get onStatusChanged => _statusController.stream;

  void _initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _currentConnectivity = results;
      _debounceCheck();
    });

    // Initial check
    checkInternetReachability();
  }

  void _debounceCheck() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      checkInternetReachability();
    });
  }

  /// Actively tests real internet reachability via lightweight socket address resolution.
  Future<bool> checkInternetReachability({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    try {
      // 1. Quick check: if connectivity results explicitly say .none, we are offline
      final connectivityResults = await _connectivity.checkConnectivity();
      _currentConnectivity = connectivityResults;
      if (connectivityResults.every((r) => r == ConnectivityResult.none)) {
        _updateStatus(NetworkStatus.offline);
        _isChecking = false;
        return false;
      }

      // 2. Real socket ping to highly available global DNS / web endpoints
      bool reachable = false;
      try {
        final lookupResults = await InternetAddress.lookup('google.com')
            .timeout(timeout);
        if (lookupResults.isNotEmpty && lookupResults[0].rawAddress.isNotEmpty) {
          reachable = true;
        }
      } catch (_) {
        // Fallback check against secondary reliable endpoint
        try {
          final backupLookup = await InternetAddress.lookup('cloudflare.com')
              .timeout(timeout);
          if (backupLookup.isNotEmpty && backupLookup[0].rawAddress.isNotEmpty) {
            reachable = true;
          }
        } catch (_) {
          reachable = false;
        }
      }

      final newStatus = reachable ? NetworkStatus.online : NetworkStatus.offline;
      _updateStatus(newStatus);
      _isChecking = false;
      return reachable;
    } catch (_) {
      _updateStatus(NetworkStatus.offline);
      _isChecking = false;
      return false;
    }
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
