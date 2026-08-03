import 'package:flutter/services.dart';

class ConnectivityValidator {
  // Must match the channel names in Kotlin/Swift files
  static const EventChannel _eventChannel = EventChannel(
    'connectivity_validator/status',
  );
  static const MethodChannel _methodChannel = MethodChannel(
    'connectivity_validator/method',
  );

  // An EventChannel supports one native subscription per channel. Keep one
  // broadcast stream for every validator instance so multiple widgets can
  // listen without registering duplicate native callbacks.
  static final Stream<bool> _connectivityChanges = _eventChannel
      .receiveBroadcastStream()
      .map((event) => event == true)
      .distinct();

  /// Creates a connectivity validator.
  ///
  /// [probeUrl] is accepted for API parity with the web implementation and
  /// is ignored on Android, iOS, and macOS (those platforms use native probes).
  ConnectivityValidator({String? probeUrl});

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
  ///
  /// Consecutive duplicate values are filtered out, so listeners only
  /// see actual connectivity changes.
  Stream<bool> get onConnectivityChanged {
    return _connectivityChanges;
  }
}
