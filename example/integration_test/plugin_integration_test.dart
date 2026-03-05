// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connectivity stream emits boolean', (WidgetTester tester) async {
    final ConnectivityValidator plugin = ConnectivityValidator();
    // The plugin emits true = validated internet, false = no internet/captive portal.
    // CI emulators may have either state; we only assert the stream works and emits a bool.
    final bool isConnected = await plugin.onConnectivityChanged.first;
    expect(isConnected, isA<bool>());
  });
}
