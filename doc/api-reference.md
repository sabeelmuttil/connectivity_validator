# API Reference

## ConnectivityValidator

Main class for connectivity status.

```dart
ConnectivityValidator({String? probeUrl});
```

- **`probeUrl`** (optional) — On **Web**, overrides the default gstatic probe. Custom URLs use CORS mode and must return HTTP `204` (same-origin or CORS-enabled). Ignored on Android, iOS, and macOS.

### onConnectivityChanged → Stream&lt;bool&gt;

Stream of connectivity status:

- **`true`** — Internet available and validated
- **`false`** — No internet or captive portal

Emits on subscribe (initial state), then only when status changes.

```dart
final validator = ConnectivityValidator();

// Initial state
final initial = await validator.onConnectivityChanged.first;

// Listen
validator.onConnectivityChanged.listen((isOnline) {
  print(isOnline ? 'Online' : 'Offline');
});
```

### getConnectivityStatus → Future&lt;bool&gt;

One-shot check (same meaning as stream values). Use for button taps or imperative checks.
