# Troubleshooting

## Stream not emitting

- Confirm you’re listening and not cancelling the subscription too early.
- On Android, ensure `ACCESS_NETWORK_STATE` is in your app’s `AndroidManifest.xml`.

## Android permission errors

Add to your app’s `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

## Always offline

- Check device network and airplane mode.
- Ensure Android manifest has the permissions above.
- Check if a firewall or network blocks HTTPS connectivity checks.
- **macOS**: ensure `com.apple.security.network.client` is in both DebugProfile and Release entitlements (see README).
- **Web**: the default probe uses `no-cors` fetch to gstatic. If you always see offline with a custom `probeUrl`, the endpoint likely lacks CORS — use a same-origin or CORS-enabled URL that returns HTTP `204`, or omit `probeUrl` to use the default. See [README Web setup](../README.md#web-setup).

## Ping-pong (online/offline flicker)

The plugin requires 2 consecutive HTTPS failures before going offline (native platforms). If it still flickers, the network may be unstable or HTTPS checks may be blocked. On Web, probes pause while the tab is hidden and run about every 12s when visible.

## iOS build issues

- Set iOS deployment target to **12.0+** (needed for `NWPathMonitor`).
- **SPM**: Run `flutter clean` then `flutter pub get` if the plugin doesn’t resolve.
- **CocoaPods**: Run `pod install` in the `ios` directory.

## Web build / dart2js issues

- Requires **Dart >=3.4.0** and **Flutter >=3.22.0** (`package:web`).
- If compile fails on `AbortController.abort` tear-offs, ensure you’re on a package version that wraps the abort in a closure (fixed in 0.1.0+).
