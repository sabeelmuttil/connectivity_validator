import 'package:flutter/services.dart';

class ConnectivityValidator {
  // Must match the channel names in Kotlin/Swift files
  static const EventChannel _eventChannel = EventChannel(
    'connectivity_validator/status',
  );
  static const MethodChannel _methodChannel = MethodChannel(
    'connectivity_validator/method',
  );

  /// Returns the current network state once.
  /// true = Internet validated (active & working)
  /// false = No internet or captive portal
  ///
  /// Use this for on-demand checks (e.g. when the user taps a button).
  Future<bool> get getConnectivityStatus async {
    final result = await _methodChannel.invokeMethod<bool>('getStatus');
    return result == true;
  }

  /// Returns a stream of booleans (for continuous monitoring).
  /// true = Internet Validated (Active & Working)
  /// false = No Internet or Captive Portal
  Stream<bool> get onConnectivityChanged {
    return _eventChannel.receiveBroadcastStream().map((event) => event == true);
  }
}
