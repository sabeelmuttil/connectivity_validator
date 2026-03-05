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

## Ping-pong (online/offline flicker)

The plugin requires 2 consecutive HTTPS failures before going offline. If it still flickers, the network may be unstable or HTTPS checks may be blocked.

## iOS build issues

- Set iOS deployment target to **12.0+** (needed for `NWPathMonitor`).
- **SPM**: Run `flutter clean` then `flutter pub get` if the plugin doesn’t resolve.
- **CocoaPods**: Run `pod install` in the `ios` directory.
