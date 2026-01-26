# connectivity_validator

A Flutter plugin that provides **validated internet connectivity status** with real-time updates. Unlike basic connectivity checks, this plugin validates that the device has actual internet access (not just a network connection), detecting captive portals and ensuring the connection is truly functional.

## Features

- ✅ **Validated Connectivity**: Checks for real internet access, not just network connection
- ✅ **Captive Portal Detection**: Detects when connected to WiFi but behind a captive portal
- ✅ **Real-time Updates**: Stream-based API for continuous connectivity monitoring
- ✅ **Cross-platform**: Works on both Android and iOS
- ✅ **Lightweight**: Zero dependencies, framework-agnostic
- ✅ **Optimized**: Only emits updates when connectivity state actually changes

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  connectivity_validator: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android

No additional setup required. The plugin uses `ConnectivityManager` with `NET_CAPABILITY_VALIDATED` to ensure real internet connectivity.

### iOS

No additional setup required. The plugin uses `NWPathMonitor` with `.satisfied` status to detect validated connectivity.

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

The plugin uses Android's `ConnectivityManager` with `NetworkCallback` to monitor:
- `NET_CAPABILITY_INTERNET`: Network has internet access
- `NET_CAPABILITY_VALIDATED`: Network has been validated (bypasses captive portals)

Only when both capabilities are present, the connection is considered "online".

### iOS

The plugin uses iOS's `NWPathMonitor` to check network path status:
- `.satisfied`: Network path is satisfied and validated (indicates real internet access, not just a connection)

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
- Verify platform-specific permissions are granted (usually not required for basic connectivity)

### Always showing offline

- Check device network settings
- Verify you're not in airplane mode
- On Android, ensure the app has network access permissions (usually granted by default)

### iOS build issues

- Ensure your iOS deployment target is 12.0 or higher (required for `NWPathMonitor`)
- Run `pod install` in the `ios` directory if needed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/sabeelmuttil/connectivity_validator).
