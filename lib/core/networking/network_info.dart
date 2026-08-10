import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports device connectivity. Abstracted so tests and the demo mode can
/// inject a deterministic implementation.
abstract interface class NetworkInfo {
  Future<bool> get isOnline;
  Stream<bool> get onConnectivityChanged;
}

class ConnectivityNetworkInfo implements NetworkInfo {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> get isOnline async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Assume online — fail optimistically; real failures surface as
      // network exceptions with recovery actions.
      return true;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
}

/// Deterministic fake for tests / offline demo mode.
class FixedNetworkInfo implements NetworkInfo {
  FixedNetworkInfo([this.online = true]);
  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }
}
