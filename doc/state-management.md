# State Management Options

The plugin is framework-agnostic. Examples for common approaches:

## StreamBuilder (no extra dependencies)

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

## GetX

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
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) => isOffline.value = !isOnline);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}

// Usage: Get.put(NetworkStatusController(), permanent: true);
// Obx(() => Text(Get.find<NetworkStatusController>().isOffline.value ? 'Offline' : 'Online'))
```

## Provider

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

## Riverpod

```dart
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityValidator().onConnectivityChanged;
});

// Or with StateNotifier
class ConnectivityNotifier extends StateNotifier<bool> {
  StreamSubscription? _subscription;

  ConnectivityNotifier() : super(false) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) => state = isOnline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) => ConnectivityNotifier());
```

## BLoC

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  StreamSubscription? _subscription;

  ConnectivityBloc() : super(ConnectivityInitial()) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) => add(ConnectivityChanged(isOnline)));
  }

  @override
  Stream<ConnectivityState> mapEventToState(ConnectivityEvent event) async* {
    if (event is ConnectivityChanged) yield ConnectivityLoaded(event.isOnline);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

// Define ConnectivityEvent, ConnectivityChanged(isOnline), ConnectivityState, ConnectivityInitial, ConnectivityLoaded(isOnline)
```

## ValueNotifier

```dart
import 'dart:async';
import 'package:connectivity_validator/connectivity_validator.dart';
import 'package:flutter/material.dart';

class ConnectivityNotifier extends ValueNotifier<bool> {
  StreamSubscription? _subscription;

  ConnectivityNotifier() : super(false) {
    _subscription = ConnectivityValidator()
        .onConnectivityChanged
        .listen((isOnline) => value = isOnline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Usage: ValueListenableBuilder<bool>(valueListenable: notifier, builder: (context, isOnline, child) => Text(isOnline ? 'Online' : 'Offline'))
```
