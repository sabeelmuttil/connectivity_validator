import 'dart:async';

import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Best Practice: NetworkStatusController for real-time connectivity monitoring
///
/// This controller demonstrates the recommended way to use connectivity_validator:
/// - Properly manages stream subscription lifecycle
/// - Handles errors gracefully
/// - Provides reactive state for UI updates
/// - Automatically cleans up resources
class NetworkStatusController extends GetxController {
  // Observable state - automatically notifies listeners when changed
  var isOffline = false.obs;
  var lastUpdateTime = DateTime.now().obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;

  StreamSubscription? _subscription;
  final ConnectivityValidator _validator = ConnectivityValidator();

  @override
  void onInit() {
    super.onInit();
    _startListening();
  }

  @override
  void onClose() {
    // CRITICAL: Always cancel subscription to prevent memory leaks
    _subscription?.cancel();
    _subscription = null;
    super.onClose();
  }

  /// Best Practice: Start listening to connectivity changes
  ///
  /// This method:
  /// 1. Listens to the stream for real-time updates
  /// 2. Handles errors gracefully
  /// 3. Updates reactive state immediately
  /// 4. Tracks last update time for debugging
  void _startListening() {
    try {
      // Listen to the EventChannel stream for real-time connectivity updates
      _subscription = _validator.onConnectivityChanged.listen(
        (isOnline) {
          // Debug: Print to console to verify stream is working

          // Update state immediately when connectivity changes
          isOffline.value = !isOnline;
          lastUpdateTime.value = DateTime.now();
          hasError.value = false;
          errorMessage.value = '';
        },
        onError: (error) {
          // Handle stream errors gracefully
          debugPrint('❌ Connectivity stream error: $error');
          hasError.value = true;
          errorMessage.value = error.toString();
          // Assume offline on error to be safe
          isOffline.value = true;
          lastUpdateTime.value = DateTime.now();
        },
        cancelOnError: false, // Keep listening even after errors
      );
    } catch (e) {
      // Handle initialization errors
      debugPrint('❌ Failed to start listening: $e');
      hasError.value = true;
      errorMessage.value = 'Failed to start listening: $e';
      isOffline.value = true;
    }
  }

  /// Manually refresh connectivity status
  /// Useful for testing or manual checks
  @override
  Future<void> refresh() async {
    try {
      final isOnline = await _validator.onConnectivityChanged.first;
      isOffline.value = !isOnline;
      lastUpdateTime.value = DateTime.now();
      hasError.value = false;
      errorMessage.value = '';
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Refresh failed: $e';
    }
  }
}
