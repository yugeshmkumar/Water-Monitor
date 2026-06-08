# Info.plist Configuration

## 🎯 Overview

iOS requires explicit permissions for local network access. This guide shows you how to configure `Info.plist` properly.

## ⚠️ Required Configuration

### Local Network Access (Critical)

**Why it's needed:**

Your app communicates with water level sensors via:
- **HTTP:** `http://192.168.1.x/api/status`
- **WebSocket:** `ws://192.168.1.x/live`
- **mDNS:** `Tank-1.local`, `Tank-2.local`

iOS blocks local network access by default starting in iOS 14.

### Error Without This:

```
Error Domain=NSURLErrorDomain Code=-1009
"The Internet connection appears to be offline."
UserInfo={_NSURLErrorNWPathKey=unsatisfied (Local network prohibited)
```

**Translation:** iOS is blocking your app from accessing devices on `192.168.x.x` addresses.

## ✅ How to Add Permission

### Method 1: Source Code View (Recommended)

1. Open `Info.plist` in Xcode
2. Right-click → **Open As → Source Code**
3. Find the opening `<dict>` tag
4. **Paste this inside:**

```xml
<!-- Local Network Access (Required for WiFi device connections) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<!-- Bonjour Services (Helps with .local hostname resolution) -->
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_ws._tcp</string>
</array>
```

5. Save file
6. Clean build: `Cmd + Shift + K`
7. Build: `Cmd + B`

### Method 2: Property List View

If you prefer the visual editor:

1. Open `Info.plist` in Xcode
2. Right-click → **Open As → Property List**
3. Hover over any row and click **+**
4. Add these entries:

| Key | Type | Value |
|-----|------|-------|
| Privacy - Local Network Usage Description | String | Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi. |
| Bonjour services | Array | (see items below) |

**For Bonjour services array, add two items:**

| Item | Type | Value |
|------|------|-------|
| Item 0 | String | `_http._tcp` |
| Item 1 | String | `_ws._tcp` |

## 🔍 What Each Key Does

### NSLocalNetworkUsageDescription

- **Type:** String
- **Purpose:** Explains why you need local network access
- **When shown:** iOS displays this in the permission prompt
- **Required:** Yes (iOS 14+)

**Example prompt:**

```
┌─────────────────────────────────────┐
│ "Zenovaa CONNECT" Would Like to    │
│ Find and Connect to Devices on     │
│ Your Local Network                 │
│                                     │
│ Zenovaa CONNECT needs to access    │
│ your local network to communicate  │
│ with your water level sensors via  │
│ WiFi.                               │
│                                     │
│   [ Don't Allow ]    [ OK ]         │
└─────────────────────────────────────┘
```

### NSBonjourServices

- **Type:** Array of strings
- **Purpose:** Declares which network services you use
- **When used:** For mDNS/Bonjour hostname resolution
- **Required:** Yes (for `.local` hostnames)

**Why `_http._tcp`:**
- Your devices serve HTTP API at `http://Tank-1.local/api/`

**Why `_ws._tcp`:**
- Your devices serve WebSocket at `ws://Tank-1.local/live`

## 📱 Testing the Configuration

### Step 1: Delete and Reinstall

iOS only prompts for permission **once**. To test:

1. Delete app from device/simulator
2. Clean build: `Cmd + Shift + K`
3. Build and run: `Cmd + R`

### Step 2: Add a Device

1. Open app
2. Add a new device
3. Complete BLE setup
4. When WiFi connection is attempted, you should see the permission prompt

### Step 3: Grant Permission

Tap **"OK"** to allow local network access.

### Step 4: Verify Success

**Check logs for:**

```
✅ [ConnectionManager] WiFi connected: 192.168.1.17
✅ [WiFi] WebSocket connected successfully
✅ [WiFi] Received live reading: 35% @ 76.5cm
```

**No longer see:**

```
❌ Error -1009 "Local network prohibited"
```

## 🔧 Troubleshooting

### Issue: Permission Prompt Not Showing

**Causes:**
1. Already granted/denied previously
2. Info.plist not saved properly
3. App not cleaned before rebuild

**Solution:**
1. Delete app completely
2. Verify Info.plist has the keys
3. Clean build folder: `Cmd + Shift + K`
4. Rebuild and reinstall

### Issue: Still Getting Error -1009

**Check:**

1. **Info.plist has the keys:**
   ```bash
   # Open Info.plist and search for:
   NSLocalNetworkUsageDescription
   ```

2. **App has permission in Settings:**
   - Open Settings app
   - Privacy & Security → Local Network
   - Find "Zenovaa CONNECT"
   - Ensure toggle is ON

3. **Device and phone on same WiFi:**
   - Both must be connected to same network
   - Check router's connected devices list

### Issue: Error Changed to -1001 (Timeout)

**Good news!** This means:
- ✅ Permission is granted
- ✅ iOS is allowing the connection
- ⚠️ Device isn't responding (different issue)

**See:** [Troubleshooting Guide - WiFi Timeout](../development/troubleshooting.md#wifi-timeout-error-1001)

## 📊 Before vs After

### Before (Without Permission):

```
[ConnectionManager] Trying WiFi: 192.168.1.17
❌ Error -1009: Local network prohibited
❌ [ConnectionManager] WiFi failed
❌ [HealthMonitor] Device degraded
```

### After (With Permission):

```
[ConnectionManager] Trying WiFi: 192.168.1.17
✅ [ConnectionManager] WiFi connected: 192.168.1.17
✅ [WiFi] WebSocket connected
✅ [WiFi] Received live reading: 35% @ 76.5cm
✅ Device showing real-time data
```

## 🎯 Complete Info.plist Example

Here's what your Info.plist should look like (showing relevant sections):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys -->
    <key>CFBundleDisplayName</key>
    <string>Zenovaa CONNECT</string>
    
    <!-- LOCAL NETWORK PERMISSION (REQUIRED) -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>
    
    <key>NSBonjourServices</key>
    <array>
        <string>_http._tcp</string>
        <string>_ws._tcp</string>
    </array>
    
    <!-- BLUETOOTH PERMISSION (REQUIRED) -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Zenovaa CONNECT uses Bluetooth to discover and configure your water level sensors.</string>
    
    <!-- Your other existing keys -->
</dict>
</plist>
```

## ✅ Verification Checklist

After adding the configuration:

- [ ] Keys added to Info.plist
- [ ] File saved
- [ ] Clean build performed
- [ ] App deleted from device
- [ ] App rebuilt and reinstalled
- [ ] Permission prompt appeared
- [ ] Permission granted
- [ ] WiFi connections working
- [ ] No error -1009 in logs

## 📚 Related Documentation

- **Getting Started:** [getting-started.md](getting-started.md)
- **Troubleshooting WiFi:** [../development/troubleshooting.md](../development/troubleshooting.md)
- **Architecture:** [../development/architecture.md](../development/architecture.md)

## 🔗 Apple Documentation

- [Supporting Local Network Privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
- [Bonjour Services](https://developer.apple.com/documentation/bundleresources/information_property_list/nsbonjourservices)

---

**Status:** ⚠️ **REQUIRED** - App cannot connect to devices via WiFi without this

**Next:** [Assets Setup](assets-setup.md) →
