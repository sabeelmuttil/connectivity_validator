# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-08-03

### Fixed

- Reuse one native EventChannel subscription across multiple Dart stream listeners, preventing duplicate network callbacks and probes
- Ignore stale, out-of-order Web probe results so an older fetch cannot overwrite a newer online/offline state
- Emit native `true` stream values only after the HTTPS validation probe succeeds; OS network signals are now hints rather than immediate online results
- Try the next native probe endpoint after non-redirect HTTP failures, allowing the Cloudflare fallback to work when a proxy blocks one endpoint

### Changed

- Clarified that the default Web `no-cors` probe provides reachability only; strict HTTP-204 and captive-portal validation requires a same-origin or CORS-enabled `probeUrl`
- Documented the Web Content Security Policy (`connect-src`) requirement for probe URLs

## [0.1.1] - 2026-08-01

### Changed

- README: document Dart `>=3.4.0` / Flutter `>=3.22.0` requirement; add Web row to comparison table
- Package description updated to list Android, iOS, macOS, and Web
- Troubleshooting docs: Web CORS / always-offline tips; CI path filters include `macos/`
- Removed unused `plugin_platform_interface` dependency

## [0.1.0] - 2026-08-01

### Added

- **Web platform support** — `navigator.onLine` baseline plus a GET fetch probe to `https://www.gstatic.com/generate_204` in `no-cors` mode (fulfill/reject as the connectivity signal; status codes are not readable under `no-cors`)
- Page Visibility: pause periodic probes when the tab is hidden; re-probe when visible again
- Optional `ConnectivityValidator(probeUrl: …)` — on Web, a custom URL uses CORS mode and requires HTTP `204`; ignored on Android, iOS, and macOS
- README **Web setup** section documenting CORS / `no-cors` behavior and when to supply a same-origin or CORS-enabled `probeUrl`
- SDK floor raised to Dart `>=3.4.0` / Flutter `>=3.22.0` for `package:web`

### Fixed

- Web dart2js/WASM compile failure from tearing off `AbortController.abort` in `Timer` — wrap in a closure instead

### Changed

- Minimum Dart/Flutter constraints updated for Web (`package:web` / `dart:js_interop`)

## [0.0.9] - 2026-07-10

### Fixed

- **Swift Package Manager (SPM) support** for iOS and macOS to restore full pub.dev score: added `FlutterFramework` dependency to iOS `Package.swift` and migrated macOS to the SPM-compatible `macos/connectivity_validator/Sources/` layout with its own `Package.swift`

## [0.0.8] - 2026-07-07

### Added

- **macOS support** (10.14+) using native `NWPathMonitor` plus the same HTTPS validation probe as iOS. Requires the `com.apple.security.network.client` sandbox entitlement (see README).

### Changed

- Added a Cloudflare (`cp.cloudflare.com/generate_204`) probe fallback so validation works in regions where Google endpoints are blocked (Android, iOS and macOS)
- Only HTTP 204 from `generate_204` endpoints counts as validated connectivity, closing a captive-portal false positive where 3xx redirects were treated as online
- Added pub.dev `topics` and a clearer package description for discoverability

## [0.0.7] - 2026-07-07

### Fixed

- False "offline" results on high-latency mobile networks by increasing the HTTPS probe timeout from 500ms to 2s (Android and iOS)
- Flaky online/offline toggling with debounced offline reporting: requires 2 independent offline signals before emitting `false`; unambiguous offline (no active network) still emits immediately
- Stale `NET_CAPABILITY_VALIDATED` (Android) and `NWPath` `.satisfied` (iOS) no longer report online during periodic checks — HTTPS probe result is authoritative
- Captive portal false positives: only HTTP 204 from `generate_204` endpoints counts as validated connectivity (Android and iOS)
- Android resource leak on engine detach (network callback and executor now cleaned up on hot restart)

### Changed

- `onConnectivityChanged` stream filters consecutive duplicate values via `.distinct()` so listeners only see actual state changes

## [0.0.6] - 2026-03-05

### Added

- **Get status on-demand**: `getConnectivityStatus` to get current connectivity once without subscribing to the stream (use when you need a single check, e.g. on button tap, instead of listening)

## [0.0.5] - 2026-03-04

### Added

- Support details for Swift Package Manager in documentation

### Changed

- Enhanced README for clarity
- Updated podspec and pubspec.lock for dependency versions

## [0.0.4] - 2026-01-27

### Added

- **Swift Package Manager (SPM) support**: Added `Package.swift` for iOS to support Swift Package Manager alongside CocoaPods
- Full SPM compatibility while maintaining CocoaPods backward compatibility

### Changed

- Updated iOS plugin structure to support both CocoaPods and Swift Package Manager
- Podspec updated to point to new SPM-compatible source file locations

## [0.0.3] - 2026-01-27

## [0.0.2] - 2026-01-27

### Changed

- **SDK compatibility**: Relaxed Dart SDK constraint from `^3.10.7` to `">=3.0.0 <4.0.0"` for broader compatibility with Flutter projects

### Fixed

- Code formatting improvements in Android plugin implementation

## [0.0.1] - 2026-01-27

### Added

- Initial release of connectivity_validator plugin
- **Validated connectivity checking**: Detects real internet access, not just network connection
- **Captive portal detection**: Identifies when connected to WiFi but behind a captive portal
- **Real-time updates**: Stream-based API (`onConnectivityChanged`) for continuous connectivity monitoring
- **Android implementation**:
  - Uses `ConnectivityManager.NetworkCallback` for real-time network monitoring
  - Checks `NET_CAPABILITY_INTERNET` and `NET_CAPABILITY_VALIDATED` capabilities
  - Sends initial state immediately when stream is listened to
  - Optimized to only emit updates when connectivity state actually changes
- **iOS implementation**:
  - Uses `NWPathMonitor` for network path monitoring
  - Checks `.satisfied` status to detect validated connectivity
  - Handles network state changes on background queue
  - Sends updates to Flutter on main thread
- **Example app**:
  - Complete working example demonstrating plugin usage
  - GetX-based state management example with `NetworkStatusController`
  - Visual indicators (icons and colors) for connectivity status
  - Real-time UI updates using reactive state management
- **Comprehensive documentation**:
  - Detailed README with installation instructions
  - Multiple state management examples (StreamBuilder, GetX, Provider, Riverpod, BLoC, ValueNotifier)
  - API reference documentation
  - Platform-specific implementation details
  - Best practices and troubleshooting guide

### Technical Details

- **Channel name**: `connectivity_validator/status` (consistent across all platforms)
- **Zero dependencies**: Plugin itself has no external dependencies
- **Framework-agnostic**: Works with any state management solution
- **Optimized**: Prevents duplicate emissions by tracking last state
- **Thread-safe**: Properly handles main thread requirements for Flutter communication

### Platform Support

- ✅ Android (API 24+)
- ✅ iOS (iOS 12.0+)
