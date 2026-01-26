import 'package:flutter/services.dart';

class ConnectivityValidator {
  // Must match the channel name in Kotlin/Swift files
  static const EventChannel _channel = EventChannel(
    'connectivity_validator/status',
  );

  /// Returns a stream of booleans.
  /// true = Internet Validated (Active & Working)
  /// false = No Internet or Captive Portal
  Stream<bool> get onConnectivityChanged {
    return _channel.receiveBroadcastStream().map((event) => event == true);
  }
}
