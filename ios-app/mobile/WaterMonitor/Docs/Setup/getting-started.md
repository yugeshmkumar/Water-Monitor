# Getting Started - Zenovaa CONNECT

## 🎯 Overview

This guide walks you through setting up and running the Zenovaa CONNECT water level monitoring app.

## ✅ Prerequisites

- **Xcode:** 15.0 or later
- **iOS:** 17.0+ (deployment target)
- **Device:** iPhone or iPad for testing
- **Hardware:** Water level sensor devices (Tank-1, Tank-2, etc.)

## 🚀 Quick Setup (5 minutes)

### Step 1: Clone and Open Project

1. Open the project in Xcode
2. Select your development team (Signing & Capabilities)
3. Choose a simulator or connected device

### Step 2: Configure Info.plist ⚠️ **REQUIRED**

**Add local network permission:**

Open `Info.plist` and add:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_ws._tcp</string>
</array>
```

**Why:** iOS requires this for WiFi connections to local devices.

**Details:** See [Info.plist Configuration](info-plist-configuration.md)

### Step 3: Build and Run

```bash
# Clean build folder
Cmd + Shift + K

# Build
Cmd + B

# Run
Cmd + R
```

### Step 4: Grant Permissions

On first launch, the app will request:

1. **Bluetooth Permission** - For BLE device discovery
2. **Notification Permission** - For water level alerts
3. **Local Network Permission** - For WiFi device connections

**Grant all permissions** for full functionality.

## 📱 First Run Experience

### If You Have No Devices Saved:

1. App shows **Welcome Screen**
2. Tap "Add Your First Sensor"
3. Follow setup wizard:
   - Connect via BLE
   - Configure WiFi
   - Calibrate tank levels
   - Configure sensor pins
   - Test connection

### If You Have Saved Devices:

1. App shows **Home Screen** with device list
2. Devices attempt WiFi connection
3. Falls back to BLE if WiFi unavailable
4. Real-time data displays automatically

## 🔧 Optional: Add Logo Assets

The app currently uses a placeholder icon. To add your Zenovaa logo:

**See:** [Assets Setup Guide](assets-setup.md)

**Priority:** 🟡 Medium (app works without it)

## 🎯 Next Steps

### To Add a Device:

1. Power on your sensor device
2. Open app
3. Tap "+" button
4. Select device from BLE scan
5. Follow configuration wizard

### To Configure WiFi on a Device:

1. Connect to device via BLE
2. Open device settings
3. Enter WiFi SSID and password
4. Save configuration
5. Device will connect to WiFi automatically

### To Monitor Water Levels:

1. Open app
2. View dashboard for all devices
3. Tap a device for detailed view
4. Check history and insights tabs

## 🐛 Troubleshooting

### App Won't Build

**Check:**
- Development team is selected
- Bundle identifier is unique
- Xcode version is 15.0+

### WiFi Connections Fail

**Issue:** Error -1009 "Local network prohibited"

**Fix:** Add `NSLocalNetworkUsageDescription` to Info.plist (see Step 2)

**Details:** [Troubleshooting Guide](../development/troubleshooting.md#wifi-connection-issues)

### Devices Not Found

**Check:**
- Device is powered on
- Within BLE range (10 meters)
- Bluetooth is enabled on phone
- App has Bluetooth permission

### Missing Logo Error

**Issue:** Console shows "No image named 'ZenovaaLogo' found"

**Fix:** This is expected! App uses placeholder icon. See [Assets Setup](assets-setup.md) to add real logo.

## 📊 Verification Checklist

After setup, verify:

- [ ] App builds without errors
- [ ] Bluetooth permission granted
- [ ] Notification permission granted
- [ ] Local network permission granted
- [ ] Can scan for BLE devices
- [ ] Can add a device
- [ ] Can connect via WiFi
- [ ] Real-time data displays
- [ ] Notifications work

## 📚 Related Documentation

- **Info.plist Configuration:** [info-plist-configuration.md](info-plist-configuration.md)
- **Assets Setup:** [assets-setup.md](assets-setup.md)
- **Troubleshooting:** [../development/troubleshooting.md](../development/troubleshooting.md)
- **Architecture:** [../development/architecture.md](../development/architecture.md)

---

**Next:** [Info.plist Configuration](info-plist-configuration.md) →
