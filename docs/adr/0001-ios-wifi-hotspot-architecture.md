# 0001. iOS Wi-Fi Hotspot Architecture

## Status
Accepted

## Context
On macOS, `CoreWLAN` enables silent background Wi-Fi scanning (`scanForNetworks(withName:)`) and iterative password association without user prompts. On iOS, `CoreWLAN` does not exist and private Wi-Fi scanning is prohibited.

iOS provides `NEHotspotConfigurationManager.apply()`, which triggers an unavoidable iOS system prompt: `"LouisaWiFi Wants to Join Wi-Fi Network LouisaCoffee?"`. iOS cannot silently attempt multiple passwords in a loop; if a password fails, the system association fails. Furthermore, free Apple ID personal teams may have limitations accessing the `Access WiFi Information` entitlement for BSSID reading.

## Decision
1. Use `CoreLocation` to determine the nearest Louisa store upon app launch or intent execution.
2. In Auto-Connect or 1-tap mode, apply the #1 candidate password (or the learned password from `LearnedStoreCache`).
3. Display all candidate password buttons directly on the nearest store card so the user can switch candidate passwords with a single tap if the primary fails.
4. Provide a generated Wi-Fi QR Code (`WIFI:S:LouisaCoffee;T:WPA;P:<password>;;`) and one-tap clipboard copy as non-entitlement fallback mechanisms.
5. Query `NEHotspotNetwork.fetchCurrent()` when connected to record BSSID into `LearnedStoreCache` when permitted, gracefully degrading if BSSID is nil.
