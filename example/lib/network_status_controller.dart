import 'dart:async';

import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// NetworkStatusController with both live (stream) and on-demand (button)
/// checks.
class NetworkStatusController extends GetxController {
  // —— Live (stream) state ——
  var liveIsOffline = false.obs;
  var liveLastUpdateTime = DateTime.now().obs;
  var liveHasError = false.obs;
  var liveErrorMessage = ''.obs;

  // —— Manual (button) state ——
  var isOffline = false.obs;
  var lastUpdateTime = DateTime.now().obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;
  var isChecking = false.obs;
  var hasChecked = false.obs;

  StreamSubscription<bool>? _liveSubscription;
  final ConnectivityValidator _validator = ConnectivityValidator();

  @override
  void onInit() {
    super.onInit();
    _startLiveListening();
  }

  @override
  void onClose() {
    _liveSubscription?.cancel();
    _liveSubscription = null;
    super.onClose();
  }

  /// Live: listen to stream for real-time updates.
  void _startLiveListening() {
    try {
      _liveSubscription = _validator.onConnectivityChanged.listen(
        (isOnline) {
          liveIsOffline.value = !isOnline;
          liveLastUpdateTime.value = DateTime.now();
          liveHasError.value = false;
          liveErrorMessage.value = '';
        },
        onError: (Object error) {
          debugPrint('Live connectivity stream error: $error');
          liveHasError.value = true;
          liveErrorMessage.value = error.toString();
          liveIsOffline.value = true;
          liveLastUpdateTime.value = DateTime.now();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to start live listening: $e');
      liveHasError.value = true;
      liveErrorMessage.value = 'Failed to start: $e';
      liveIsOffline.value = true;
    }
  }

  /// Manual: check once when the user taps the button.
  Future<void> checkNow() async {
    if (isChecking.value) return;
    isChecking.value = true;
    hasError.value = false;
    errorMessage.value = '';
    try {
      final isOnline = await _validator.getConnectivityStatus;
      isOffline.value = !isOnline;
      lastUpdateTime.value = DateTime.now();
      hasChecked.value = true;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      hasError.value = true;
      errorMessage.value = e.toString();
      isOffline.value = true;
      lastUpdateTime.value = DateTime.now();
      hasChecked.value = true;
    } finally {
      isChecking.value = false;
    }
  }
}
