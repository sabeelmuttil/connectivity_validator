
import 'connectivity_validator_platform_interface.dart';

class ConnectivityValidator {
  Future<String?> getPlatformVersion() {
    return ConnectivityValidatorPlatform.instance.getPlatformVersion();
  }
}
