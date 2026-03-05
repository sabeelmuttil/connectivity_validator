# API Reference

## ConnectivityValidator

Main class for connectivity status.

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
