import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus {
  Online,
  Offline,
  Unknown,
}

class ConnectivityService extends ChangeNotifier {
  late StreamSubscription<ConnectivityResult> _subscription;
  ConnectivityStatus _status = ConnectivityStatus.Unknown;

  ConnectivityStatus get status => _status;

  ConnectivityService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Get initial status
    final initialResult = await Connectivity().checkConnectivity();
    _updateStatus(initialResult);

    // Listen for future changes
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(ConnectivityResult result) {
    final newStatus = (result == ConnectivityResult.none)
        ? ConnectivityStatus.Offline
        : ConnectivityStatus.Online;

    if (newStatus != _status) {
      _status = newStatus;
      print('Connectivity status changed: $_status');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
