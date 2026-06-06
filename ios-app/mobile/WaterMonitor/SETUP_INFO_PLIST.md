# Setup Info.plist - Fix WiFi Connectivity

## 🎯 What This Fixes

**Problem:** iOS is blocking your app from accessing local network (WiFi devices)

**Error:** `Error Code=-1009 "Local network prohibited"`

**Solution:** Add local network permission to Info.plist (2 minutes)

---

## 🚀 Quick Copy-Paste Solution

### Step 1: Locate Info.plist

1. Open your Xcode project
2. In Project Navigator (left sidebar), look for `Info.plist`
   - Usually in the project root or app folder
   - May also be in a folder like `WaterMonitor/Info.plist`

### Step 2: Open as Source Code

1. **Right-click** on `Info.plist`
2. Select **"Open As"** → **"Source Code"**

### Step 3: Add This Code

Find the opening `<dict>` tag (near the top of the file) and **paste this anywhere inside**:

```xml
<!-- ═══════════════════════════════════════════════════════════ -->
<!-- Local Network Access - Required for WiFi Device Communication -->
<!-- ═══════════════════════════════════════════════════════════ -->

<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<key>NSBonjourServices</key>
<array>
	<string>_http._tcp</string>
	<string>_ws._tcp</string>
</array>
```

### Step 4: Save and Close

1. Press `Cmd + S` to save
2. You can switch back to Property List view if you prefer:
   - Right-click → "Open As" → "Property List"

---

## 📸 Visual Guide

### Before (Source Code View):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	
	<!-- YOUR EXISTING KEYS... -->
	
</dict>
</plist>
```

### After (with new keys):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	
	<!-- ADD THESE KEYS ↓ -->
	<key>NSLocalNetworkUsageDescription</key>
	<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>
	
	<key>NSBonjourServices</key>
	<array>
		<string>_http._tcp</string>
		<string>_ws._tcp</string>
	</array>
	<!-- END NEW KEYS ↑ -->
	
	<!-- YOUR EXISTING KEYS... -->
	
</dict>
</plist>
```

---

## 🎨 Alternative: Property List View

If you prefer the visual editor:

### Step 1: Open as Property List
1. Right-click `Info.plist`
2. Select "Open As" → "Property List"

### Step 2: Add First Key
1. Hover over any row
2. Click the **+** button
3. In the new row, set:
   - **Key:** Type "Privacy - Local Network Usage Description" (or select from dropdown)
   - **Type:** String
   - **Value:** `Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.`

### Step 3: Add Second Key
1. Click **+** again
2. Set:
   - **Key:** "Bonjour services" (or select from dropdown)
   - **Type:** Array

### Step 4: Add Array Items
1. Click the disclosure triangle next to "Bonjour services" to expand it
2. Hover over the array and click **+** to add items
3. Add two items:
   - **Item 0:** String: `_http._tcp`
   - **Item 1:** String: `_ws._tcp`

### Visual Result:
```
▼ Information Property List
  ▼ Bonjour services                          Array  (2 items)
      Item 0                                  String  _http._tcp
      Item 1                                  String  _ws._tcp
    CFBundleDevelopmentRegion                 String  $(DEVELOPMENT_LANGUAGE)
    Privacy - Local Network Usage Description String  Zenovaa CONNECT needs to...
```

---

## ✅ Verification

After adding the keys, verify they're there:

### In Source Code View:
Look for these two keys:
```xml
<key>NSLocalNetworkUsageDescription</key>
<key>NSBonjourServices</key>
```

### In Property List View:
Look for:
- "Privacy - Local Network Usage Description"
- "Bonjour services" (with 2 items)

---

## 🧪 Testing

### Step 1: Clean and Rebuild
```
1. Delete app from device/simulator
2. In Xcode: Product → Clean Build Folder (Cmd + Shift + K)
3. Build: Cmd + B
4. Run: Cmd + R
```

### Step 2: Add a Device
1. Open the app
2. Add a new device (or reconfigure existing)
3. Complete WiFi setup

### Step 3: Grant Permission
When the app tries to connect via WiFi, iOS will show:

```
┌──────────────────────────────────────────┐
│  "Zenovaa CONNECT" Would Like to Find   │
│  and Connect to Devices on Your Local   │
│  Network                                 │
│                                          │
│  Zenovaa CONNECT needs to access your   │
│  local network to communicate with your │
│  water level sensors via WiFi.          │
│                                          │
│     [ Don't Allow ]         [ OK ]      │
└──────────────────────────────────────────┘
```

**Tap "OK"**

### Step 4: Verify Success
Check the logs for:

**✅ Success:**
```
[ConnectionManager] WiFi connected: 192.168.1.17
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
```

**❌ Before (error):**
```
Error Code=-1009 "The Internet connection appears to be offline."
Local network prohibited
```

---

## 🔧 Troubleshooting

### Issue: Permission prompt doesn't appear
**Solution:**
- Delete and reinstall the app (iOS only prompts once)
- Check Settings → Privacy & Security → Local Network

### Issue: Permission denied
**Solution:**
- Go to Settings → Privacy & Security → Local Network
- Find "Zenovaa CONNECT"
- Toggle it ON

### Issue: Build error after adding
**Solution:**
- Check XML syntax is correct
- Ensure all tags are properly closed: `</string>`, `</array>`, `</dict>`
- Make sure you pasted inside the `<dict>...</dict>` section

### Issue: Keys not showing up
**Solution:**
- Make sure you saved the file (Cmd + S)
- Try opening in the other view (Source Code ↔ Property List)
- Restart Xcode if needed

---

## 🎯 What These Keys Do

### NSLocalNetworkUsageDescription
- **Purpose:** Explains to users why you need local network access
- **Required:** Yes, for iOS 14+ apps accessing local network
- **User-Facing:** This text appears in the permission prompt

### NSBonjourServices
- **Purpose:** Declares which network services your app uses
- **Services:**
  - `_http._tcp` - HTTP connections to devices (API calls)
  - `_ws._tcp` - WebSocket connections (real-time data)
- **Helps with:** Resolving `.local` hostnames (e.g., `Tank-1.local`)

---

## ⏭️ Next Steps

After adding Info.plist entries:

1. ✅ WiFi connectivity fixed
2. ⏭️ Next: Add logo assets → [SETUP_APP_ICON.md](SETUP_APP_ICON.md)
3. 🧪 Finally: Test everything → [TESTING_GUIDE.md](TESTING_GUIDE.md)

---

## 📋 Summary

**What you did:**
- Added 2 keys to Info.plist (1 string, 1 array)

**What you get:**
- iOS permission prompt for local network access
- Ability to connect to WiFi devices
- WebSocket connections work
- No more -1009 errors

**Time spent:** 2 minutes ⏱️

---

**Done with this? Continue to:** [SETUP_APP_ICON.md](SETUP_APP_ICON.md) 🚀
