# Testing Guide - Verify All Fixes Work

## 🎯 Purpose

This guide helps you verify that all fixes are working correctly.

**Prerequisites:**
- ✅ Applied Info.plist changes ([SETUP_INFO_PLIST.md](SETUP_INFO_PLIST.md))
- ✅ Added logo assets ([SETUP_APP_ICON.md](SETUP_APP_ICON.md))

---

## 🧪 Complete Test Flow

### Preparation

1. **Delete the app** from your device/simulator
   - This resets all permissions and caches
   - Long-press app icon → Remove App → Delete

2. **Clean build folder**
   ```
   Xcode → Product → Clean Build Folder
   Or: Cmd + Shift + K
   ```

3. **Build the app**
   ```
   Xcode → Product → Build
   Or: Cmd + B
   ```

4. **Run the app**
   ```
   Xcode → Product → Run
   Or: Cmd + R
   ```

---

## Test 1: App Launch & Splash Screen ✅

### What to Test:
App launches and shows splash screen correctly

### Steps:
1. Launch the app
2. Observe the splash screen

### Expected Result:
```
✅ Blue gradient background (deep blue → cyan)
✅ Zenovaa logo icon appears (120x120, centered)
✅ "Zenovaa" text in large serif font
✅ "CONNECT" text with letter spacing
✅ No console error about missing 'ZenovaaLogo'
✅ Smooth transition to welcome or home screen
```

### Common Issues:
| Issue | Solution |
|-------|----------|
| Missing logo error | Check Assets.xcassets has "ZenovaaLogo" image set |
| Logo not showing | Verify all 3 sizes (@1x, @2x, @3x) are added |
| Wrong colors | Logo asset should have blue gradient built in |

---

## Test 2: App Icon ✅

### What to Test:
App icon appears on home screen

### Steps:
1. Go to device/simulator home screen
2. Look for your app icon

### Expected Result:
```
✅ Zenovaa "Z" logo icon visible
✅ Blue gradient background
✅ Icon is crisp and clear (not pixelated)
✅ NOT showing default iOS app icon
```

### Common Issues:
| Issue | Solution |
|-------|----------|
| Default icon showing | Check AppIcon in Assets.xcassets is filled |
| Blurry icon | Ensure 1024x1024 is in App Store slot |
| Icon not updating | Delete app, clean build, reinstall |

---

## Test 3: Add Device Flow ✅

### What to Test:
Complete device setup flow works smoothly

### Steps:
1. Tap "Add Your First Sensor" (or + button if you have devices)
2. Allow Bluetooth permission if prompted
3. Wait for scan to find devices
4. Select a device (e.g., "Tank-2")
5. Wait for BLE connection
6. Configure WiFi:
   - Enter SSID
   - Enter password
   - Set node ID (or keep default)
7. Configure tank:
   - Set volume
   - Set alert thresholds
   - Optionally calibrate
8. Configure pins (test sensor)
9. Tap "Done" on final screen

### Expected Result:
```
✅ Scan finds devices
✅ BLE connection succeeds
✅ Config screens load
✅ Settings save successfully
✅ Health check screen appears
✅ Tapping "Done" returns to home screen immediately
✅ Device appears in device list
✅ NO need to restart app
```

### Common Issues:
| Issue | Solution |
|-------|----------|
| Stuck on add device screen | Make sure you applied code fixes to AddDeviceView.swift |
| Can't find devices | Check Bluetooth is on, device is powered |
| Config times out | Make sure device is in range |
| Still stuck after "Done" | Verify DeviceHealthCheckView.swift was updated |

---

## Test 4: Local Network Permission ✅

### What to Test:
iOS prompts for local network access and WiFi connects

### Steps:
1. Add a device (or use existing)
2. Complete WiFi configuration
3. Wait for app to attempt WiFi connection

### Expected Result:
```
✅ iOS shows permission prompt:
   "Zenovaa CONNECT Would Like to Find and 
    Connect to Devices on Your Local Network"
   
   With your custom message:
   "Zenovaa CONNECT needs to access your local
    network to communicate with your water level
    sensors via WiFi."

✅ Tap "OK" to grant permission
✅ WiFi connection succeeds
✅ Logs show: "WiFi connected: 192.168.1.x"
✅ WebSocket opens successfully
✅ Real-time data starts streaming
```

### Common Issues:
| Issue | Solution |
|-------|----------|
| No permission prompt | Check Info.plist has NSLocalNetworkUsageDescription |
| Permission denied | Settings → Privacy → Local Network → Toggle ON |
| Prompt doesn't show | Delete and reinstall app (iOS only prompts once) |
| Still getting -1009 error | Verify both Info.plist keys are added correctly |

---

## Test 5: WiFi Connection ✅

### What to Test:
Device connects via WiFi and streams data

### Steps:
1. Grant local network permission (from Test 4)
2. Wait for connection
3. Observe console logs

### Expected Result:
```
Console logs show:

✅ [ConnectionManager] Trying WiFi: 192.168.1.x for Tank-X
✅ [ConnectionManager] WiFi connected: 192.168.1.x
✅ [ConnectionManager] Opening WebSocket for Tank-X...
✅ [WiFi] WebSocket connecting to ws://192.168.1.x/live
✅ [WiFi] WebSocket connected successfully
✅ [WiFi] Received live reading: 35% @ 76.5cm
✅ [WiFi] Received live reading: 34% @ 77.8cm
✅ (readings continue streaming every few seconds)

❌ NO errors like:
   ❌ Error Code=-1009
   ❌ Local network prohibited
   ❌ Connection timeout
```

### Common Issues:
| Issue | Solution |
|-------|----------|
| -1009 error | Info.plist not updated or permission denied |
| Timeout | Check device and phone on same WiFi network |
| Wrong IP | Update device IP in app settings |
| WebSocket fails | Check device firmware is running web server |

---

## Test 6: Device List & Navigation ✅

### What to Test:
Device appears in list and navigation works

### Steps:
1. After adding device, verify you're on home screen
2. Check device list/dashboard

### Expected Result:
```
✅ Device appears in list immediately
✅ Device name shown correctly
✅ Level percentage displayed
✅ Connection status shown
✅ Can tap device to view details
✅ Can navigate between tabs
✅ Can add more devices
```

---

## 📊 Full Success Checklist

Complete this checklist to verify everything works:

### App Launch:
- [ ] App launches without crashes
- [ ] Splash screen shows Zenovaa logo
- [ ] No "ZenovaaLogo not found" error
- [ ] Smooth transition to welcome/home

### App Icon:
- [ ] Icon visible on home screen
- [ ] Shows Zenovaa "Z" logo
- [ ] Icon is crisp and clear

### Permissions:
- [ ] Bluetooth permission granted
- [ ] Local network permission prompt appears
- [ ] Local network permission granted
- [ ] Notifications permission granted (if applicable)

### Device Setup:
- [ ] Can scan for devices via BLE
- [ ] Can connect to device
- [ ] Can configure WiFi settings
- [ ] Can configure tank settings
- [ ] Can test sensor reading
- [ ] Tapping "Done" returns to home

### WiFi Connectivity:
- [ ] WiFi connection succeeds
- [ ] No -1009 errors
- [ ] WebSocket opens
- [ ] Real-time data streaming
- [ ] Device status updates

### Navigation:
- [ ] No stuck screens
- [ ] No need to restart app
- [ ] Can navigate between tabs
- [ ] Can add multiple devices
- [ ] Can view device details

---

## 🔍 Console Log Patterns

### ✅ Healthy Logs:
```
[Migration] Database healthy, no migration needed
[ConnectionManager] App entering foreground - resuming monitoring
[Notifications] Permission granted
[BLE] central state → 5
[BLE] scan started
[BLE] found: Tank-2  RSSI: -55
[BLE] connected to Tank-2
[BLE] AA03 config decoded: node=Tank-2 empty=107.3 full=20.5
[ConnectionManager] WiFi connected: 192.168.1.17
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
```

### ❌ Problem Logs:
```
❌ No image named 'ZenovaaLogo' found
   → Fix: Add logo to Assets.xcassets

❌ Error Domain=NSURLErrorDomain Code=-1009
❌ Local network prohibited
   → Fix: Update Info.plist and grant permission

❌ [ConfigWizard] First-time setup complete
   (then app doesn't navigate)
   → Fix: Should be fixed in code, verify latest changes

❌ [ConnectionManager] WiFi failed: 192.168.1.x
❌ [HealthMonitor] 🔴 Device appears offline
   → Check: Device on same network, correct IP
```

---

## 🔧 Troubleshooting Guide

### Issue: App crashes on launch
**Possible causes:**
- Missing required frameworks
- Code syntax error
- SwiftData schema issue

**Solutions:**
1. Check build errors in Xcode
2. Clean build folder
3. Reset simulator/device
4. Check console for crash logs

---

### Issue: WiFi permission not working
**Possible causes:**
- Info.plist not saved
- Wrong key names
- Permission already denied

**Solutions:**
1. Verify Info.plist has both keys (source code view)
2. Delete and reinstall app
3. Check Settings → Privacy → Local Network
4. Make sure NSBonjourServices array has 2 items

---

### Issue: Logo not showing
**Possible causes:**
- Wrong image set name
- Missing image sizes
- Images not in Assets.xcassets

**Solutions:**
1. Verify image set name is exactly "ZenovaaLogo"
2. Check all 3 sizes are added (@1x, @2x, @3x)
3. Clean build and rebuild
4. Check images are PNG format

---

### Issue: Navigation still stuck
**Possible causes:**
- Code changes not applied
- Old build running
- Cache issue

**Solutions:**
1. Verify AddDeviceView.swift has latest code
2. Clean build folder thoroughly
3. Delete app and reinstall
4. Restart Xcode and rebuild

---

## 📱 Device-Specific Testing

### iPhone:
- [ ] Test on iPhone simulator
- [ ] Test on physical iPhone (if available)
- [ ] Portrait orientation works
- [ ] All screen sizes look good

### iPad:
- [ ] Test on iPad simulator (if applicable)
- [ ] Portrait and landscape both work
- [ ] Layouts adapt properly

---

## 🎯 Performance Testing

### App Startup:
- [ ] Launches in < 3 seconds
- [ ] Splash screen shows immediately
- [ ] No noticeable lag

### Device Scanning:
- [ ] Finds devices within 5 seconds
- [ ] BLE connection < 3 seconds
- [ ] Config loads instantly

### WiFi Connection:
- [ ] Initial connection < 5 seconds
- [ ] Reconnection < 3 seconds
- [ ] Data streaming smooth (no stuttering)

---

## ✅ Final Verification

If you can check ALL of these, you're done! 🎉

- [ ] App launches showing Zenovaa splash screen
- [ ] App icon visible on home screen
- [ ] Can add device smoothly from start to finish
- [ ] "Done" button returns to home (no stuck screens)
- [ ] iOS prompts for local network permission
- [ ] WiFi connections succeed (no -1009 errors)
- [ ] Real-time data streaming works
- [ ] No console errors about missing images
- [ ] Can navigate app without crashes
- [ ] Multiple devices can be added

**All checked?** Congratulations! Your app is fully functional with Zenovaa branding! ✅

---

## 📚 What to Do If Tests Fail

1. **Review logs carefully** - They tell you exactly what's wrong
2. **Check the specific issue** in troubleshooting section above
3. **Verify you completed all setup steps:**
   - [SETUP_INFO_PLIST.md](SETUP_INFO_PLIST.md)
   - [SETUP_APP_ICON.md](SETUP_APP_ICON.md)
4. **See technical details:** [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md)
5. **Check changelog:** [CHANGELOG.md](CHANGELOG.md)

---

**Everything working?** See [BRANDING_GUIDE.md](BRANDING_GUIDE.md) for design specs! 🎨
