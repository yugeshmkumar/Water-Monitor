# Quick Fix: Enable Local Network Access

## The Problem

Your logs show:
```
Error Domain=NSURLErrorDomain Code=-1009
UserInfo={_NSURLErrorNWPathKey=unsatisfied (Local network prohibited)
```

**Translation:** iOS is blocking your app from connecting to devices on your local WiFi network (192.168.1.x addresses).

---

## The Solution (2 minutes)

### Step 1: Open Info.plist in Xcode

1. In Xcode, locate `Info.plist` in your project navigator
2. Right-click → Open As → **Source Code**

### Step 2: Add These Lines

Find the opening `<dict>` tag (usually near the top) and add this anywhere inside:

```xml
<!-- Local Network Access (Required for WiFi device communication) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<!-- Bonjour Services (Helps with .local hostname resolution) -->
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_ws._tcp</string>
</array>
```

**OR** if you prefer the visual editor:

1. Right-click Info.plist → Open As → **Property List**
2. Hover over any row and click the **+** button
3. Add these keys:

| Key | Type | Value |
|-----|------|-------|
| Privacy - Local Network Usage Description | String | Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi. |
| Bonjour services | Array | (add items below) |
| → Item 0 | String | _http._tcp |
| → Item 1 | String | _ws._tcp |

### Step 3: Test

1. **Delete the app** from your device/simulator (to reset permissions)
2. Clean build: `Cmd + Shift + K`
3. Build and run: `Cmd + R`
4. Add a device and complete setup
5. When the app tries to connect via WiFi, iOS will show:

   ```
   ┌─────────────────────────────────────┐
   │  "Zenovaa CONNECT" Would Like to   │
   │  Find and Connect to Devices on     │
   │  Your Local Network                 │
   │                                      │
   │  Zenovaa CONNECT needs to access    │
   │  your local network to communicate  │
   │  with your water level sensors via  │
   │  WiFi.                              │
   │                                      │
   │     [ Don't Allow ]    [ OK ]       │
   └─────────────────────────────────────┘
   ```

6. **Tap "OK"** to grant permission
7. WiFi connection should now succeed!

---

## What This Does

### NSLocalNetworkUsageDescription
- **Required** for iOS 14+ apps that access local network (192.168.x.x, 10.x.x.x, etc.)
- Shows a permission prompt to users
- Your custom message explains why you need access

### NSBonjourServices
- Declares which network services you use
- Helps iOS resolve `.local` hostnames (like `Tank-1.local`)
- Required for mDNS/Bonjour discovery

---

## Verification

After adding and rebuilding, check the logs:

### ❌ Before (blocked):
```
Error Domain=NSURLErrorDomain Code=-1009
UserInfo={_NSURLErrorNWPathKey=unsatisfied (Local network prohibited)
[ConnectionManager] WiFi failed: 192.168.1.17
```

### ✅ After (working):
```
[ConnectionManager] WiFi connected: 192.168.1.17
[ConnectionManager] Opening WebSocket for Tank-1...
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
```

---

## Troubleshooting

### Permission Not Showing?
- Delete and reinstall the app
- Make sure Info.plist was saved
- Clean build folder: `Cmd + Shift + K`

### Still Getting -1009 Error?
- Check that you granted permission (Settings > Privacy & Security > Local Network > Zenovaa CONNECT)
- Verify device and iPhone are on the same WiFi network
- Verify device IP address is correct (should be 192.168.1.x)

### Permission Denied?
Users can change this in:
**Settings > Privacy & Security > Local Network > Zenovaa CONNECT**

---

## Why This Wasn't an Issue Before

In iOS 13 and earlier, apps could access the local network without permission. iOS 14 introduced this privacy feature to prevent apps from scanning your local network without your knowledge.

**Your app needs this because:**
- It communicates with devices via HTTP/WebSocket on local IPs (192.168.1.x)
- It resolves `.local` hostnames (Tank-1.local, Tank-2.local)
- It's a legitimate use case (controlling your own IoT devices)

---

## One-Line Summary

**Add local network permission to Info.plist → Users grant permission → WiFi connections work** ✅
