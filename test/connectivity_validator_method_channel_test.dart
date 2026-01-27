import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConnectivityValidator creates instance correctly', () {
    ConnectivityValidator validator = ConnectivityValidator();
    expect(validator, isA<ConnectivityValidator>());
  });

  test('onConnectivityChanged returns a stream', () {
    ConnectivityValidator validator = ConnectivityValidator();
    final stream = validator.onConnectivityChanged;

    expect(stream, isA<Stream<bool>>());
  });

  test('onConnectivityChanged stream is properly typed', () {
    ConnectivityValidator validator = ConnectivityValidator();
    final stream = validator.onConnectivityChanged;

    // Verify the stream type
    expect(stream, isA<Stream<bool>>());
    // Note: Actual event testing requires platform integration tests
    // as EventChannel mocking is complex and requires native platform setup
  });
}
