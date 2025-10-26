
import 'package:flutter/foundation.dart';

class AppConnectivityService {
  // Use a ValueNotifier to easily notify listeners of changes.
  // true = online, false = offline.
  final ValueNotifier<bool> isApiOnline = ValueNotifier(true);

  // Method to update the API connectivity status.
  void setApiStatus(bool isOnline) {
    if (isApiOnline.value != isOnline) {
      isApiOnline.value = isOnline;
    }
  }
}
