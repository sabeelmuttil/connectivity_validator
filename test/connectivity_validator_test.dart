import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ConnectivityValidator creates instance correctly', () {
    ConnectivityValidator connectivityValidator = ConnectivityValidator();
    expect(connectivityValidator, isA<ConnectivityValidator>());
  });

  test('onConnectivityChanged returns a stream', () {
    ConnectivityValidator connectivityValidator = ConnectivityValidator();
    final stream = connectivityValidator.onConnectivityChanged;

    expect(stream, isA<Stream<bool>>());
  });

  test('onConnectivityChanged can be accessed multiple times', () {
    ConnectivityValidator connectivityValidator = ConnectivityValidator();
    final stream1 = connectivityValidator.onConnectivityChanged;
    final stream2 = connectivityValidator.onConnectivityChanged;

    expect(stream1, isA<Stream<bool>>());
    expect(stream2, isA<Stream<bool>>());
  });

  test('checkConnectivity returns a Future<bool>', () {
    ConnectivityValidator connectivityValidator = ConnectivityValidator();
    final result = connectivityValidator.getConnectivityStatus;
    expect(result, isA<Future<bool>>());
  });
}
