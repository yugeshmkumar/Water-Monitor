# Changelog

All notable changes to the Zenovaa CONNECT app are documented in this file.

---

## [1.0.1] - 2026-06-08

### 🐛 Bug Fixes

#### Fixed: App Navigation After Adding Device

**Issue:** App remained stuck on the add device screen after completing setup. Users had to force close and reopen the app to see the newly added device.

**Root Cause:**  
- The "Done" button wasn't properly cleaning up BLE state
- Sheet dismissal callback wasn't triggering screen transition
- BLE scan and connection remained active

**Files Changed:**
- `AddDeviceView.swift`
- `DeviceHealthCheckView.swift`

**Solution:**
```swift
// AddDeviceView.swift - Added proper cleanup
DeviceHealthCheckView(device: device, onDone: {
    cm.ble.stopScan()
    cm.ble.disconnect()
    onComplete?()
    dismiss()
})
```

**Result:** ✅ App now correctly returns to home screen after adding a device

---

#### Fixed: Missing Logo Console Error

**Issue:** Console displayed error: `No image named 'ZenovaaLogo' found in asset catalog`

**Root Cause:**  
- Splash screen code referenced `Image("ZenovaaLogo")`
- Asset was never added to `Assets.xcassets`

**Files Changed:**
- `ContentView.swift`

**Solution:**
```swift
// Added fallback placeholder
if let _ = UIImage(named: "ZenovaaLogo") {
    Image("ZenovaaLogo")  // Use custom logo if available
} else {
    // Fallback placeholder (blue square + water drop)
    ZStack {
        RoundedRectangle(cornerRadius: 28)
            .fill(gradient)
        Image(systemName: "drop.circle.fill")
    }
}
```

**Result:** ✅ No more console errors, app uses placeholder until real logo is added

---

### ✨ Enhancements

#### Updated: Splash Screen Branding

**Change:** Replaced generic "Water Monitor" branding with "Zenovaa CONNECT"

**Files Changed:**
- `ContentView.swift`

**What Changed:**
- Added blue gradient background (deep blue → cyan)
- Changed logo reference to "ZenovaaLogo"
- Updated text from "Water Monitor" to "Zenovaa CONNECT"
- Added professional typography and spacing
- Added subtle shadow to logo

**Visual Result:**
```
╔═══════════════════════╗
║ Blue Gradient         ║
║   [Zenovaa Logo]      ║
║     Zenovaa           ║
║   C O N N E C T       ║
╚═══════════════════════╝
```

---

### ⚠️ Known Issues

#### WiFi Connection Timeout

**Issue:** Devices at specific IP addresses may timeout during WiFi connection

**Error:** `Error -1001: Request timed out`

**Diagnosis:**
- Error changed from `-1009` (local network prohibited) to `-1001` (timeout)
- This confirms local network permission is working
- Device is likely powered off or IP address changed

**Workaround:**
1. Check device is powered on
2. Move closer for BLE connection
3. Verify IP address in router settings
4. App will fall back to BLE automatically

**See:** [Troubleshooting - WiFi Timeout](../development/troubleshooting.md#error-1001-request-timeout)

---

### 📋 Configuration Required

These changes require user action to complete setup:

#### Local Network Permission

**Required:** Add to `Info.plist`

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_ws._tcp</string>
</array>
```

**Why:** iOS 14+ requires explicit permission for local network access

**Without this:** WiFi connections fail with error -1009

**See:** [Info.plist Configuration Guide](../setup/info-plist-configuration.md)

---

#### Logo Assets (Optional)

**Optional:** Add logo to `Assets.xcassets`

- Create image set named `ZenovaaLogo`
- Add sizes: 120px (@1x), 240px (@2x), 360px (@3x)
- Extract from brand image (just the icon, no text)

**Without this:** App uses placeholder icon (blue square + water drop)

**See:** [Assets Setup Guide](../setup/assets-setup.md)

---

## [1.0.0] - 2026-06-06

### 🎉 Initial Release

#### Core Features

- ✅ BLE device discovery and connection
- ✅ WiFi device connection with automatic fallback
- ✅ Real-time water level monitoring
- ✅ Multiple device support
- ✅ Device health monitoring
- ✅ Progressive notification escalation system
- ✅ In-app alert dialogs
- ✅ Historical data tracking
- ✅ Insights and analytics
- ✅ Device configuration wizard

#### Notification System

**System Notifications:**
- Progressive escalation (15min, 30min, 1hr, 2hr, daily)
- Critical alert interruption level
- Focus mode bypass for critical alerts
- State-based alerting (normal, low, nearly-low, high, nearly-full)

**In-App Alerts:**
- Modal dialogs when app is active
- Smart motor controller detection
- Action buttons (View Details, Dismiss)
- 30-minute cooldown between alerts

#### Connectivity

**BLE (Bluetooth Low Energy):**
- Automatic device discovery
- Characteristic-based communication
- Real-time data streaming
- Configuration via BLE

**WiFi:**
- HTTP API communication
- WebSocket live data streaming
- Automatic fallback to BLE if WiFi fails
- mDNS hostname resolution (.local)

#### Data Management

- SwiftData persistence
- Automatic migration support
- Device configuration storage
- Historical readings archive
- Health status tracking

---

## Version History Summary

| Version | Date | Key Changes |
|---------|------|-------------|
| 1.0.1 | 2026-06-08 | Navigation fix, logo placeholder, WiFi diagnostic improvements |
| 1.0.0 | 2026-06-06 | Initial release with full feature set |

---

## Migration Notes

### 1.0.0 → 1.0.1

**Database:** No migration required. Backward compatible.

**Code Changes:**
- Pull latest code
- Clean build (`Cmd + Shift + K`)
- Rebuild (`Cmd + B`)

**Configuration:**
- Add Info.plist entries for local network (if not already done)
- Optionally add logo assets

**User Data:** Preserved. No action needed.

---

## Upcoming Features

### Planned for 1.1.0

- [ ] Motor control integration
- [ ] Predictive alerts (based on drain patterns)
- [ ] Actionable notifications (interactive buttons)
- [ ] Daily summary notifications
- [ ] Leak detection alerts
- [ ] Enhanced insights with trends

### Under Consideration

- [ ] Multiple tanks per device
- [ ] Custom alert messages
- [ ] Export data to CSV
- [ ] Cloud backup
- [ ] Multi-user support
- [ ] Siri shortcuts

---

## How to Report Issues

If you encounter issues not listed here:

1. Check [Troubleshooting Guide](../development/troubleshooting.md)
2. Review console logs for error messages
3. Note steps to reproduce
4. Check if issue is already fixed in latest version

---

## Documentation Updates

### 2026-06-08

- Created organized documentation structure in `docs/` folder
- Consolidated scattered documentation files
- Added comprehensive troubleshooting guide
- Updated all cross-references

### 2026-06-06

- Initial documentation created
- System integration guide
- Notification system documentation
- In-app alerts documentation

---

**For detailed technical information, see:**
- [Architecture Guide](../development/architecture.md)
- [Feature Documentation](../features/)
- [Setup Guides](../setup/)

---

**Last Updated:** 2026-06-08  
**Current Version:** 1.0.1  
**Status:** Stable
