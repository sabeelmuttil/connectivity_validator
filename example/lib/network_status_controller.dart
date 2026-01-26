import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:get/get.dart';

class NetworkStatusController extends GetxController {
  var isOffline = false.obs;
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _startListening();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _startListening() {
    // Listen to the EventChannel stream
    _subscription = ConnectivityValidator().onConnectivityChanged.listen((isOnline) {
      // Update .value to notify listeners
      isOffline.value = !isOnline;
    });
  }
}
