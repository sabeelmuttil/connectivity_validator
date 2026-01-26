import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'connectivity_validator_method_channel.dart';

abstract class ConnectivityValidatorPlatform extends PlatformInterface {
  /// Constructs a ConnectivityValidatorPlatform.
  ConnectivityValidatorPlatform() : super(token: _token);

  static final Object _token = Object();

  static ConnectivityValidatorPlatform _instance =
      MethodChannelConnectivityValidator();

  /// The default instance of [ConnectivityValidatorPlatform] to use.
  ///
  /// Defaults to [MethodChannelConnectivityValidator].
  static ConnectivityValidatorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ConnectivityValidatorPlatform] when
  /// they register themselves.
  static set instance(ConnectivityValidatorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
