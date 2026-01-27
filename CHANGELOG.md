# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
