# connectivity_validator

[![pub package](https://img.shields.io/pub/v/connectivity_validator.svg)](https://pub.dev/packages/connectivity_validator)
[![pub points](https://img.shields.io/pub/points/connectivity_validator?color=2E8B57&label=pub%20points)](https://pub.dev/packages/connectivity_validator/score)
[![CI](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml/badge.svg)](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml)

Flutter plugin for **validated** internet connectivity: real internet access, not just “network connected.” Detects captive portals and router-without-internet. Stream-based, Android & iOS.

## Features

- Validated connectivity (real internet, not only link up)
- Captive portal and “WiFi on, no internet” detection
- Real-time stream (`onConnectivityChanged`)
- Android (API 24+) and iOS (12.0+)

## Installation

**pubspec.yaml**

```yaml
dependencies:
  connectivity_validator: ^0.0.5
```

```bash
flutter pub get
```

## Platform setup

**Android** — Add to `AndroidManifest.xml` if needed:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

**iOS**

- **Swift Package Manager (default)** — No extra setup. Flutter uses SPM for the plugin.
- **CocoaPods** — If your project uses CocoaPods for this plugin, run in the project root:
  ```bash
  cd ios && pod install && cd ..
  ```

## Usage

```dart
import 'package:connectivity_validator/connectivity_validator.dart';

final validator = ConnectivityValidator();

validator.onConnectivityChanged.listen((isOnline) {
  if (isOnline) {
    // Internet validated
  } else {
    // No internet or captive portal
  }
});
```

**Get initial state and listen to changes:**

```dart
final validator = ConnectivityValidator();

// Get initial state
final initialStatus = await validator.onConnectivityChanged.first;
print('Initial status: ${initialStatus ? "Online" : "Offline"}');

// Listen to changes
validator.onConnectivityChanged.listen((isOnline) {
  print('Connectivity changed: ${isOnline ? "Online" : "Offline"}');
});
```

**In UI (e.g. StreamBuilder):**

```dart
StreamBuilder<bool>(
  stream: ConnectivityValidator().onConnectivityChanged,
  initialData: false,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    return Text(isOnline ? 'Online' : 'Offline');
  },
)
```

## Documentation

- [State management (GetX, Provider, Riverpod, BLoC, ValueNotifier)](doc/state-management.md)
- [API reference](doc/api-reference.md)
- [How it works](doc/how-it-works.md)
- [Best practices](doc/best-practices.md)
- [Troubleshooting](doc/troubleshooting.md)

## Example app

```bash
cd example && flutter pub get && flutter run
```

## Contributing

Contributions welcome. See the [GitHub repo](https://github.com/sabeelmuttil/connectivity_validator).

## License

See [LICENSE](LICENSE).
