# How It Works

## Overview

The plugin uses native capability checks plus HTTPS connectivity tests so you get **real** internet status, not just “network connected.” That catches captive portals and “WiFi on but no internet.”

## Android

- **Capability checks**: `ConnectivityManager` + `NetworkCallback`; uses `NET_CAPABILITY_INTERNET` and `NET_CAPABILITY_VALIDATED`.
- **HTTPS check**: When capabilities say online, requests to Google’s connectivity-check endpoints (e.g. `www.google.com/generate_204`) with 500ms timeout.
- **Failure handling**: Switches to offline only after 2 consecutive HTTPS failures to avoid ping-pong.
- **Periodic checks**: Every 2s for capability changes; HTTPS re-check every 5s; results cached 5s.

## iOS

- **Path checks**: `NWPathMonitor`; uses `.satisfied` for path status.
- **HTTPS check**: Same idea as Android when path is satisfied.
- **Failure handling**: Same 2-failure rule and caching as Android.

## Why HTTPS?

`NET_CAPABILITY_VALIDATED` (Android) and `NWPathMonitor.satisfied` (iOS) can still report “connected” when:

- The router has no internet
- You’re behind a captive portal
- DNS is broken

HTTPS requests to known endpoints give a real check that the device can reach the internet.
