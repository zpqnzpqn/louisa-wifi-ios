# Louisa Wi-Fi iOS Context

Native iOS client for automatically connecting to Louisa Coffee Wi-Fi networks across Taiwan and visualizing visit statistics.

## Language

### Core Domain

**Store**:
A physical Louisa Coffee branch with geographical coordinates, phone number, and candidate Wi-Fi passwords.
_Avoid_: Branch, shop, location

**Candidate Passwords**:
The ordered array of derived passwords computed from a Store's phone number according to regional dialing rules.
_Avoid_: Guesses, password list

**Learned Store Cache**:
The persistent mapping between a Wi-Fi router's BSSID, the verified Store name, and the working password that succeeded previously.
_Avoid_: Memory, saved networks

**Hotspot Configuration**:
An explicit iOS network association request submitted via `NEHotspotConfigurationManager` to configure and join the `LouisaCoffee` SSID.
_Avoid_: Wi-Fi profile, mobileconfig

**Usage Record**:
Aggregated daily duration (in seconds) spent connected to specific Louisa stores, used to render the contribution heatmap.
_Avoid_: Logs, session history

**Brand Icon**:
The official Louisa Coffee visual identity featuring the goddess profile with flowing orange hair on an ivory background.
_Avoid_: Generic cup, placeholder icon
