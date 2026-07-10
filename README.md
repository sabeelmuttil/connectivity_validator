# connectivity_validator

[![pub package](https://img.shields.io/pub/v/connectivity_validator.svg)](https://pub.dev/packages/connectivity_validator)
[![pub points](https://img.shields.io/pub/points/connectivity_validator?color=2E8B57&label=pub%20points)](https://pub.dev/packages/connectivity_validator/score)
[![CI](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml/badge.svg)](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml)

Flutter plugin for **validated** internet connectivity: real internet access, not just “network connected.” Detects captive portals and router-without-internet. Stream-based, Android, iOS & macOS.

## Features

- Validated connectivity (real internet, not only link up)
- Captive portal and “WiFi on, no internet” detection
- Real-time stream (`onConnectivityChanged`)
- Android (API 24+), iOS (12.0+) and macOS (10.14+)

## Why connectivity_validator?

Most connectivity packages tell you whether a network _interface_ is up — not whether
you can actually reach the internet. So your app shows “online” while stuck behind a
hotel WiFi login page, or when the router has lost its upstream connection.

`connectivity_validator` answers the question you actually care about: **can the device
reach the internet right now?** It combines native OS validation
(`NET_CAPABILITY_VALIDATED` on Android, `NWPathMonitor` on iOS) with a lightweight HTTPS
probe to `generate_204` endpoints, so a captive portal or dead router reports as offline.

|                         | `connectivity_plus` | `internet_connection_checker` | **connectivity_validator** |
| ----------------------- | :-----------------: | :---------------------------: | :------------------------: |
| Network interface up    |         ✅          |              ✅               |             ✅             |
| Real internet reachable |         ❌          |              ✅               |             ✅             |
| Captive portal detected |         ❌          |              ❌               |             ✅             |
| Native OS validation    |         ❌          |              ❌               |             ✅             |
| Real-time stream        |         ✅          |              ✅               |             ✅             |

## Installation

**pubspec.yaml**

```yaml
dependencies:
  connectivity_validator: ^0.0.9
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

**macOS** — The app sandbox blocks outgoing requests by default, so the HTTPS
validation probe needs the network **client** entitlement. Add it to **both**
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Without this the plugin always reports offline on macOS.

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

**Live status (stream) + manual check (on-demand):**

```dart
final validator = ConnectivityValidator();

// Live updates
validator.onConnectivityChanged.listen((isOnline) => /* update UI */);

// On-demand check (e.g. button tap)
final isOnline = await validator.getConnectivityStatus;
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

**Run the example:**

```bash
cd example && flutter pub get && flutter run
```

## Documentation

- [State management (GetX, Provider, Riverpod, BLoC, ValueNotifier)](doc/state-management.md)
- [API reference](doc/api-reference.md)
- [How it works](doc/how-it-works.md)
- [Best practices](doc/best-practices.md)
- [Troubleshooting](doc/troubleshooting.md)

## Contributing

Contributions welcome. See the [GitHub repo](https://github.com/sabeelmuttil/connectivity_validator).

## License

See [LICENSE](LICENSE).
