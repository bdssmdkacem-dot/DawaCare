import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around connectivity_plus exposing a single boolean stream,
/// used by [SyncEngine] to know when it's safe to flush the offline queue.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();

  Stream<bool> get onOnlineChanged => _onlineController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(online);
      }
    });
  }

  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    return _isOnline;
  }

  void dispose() {
    _sub?.cancel();
    _onlineController.close();
  }
}
