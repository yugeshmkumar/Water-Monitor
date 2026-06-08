# Troubleshooting Guide

## 🎯 Overview

This guide covers common issues and their solutions for the Zenovaa CONNECT app.

---

## 🌐 WiFi Connection Issues

### Error -1009: Local Network Prohibited

**Symptoms:**
```
Error Domain=NSURLErrorDomain Code=-1009
"The Internet connection appears to be offline."
UserInfo={_NSURLErrorNWPathKey=unsatisfied (Local network prohibited)
```

**Cause:** iOS is blocking local network access because permission isn't configured.

**Solution:**

1. **Add to Info.plist:**
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>
   
   <key>NSBonjourServices</key>
   <array>
       <string>_http._tcp</string>
       <string>_ws._tcp</string>
   </array>
   ```

2. **Delete and reinstall app** (to trigger permission prompt)
3. **Grant permission** when prompted
4. **Verify** in Settings > Privacy & Security > Local Network

**See:** [Info.plist Configuration](../setup/info-plist-configuration.md)

**Status:** ⚠️ **CRITICAL** - Required for WiFi to work

---

### Error -1001: Request Timeout

**Symptoms:**
```
Error Domain=NSURLErrorDomain Code=-1001 "The request timed out."
[ConnectionManager] WiFi failed: 192.168.1.17
[HealthMonitor] ⚠️ Device degraded
```

**Cause:** Device is not responding at the IP address.

**Possible Reasons:**

1. **Device is offline/powered off**
   - Check device power
   - Look for status LEDs

2. **Wrong IP address**
   - IP may have changed (DHCP)
   - Check router's connected devices list
   - Look for device MAC address in router

3. **Device WiFi not configured**
   - WiFi SSID/password not set
   - Device still only accessible via BLE

4. **Network issue**
   - Phone and device on different networks
   - Router blocking communication (AP Isolation)
   - Firewall blocking connections

**Solutions:**

#### Solution 1: Power Cycle Device
```
1. Turn off device
2. Wait 10 seconds
3. Turn on device
4. Wait 30 seconds for WiFi connection
5. Try connecting in app
```

#### Solution 2: Connect via BLE First
```
1. Open app
2. Tap on device
3. App should fall back to BLE automatically
4. Check device config for WiFi settings
5. Verify IP address shown
6. Update WiFi credentials if needed
```

#### Solution 3: Check Device is in BLE Range
```
[BLE] found: MacBook  RSSI: -51
[BLE] found: atomberg_R3...  RSSI: -63
❌ No "Tank-1" in scan results
```

If device not in BLE scan:
- Device is too far (move within 10m)
- Device is powered off
- Device battery dead

#### Solution 4: Verify Network Settings
```
1. Phone and device on SAME WiFi network
2. WiFi is 2.4 GHz (most IoT devices need 2.4 GHz, not 5 GHz)
3. Router not blocking device-to-device communication
4. Check router "AP Isolation" setting (should be OFF)
```

**See:** Device config logs for actual IP:
```
[BLE] AA03 raw data: {"ip":"192.168.1.17", ...}
```

---

## 📱 BLE Connection Issues

### Device Not Appearing in Scan

**Symptoms:**
```
[BLE] scan started
[BLE] found: MacBook  RSSI: -51
❌ Your device not found
```

**Causes:**

1. **Device powered off**
2. **Out of range** (BLE range ~10 meters)
3. **Device already connected** (to another device/app)
4. **Bluetooth off** on phone

**Solutions:**

1. **Check device is powered on**
   - Look for LED indicators
   - Power cycle if needed

2. **Move closer to device**
   - BLE works best within 5 meters
   - Remove obstacles between phone and device

3. **Check Bluetooth**
   - Settings > Bluetooth > ON
   - App has Bluetooth permission

4. **Restart BLE scan**
   - Pull down to refresh in app
   - Or force close and reopen app

---

### Device Connects Then Disconnects

**Symptoms:**
```
[BLE] connected to Tank-1
[BLE] discovered 6 characteristics
[BLE] peripheral disconnected
```

**Causes:**

1. **Weak signal** (device too far)
2. **Device went to sleep**
3. **WiFi upgrade attempted**

**Solutions:**

1. **Stay close** during setup
2. **Keep app in foreground** during BLE operations
3. **Check logs** - if device upgraded to WiFi successfully, disconnection is normal:
   ```
   [ConnectionManager] Upgrading to WiFi using saved IP
   [ConnectionManager] WiFi connected: 192.168.1.17
   ✅ This is expected behavior
   ```

---

## 🔔 Notification Issues

### Notifications Not Appearing

**Check:**

1. **Permission granted?**
   - Settings > Zenovaa CONNECT > Notifications > Allow
   
2. **Device state matches threshold?**
   - Low alert: Tank below 15% (default)
   - High alert: Tank above 85% (default)
   
3. **Check console logs:**
   ```
   [Notifications] 🔔 State change for Tank-1: normal → low at 12%
   ```
   
4. **Focus Mode / Do Not Disturb:**
   - Critical alerts should break through
   - Check Settings > Focus

**See:** [Notifications Feature Guide](../features/notifications.md)

---

### In-App Alerts Not Showing

**Symptoms:**
- No modal dialog when tank reaches threshold
- Only system notifications appear

**Check:**

1. **App in foreground?**
   - In-app alerts only show when app is active
   - Background uses system notifications

2. **Cooldown period:**
   - In-app alerts have 30-minute cooldown
   - Check logs:
     ```
     [InAppAlert] Cooldown active, skipping alert
     ```

3. **Alert thresholds:**
   - Check device config for alertLowPct / alertHighPct
   - Default: 15% low, 85% high

**See:** [In-App Alerts Guide](../features/in-app-alerts.md)

---

## 🖼️ Assets Issues

### Missing Logo Error

**Symptoms:**
```
No image named 'ZenovaaLogo' found in asset catalog
```

**Status:** ✅ **FIXED** (App now uses placeholder)

**Current Behavior:**
- App shows blue rounded square with water drop icon
- No console error
- App works perfectly

**To Add Real Logo:**

See: [Assets Setup Guide](../setup/assets-setup.md)

**Priority:** 🟡 Low-Medium (app works without it)

---

## 🚀 App Navigation Issues

### App Stuck on Add Device Screen

**Symptoms:**
- Complete device setup
- Tap "Done"
- Still showing add device screen
- Have to force close app

**Status:** ✅ **FIXED** (as of 2026-06-08)

**Fix Applied:**
- Proper BLE cleanup on dismiss
- Callback mechanism for sheet dismissal
- Auto-transition to home screen

**If still experiencing:**
1. Pull latest code changes
2. Clean build: `Cmd + Shift + K`
3. Rebuild: `Cmd + B`

**See:** [Changelog - Fix #4](../reference/changelog.md#fix-4-app-navigation-after-adding-device)

---

## 🔧 Build & Runtime Issues

### Build Errors

**Common issues:**

1. **"Development team not selected"**
   - Xcode > Signing & Capabilities > Team > Select your team

2. **"Bundle identifier already in use"**
   - Change bundle ID to something unique
   - General > Identity > Bundle Identifier

3. **"Missing SwiftData framework"**
   - Ensure deployment target is iOS 17.0+
   - General > Deployment Info > iOS 17.0

### Runtime Crashes

**Check console for:**

1. **CoreData errors:**
   - Usually auto-recovers
   - If persistent, delete app and reinstall

2. **Force unwrap errors:**
   - Check device config is properly set
   - Ensure device has required fields (nodeID, empty/full values)

3. **Network errors:**
   - See WiFi troubleshooting above

---

## 📊 Device Health Status

### Device Shows "Degraded"

**Meaning:** Device connectivity is unstable

**Causes:**
- WiFi connection failing
- Device responding slowly
- Intermittent network issues

**Polling frequency:**
- Healthy: Every 15 seconds
- Degraded: Every 60 seconds
- Offline: Every 300 seconds (5 minutes)

**Solution:**
1. Check WiFi connection
2. Verify device is on same network
3. Check signal strength (RSSI in logs)
4. Try power cycling device

### Device Shows "Offline"

**Meaning:** No successful connection for extended period

**Solution:**
1. Check device is powered on
2. Verify BLE range (move closer)
3. Check WiFi configuration
4. Review logs for specific errors

---

## 🔍 Debugging Tips

### Enable Verbose Logging

All logs are prefixed with tags:
- `[BLE]` - Bluetooth operations
- `[WiFi]` - WiFi operations
- `[ConnectionManager]` - Connection state
- `[HealthMonitor]` - Device health
- `[Notifications]` - Notification events

### Check Log Sequence

**Successful Connection:**
```
[ConnectionManager] Trying WiFi: 192.168.1.17
[ConnectionManager] WiFi connected: 192.168.1.17
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
✅ Working correctly
```

**WiFi Fails, BLE Works:**
```
[ConnectionManager] WiFi failed: 192.168.1.17
[ConnectionManager] Starting BLE scan for Tank-1
[BLE] found: Tank-1  RSSI: -55
[BLE] connected to Tank-1
✅ Fallback working correctly
```

**Device Completely Offline:**
```
[ConnectionManager] WiFi failed: 192.168.1.17
[BLE] scan started
[BLE] found: MacBook  RSSI: -51
❌ Tank-1 not found (device offline)
```

---

## 📱 Testing on Physical Device

**Common issues:**

1. **"Could not install app"**
   - Device storage full
   - Delete old builds
   - Free up space

2. **App crashes immediately**
   - Check deployment target matches device iOS version
   - Verify signing certificates

3. **Permissions not prompting**
   - Delete app and reinstall
   - iOS only prompts once
   - Check Settings > Privacy for already granted/denied permissions

---

## 🆘 Still Stuck?

### Diagnostic Checklist

Run through this checklist:

**Setup:**
- [ ] Info.plist has `NSLocalNetworkUsageDescription`
- [ ] Info.plist has `NSBonjourServices`
- [ ] Bluetooth permission granted
- [ ] Notification permission granted
- [ ] Local network permission granted

**Device:**
- [ ] Device powered on
- [ ] Status LEDs lit
- [ ] Within BLE range (10m)
- [ ] On same WiFi network as phone

**App:**
- [ ] Latest code pulled
- [ ] Clean build performed
- [ ] No build errors
- [ ] Running on device (not just simulator)

**Connectivity:**
- [ ] BLE scan finds other devices
- [ ] WiFi network accessible
- [ ] Router not blocking local communication

### Getting More Help

If issues persist:

1. **Collect full logs** from console
2. **Note exact error messages**
3. **Document steps to reproduce**
4. **Check** [Changelog](../reference/changelog.md) for recent fixes
5. **Review** [Architecture](../development/architecture.md) for system understanding

---

## 📚 Related Documentation

- [Getting Started](../setup/getting-started.md) - Initial setup
- [Info.plist Configuration](../setup/info-plist-configuration.md) - Required permissions
- [Notifications Guide](../features/notifications.md) - Notification system
- [Architecture](../development/architecture.md) - System design
- [Changelog](../reference/changelog.md) - Recent fixes

---

**Last Updated:** 2026-06-08  
**Covers:** App version 1.0.1 and later
