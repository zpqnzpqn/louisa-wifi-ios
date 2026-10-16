# 0002. Session Tracking Lifecycle on iOS

## Status
Accepted

## Context
On macOS, background execution allows a perpetual 60-second timer to monitor Wi-Fi connectivity and increment usage duration. On iOS, applications are suspended immediately after entering background state unless using background audio or continuous GPS tracking, which drain battery and introduce aggressive privacy warnings.

## Decision
1. Implement a timestamp-based session lifecycle in `Tracker`. When the app connects to `LouisaCoffee` or is brought to foreground while connected, it records `sessionStart`.
2. When the app is foregrounded, backgrounded, or performs network checks, it calculates the elapsed seconds between timestamps and credits them to the current store's `Usage Record`.
3. Expose `AppIntents` (`ConnectNearestLouisaIntent` and `LogLouisaVisitIntent`) enabling iOS Shortcuts Personal Automations (e.g., trigger when iPhone joins or leaves `LouisaCoffee`) to record exact session boundaries without background battery drain.
