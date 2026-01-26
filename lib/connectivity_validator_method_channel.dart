import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'connectivity_validator_platform_interface.dart';

/// An implementation of [ConnectivityValidatorPlatform] that uses method
/// channels.
class MethodChannelConnectivityValidator extends ConnectivityValidatorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('connectivity_validator');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
