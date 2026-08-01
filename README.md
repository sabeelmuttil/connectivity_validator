# connectivity_validator

[![pub package](https://img.shields.io/pub/v/connectivity_validator.svg)](https://pub.dev/packages/connectivity_validator)
[![pub points](https://img.shields.io/pub/points/connectivity_validator?color=2E8B57&label=pub%20points)](https://pub.dev/packages/connectivity_validator/score)
[![CI](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml/badge.svg)](https://github.com/sabeelmuttil/connectivity_validator/actions/workflows/connectivity_validator.yaml)

Flutter plugin for **validated** internet connectivity: real internet access, not just “network connected.” Detects captive portals and router-without-internet. Stream-based, Android, iOS, macOS & Web.

## Features

- Validated connectivity (real internet, not only link up)
- Captive portal and “WiFi on, no internet” detection
- Real-time stream (`onConnectivityChanged`)
- Android (API 24+), iOS (12.0+), macOS (10.14+) and Web

## Why connectivity_validator?

Most connectivity packages tell you whether a network _interface_ is up — not whether
you can actually reach the internet. So your app shows “online” while stuck behind a
hotel WiFi login page, or when the router has lost its upstream connection.

`connectivity_validator` answers the question you actually care about: **can the device
reach the internet right now?** On mobile/desktop it combines native OS validation
(`NET_CAPABILITY_VALIDATED` on Android, `NWPathMonitor` on iOS/macOS) with a lightweight
HTTPS probe to `generate_204` endpoints. On Web it uses `navigator.onLine` plus a
browser fetch probe (see [Web setup](#web-setup)).

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

### Web setup

On Web there is no native OS “validated” signal. The plugin uses:

1. **`navigator.onLine`** as a baseline (browser says the network interface is up)
2. A **fetch probe** to confirm real reachability

**CORS caveat:** Cross-origin `fetch` in `no-cors` mode returns an opaque response — JavaScript cannot read `response.status`, so the default probe cannot verify HTTP `204` the way Android/iOS/macOS do. The default is a `GET` to `https://www.gstatic.com/generate_204` in `no-cors` mode: a fulfilled promise counts as online; network error or timeout counts as offline.

Google/Cloudflare `generate_204` URLs usually do **not** expose CORS headers for browsers. For precise status-code validation (require HTTP `204`), pass a same-origin or CORS-enabled endpoint you control:

```dart
final validator = ConnectivityValidator(
  probeUrl: 'https://your-domain.com/connectivity-check', // must return 204 + CORS
);
```

When `probeUrl` is set, Web uses CORS mode and treats `status == 204` as online. Non-CORS custom URLs will fail closed (report offline).

`probeUrl` is accepted on all platforms for API parity but is **ignored** on Android, iOS, and macOS (those keep their native probe lists).

Periodic probes run about every 12s while you listen to the stream, and pause when the tab is hidden (`document.visibilityState`).

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

**Web (Chrome) — toggle network to test online/offline:**

```bash
cd example && flutter pub get && flutter run -d chrome
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
