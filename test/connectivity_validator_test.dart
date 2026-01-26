import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:connectivity_validator/connectivity_validator_method_channel.dart';
import 'package:connectivity_validator/connectivity_validator_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockConnectivityValidatorPlatform
    with MockPlatformInterfaceMixin
    implements ConnectivityValidatorPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ConnectivityValidatorPlatform initialPlatform =
      ConnectivityValidatorPlatform.instance;

  test('$MethodChannelConnectivityValidator is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelConnectivityValidator>());
  });

  test('getPlatformVersion', () async {
    ConnectivityValidator connectivityValidatorPlugin = ConnectivityValidator();
    MockConnectivityValidatorPlatform fakePlatform =
        MockConnectivityValidatorPlatform();
    ConnectivityValidatorPlatform.instance = fakePlatform;

    expect(await connectivityValidatorPlugin.onConnectivityChanged.first, true);
  });
}
