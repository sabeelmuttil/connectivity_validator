# connectivity_validator

A Flutter plugin that provides **validated internet connectivity status** with real-time updates. Unlike basic connectivity checks, this plugin validates that the device has actual internet access (not just a network connection), detecting captive portals and ensuring the connection is truly functional.

## Features

- ✅ **Validated Connectivity**: Checks for real internet access, not just network connection
- ✅ **Captive Portal Detection**: Detects when connected to WiFi but behind a captive portal
- ✅ **Router Internet Loss Detection**: Detects when WiFi router loses internet while staying connected
- ✅ **HTTPS Connectivity Testing**: Performs actual HTTPS requests to verify real internet access
- ✅ **Smart Failure Handling**: Prevents ping-pong effects with intelligent failure counter
- ✅ **Real-time Updates**: Stream-based API for continuous connectivity monitoring
- ✅ **Cross-platform**: Works on both Android and iOS with identical behavior
- ✅ **Lightweight**: Zero dependencies, framework-agnostic
- ✅ **Optimized**: Only emits updates when connectivity state actually changes
- ✅ **Battery Efficient**: Smart caching and periodic checks balance accuracy with performance

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  connectivity_validator: ^0.0.4
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android

The plugin requires the following permissions in your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required permission to check network connectivity state -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- Optional: For WiFi-specific connectivity checks -->
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    ...
</manifest>
```

**Note**: These permissions are typically already included in Flutter apps, but if you encounter permission errors, ensure they're declared in your app's `AndroidManifest.xml` file.

The plugin uses `ConnectivityManager` with `NET_CAPABILITY_VALIDATED` and HTTPS connectivity testing to ensure real internet connectivity.

**Note**: The plugin also requires `INTERNET` permission for HTTPS connectivity tests. This is typically already included in Flutter apps.

### iOS

No additional setup required. The plugin uses `NWPathMonitor` with `.satisfied` status and HTTPS connectivity testing to detect validated connectivity.

**Note**: The plugin supports both CocoaPods and Swift Package Manager (SPM). Flutter will automatically use the appropriate dependency manager based on your project configuration.

## Basic Usage

The plugin provides a simple stream-based API:

```dart
import 'package:connectivity_validator/connectivity_validator.dart';

final validator = ConnectivityValidator();

// Listen to connectivity changes
validator.onConnectivityChanged.listen((isOnline) {
  if (isOnline) {
    print('Internet is available and validated');
  } else {
    print('No internet or captive portal detected');
  }
});
```

## State Management Options

The plugin is framework-agnostic and works with any state management solution. Here are examples for popular approaches:

### Option 1: Using StreamBuilder (No Dependencies)

The simplest approach using Flutter's built-in `StreamBuilder`:

```dart
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/material.dart';

class ConnectivityWidget extends StatelessWidget {
  final ConnectivityValidator validator = ConnectivityValidator();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: validator.onConnectivityChanged,
      initialData: false,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        return Text(
          isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}
```

### Option 2: Using GetX

Create a controller that extends `GetxController`:

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:get/get.dart';

class NetworkStatusController extends GetxController {
  var isOffline = false.obs;
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _startListening();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _startListening() {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) {
      isOffline.value = !isOnline;
    });
  }
}
```

Usage in your app:

```dart
import 'package:get/get.dart';

void main() {
  Get.put(NetworkStatusController(), permanent: true);
  runApp(MyApp());
}

// In your widget
Obx(() => Text(
  Get.find<NetworkStatusController>().isOffline.value
    ? 'Offline'
    : 'Online'
))
```

### Option 3: Using Provider

Create a provider class:

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = false;
  StreamSubscription? _subscription;
  final ConnectivityValidator _validator = ConnectivityValidator();

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _startListening();
  }

  void _startListening() {
    _subscription = _validator.onConnectivityChanged.listen((isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

Usage:

```dart
// Wrap your app
ChangeNotifierProvider(
  create: (_) => ConnectivityProvider(),
  child: MyApp(),
)

// In your widget
Consumer<ConnectivityProvider>(
  builder: (context, provider, child) {
    return Text(provider.isOnline ? 'Online' : 'Offline');
  },
)
```

### Option 4: Using Riverpod

Create a provider:

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityValidator().onConnectivityChanged;
});

// Or with state management
class ConnectivityNotifier extends StateNotifier<bool> {
  StreamSubscription? _subscription;

  ConnectivityNotifier() : super(false) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) {
      state = isOnline;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
```

Usage:

```dart
// With StreamProvider
final connectivity = ref.watch(connectivityProvider);
connectivity.when(
  data: (isOnline) => Text(isOnline ? 'Online' : 'Offline'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
)

// With StateNotifier
final isOnline = ref.watch(connectivityNotifierProvider);
Text(isOnline ? 'Online' : 'Offline')
```

### Option 5: Using BLoC

Create a BLoC:

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  StreamSubscription? _subscription;

  ConnectivityBloc() : super(ConnectivityInitial()) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) {
      add(ConnectivityChanged(isOnline));
    });
  }

  @override
  Stream<ConnectivityState> mapEventToState(ConnectivityEvent event) async* {
    if (event is ConnectivityChanged) {
      yield ConnectivityLoaded(event.isOnline);
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

// Events
abstract class ConnectivityEvent {}
class ConnectivityChanged extends ConnectivityEvent {
  final bool isOnline;
  ConnectivityChanged(this.isOnline);
}

// States
abstract class ConnectivityState {}
class ConnectivityInitial extends ConnectivityState {}
class ConnectivityLoaded extends ConnectivityState {
  final bool isOnline;
  ConnectivityLoaded(this.isOnline);
}
```

Usage:

```dart
BlocProvider(
  create: (_) => ConnectivityBloc(),
  child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
    builder: (context, state) {
      if (state is ConnectivityLoaded) {
        return Text(state.isOnline ? 'Online' : 'Offline');
      }
      return CircularProgressIndicator();
    },
  ),
)
```

### Option 6: Using ValueNotifier

Simple reactive approach without external dependencies:

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/material.dart';

class ConnectivityNotifier extends ValueNotifier<bool> {
  StreamSubscription? _subscription;

  ConnectivityNotifier() : super(false) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) {
      value = isOnline;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

Usage:

```dart
final notifier = ConnectivityNotifier();

ValueListenableBuilder<bool>(
  valueListenable: notifier,
  builder: (context, isOnline, child) {
    return Text(isOnline ? 'Online' : 'Offline');
  },
)
```

## API Reference

### `ConnectivityValidator`

The main class for accessing connectivity status.

#### Properties

##### `onConnectivityChanged` → `Stream<bool>`

Returns a stream of boolean values indicating connectivity status:

- `true`: Internet is available and validated (active connection with real internet access)
- `false`: No internet connection or captive portal detected

The stream emits:

- Immediately when you start listening (initial state)
- Whenever the connectivity status changes
- Only when the state actually changes (optimized to avoid duplicate emissions)

#### Example

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

## How It Works

### Android

The plugin uses Android's `ConnectivityManager` with `NetworkCallback` and HTTPS connectivity testing:

#### Two-Phase Validation System

1. **Immediate Capability Checks** (Fast Response)
   - Monitors multiple callbacks: `onAvailable`, `onLost`, `onCapabilitiesChanged`, and `onLinkPropertiesChanged`
   - Checks `NET_CAPABILITY_INTERNET` and `NET_CAPABILITY_VALIDATED` for immediate updates
   - Sends updates instantly when capabilities change

2. **HTTPS Connectivity Verification** (Accurate Detection)
   - When capabilities indicate online, performs HTTPS requests to Google's connectivity check endpoints
   - Tests multiple endpoints: `www.google.com/generate_204`, `connectivitycheck.gstatic.com/generate_204`, `clients3.google.com/generate_204`
   - Uses 500ms timeout per request for fast verification
   - Runs in background thread to avoid blocking UI

#### Smart Failure Handling

- **Failure Counter**: Tracks consecutive HTTPS test failures
- **Override Logic**: Only switches to OFFLINE after 2 consecutive HTTPS failures (prevents ping-pong effects)
- **Respects HTTPS Results**: When HTTPS confirms OFFLINE, periodic capability checks won't override it
- **Automatic Reset**: Counter resets when HTTPS test succeeds or capabilities say offline

#### Periodic Checks

- Runs every 2 seconds to detect router internet loss
- Verifies connectivity with HTTPS tests every 5 seconds
- Caches HTTPS test results for 5 seconds to balance accuracy with performance

This dual approach ensures:

- **Fast response** when network capabilities change
- **Accurate detection** when router loses internet (even if WiFi stays connected)
- **No ping-pong effects** from intermittent HTTPS test failures
- **Battery efficient** with smart caching and periodic checks

### iOS

The plugin uses iOS's `NWPathMonitor` with HTTPS connectivity testing:

#### Two-Phase Validation System

1. **Immediate Path Status Checks** (Fast Response)
   - Monitors all network interfaces (WiFi, cellular, etc.)
   - Checks `.satisfied` status for immediate updates
   - Sends updates instantly when path status changes

2. **HTTPS Connectivity Verification** (Accurate Detection)
   - When path status indicates online, performs HTTPS requests to Google's connectivity check endpoints
   - Tests multiple endpoints sequentially until one succeeds
   - Uses 500ms timeout per request for fast verification
   - Runs asynchronously to avoid blocking

#### Smart Failure Handling

- **Failure Counter**: Tracks consecutive HTTPS test failures
- **Override Logic**: Only switches to OFFLINE after 2 consecutive HTTPS failures (prevents ping-pong effects)
- **Respects HTTPS Results**: When HTTPS confirms OFFLINE, periodic path checks won't override it
- **Automatic Reset**: Counter resets when HTTPS test succeeds or path status says offline

#### Periodic Checks

- Runs every 2 seconds to detect router internet loss
- Verifies connectivity with HTTPS tests every 5 seconds
- Caches HTTPS test results for 5 seconds to balance accuracy with performance

This dual approach ensures:

- **Fast response** when network path status changes
- **Accurate detection** when router loses internet (even if WiFi stays connected)
- **No ping-pong effects** from intermittent HTTPS test failures
- **Battery efficient** with smart caching and periodic checks

### Why HTTPS Testing?

Both Android's `NET_CAPABILITY_VALIDATED` and iOS's `NWPathMonitor.satisfied` can be **stale** when:

- Router loses internet but WiFi connection remains active
- Network is behind a captive portal that hasn't been detected yet
- DNS issues prevent actual internet access

HTTPS connectivity testing provides a **ground truth** check by making actual requests to reliable endpoints, ensuring the device truly has internet access.

## Example App

The example app demonstrates usage with GetX. To run it:

```bash
cd example
flutter pub get
flutter run
```

The example shows:

- Real-time connectivity status updates
- Visual indicators (icons and colors)
- Proper state management with GetX

## Best Practices

1. **Always dispose subscriptions**: When using the stream, make sure to cancel the subscription in your `dispose()` method to prevent memory leaks.

2. **Handle initial state**: The stream emits immediately when you start listening, so handle the initial state appropriately.

3. **Use appropriate state management**: Choose a state management solution that fits your app's architecture. The plugin works with all of them.

4. **Show user feedback**: Display connectivity status clearly to users, especially when offline, so they understand why certain features aren't working.

5. **Graceful degradation**: Design your app to handle offline states gracefully without crashing.

## Troubleshooting

### Stream not emitting updates

- Ensure you're properly listening to the stream
- Check that you're not canceling the subscription prematurely
- On Android, verify that `ACCESS_NETWORK_STATE` permission is declared in your `AndroidManifest.xml`

### Permission errors on Android

If you see an error like `android.permission.ACCESS_NETWORK_STATE`, add the required permissions to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

The plugin's manifest includes these permissions, but your app's manifest must also declare them.

### Always showing offline

- Check device network settings
- Verify you're not in airplane mode
- On Android, ensure the app has network access permissions declared in `AndroidManifest.xml`
- Check if HTTPS connectivity tests are being blocked by firewall or network restrictions

### Ping-pong effect (rapidly switching between online/offline)

The plugin includes smart failure handling to prevent this:

- Requires 2 consecutive HTTPS test failures before overriding native status
- Respects HTTPS test results when they conflict with native status
- If you still experience ping-pong, it may indicate network instability or firewall blocking HTTPS tests

### iOS build issues

- Ensure your iOS deployment target is 12.0 or higher (required for `NWPathMonitor`)
- Run `pod install` in the `ios` directory if needed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/sabeelmuttil/connectivity_validator).
