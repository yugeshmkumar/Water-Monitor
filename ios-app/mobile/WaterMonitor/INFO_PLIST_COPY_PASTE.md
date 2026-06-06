# Info.plist - Copy & Paste

## Quick Copy-Paste Solution

### Option 1: Source Code View (Easiest)

1. Open `Info.plist` in Xcode
2. Right-click → **Open As → Source Code**
3. Find the first `<dict>` tag
4. **Copy and paste this** anywhere inside the `<dict>...</dict>`:

```xml
<!-- ═══════════════════════════════════════════════════════════ -->
<!-- Local Network Access (Required for WiFi device connections) -->
<!-- ═══════════════════════════════════════════════════════════ -->

<!-- Permission prompt message -->
<key>NSLocalNetworkUsageDescription</key>
<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>

<!-- Bonjour service types for mDNS/.local hostname resolution -->
<key>NSBonjourServices</key>
<array>
	<string>_http._tcp</string>
	<string>_ws._tcp</string>
</array>
```

5. Save the file
6. Clean and rebuild: `Cmd + Shift + K`, then `Cmd + B`

---

### Option 2: Property List View

If you prefer the visual editor:

1. Open `Info.plist` in Xcode
2. Right-click → **Open As → Property List**
3. Hover over any row and click the **+** button
4. Add these two entries:

#### Entry 1: Local Network Description
```
Key:   Privacy - Local Network Usage Description
Type:  String
Value: Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.
```

#### Entry 2: Bonjour Services
```
Key:   Bonjour services
Type:  Array
```

Then expand the array and add two items:

```
Item 0
Type:  String
Value: _http._tcp

Item 1
Type:  String  
Value: _ws._tcp
```

---

## Complete Info.plist Example

Here's what your Info.plist should look like (showing relevant sections):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Your existing keys -->
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Zenovaa CONNECT</string>
	<!-- ... other keys ... -->
	
	<!-- ADD THESE FOR LOCAL NETWORK ACCESS -->
	<key>NSLocalNetworkUsageDescription</key>
	<string>Zenovaa CONNECT needs to access your local network to communicate with your water level sensors via WiFi.</string>
	
	<key>NSBonjourServices</key>
	<array>
		<string>_http._tcp</string>
		<string>_ws._tcp</string>
	</array>
	<!-- END OF NEW KEYS -->
	
	<!-- Your existing keys continue -->
	<key>UIApplicationSceneManifest</key>
	<dict>
		<!-- ... -->
	</dict>
</dict>
</plist>
```

---

## Additional Permissions (Optional)

While you're editing Info.plist, you might want to add these as well:

### Bluetooth Permission (for BLE connections)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Zenovaa CONNECT uses Bluetooth to discover and configure your water level sensors.</string>
```

### Camera Permission (if you plan to add QR code scanning later)

```xml
<key>NSCameraUsageDescription</key>
<string>Zenovaa CONNECT uses the camera to scan QR codes on your sensors for quick setup.</string>
```

---

## Verification

After adding, your Info.plist should contain:

✅ `NSLocalNetworkUsageDescription` - String value explaining local network usage  
✅ `NSBonjourServices` - Array with `_http._tcp` and `_ws._tcp`

### Visual Verification in Property List View:

```
▼ Information Property List
  ▼ Bonjour services                          Array  (2 items)
      Item 0                                  String  _http._tcp
      Item 1                                  String  _ws._tcp
    Privacy - Local Network Usage Description String  Zenovaa CONNECT needs to...
```

---

## Testing

1. **Delete the app** from your device/simulator
2. Clean: `Cmd + Shift + K`
3. Build: `Cmd + B`
4. Run: `Cmd + R`
5. Add a device
6. When WiFi connection is attempted, you should see:

   **Permission Prompt:**
   ```
   "Zenovaa CONNECT" Would Like to Find and
   Connect to Devices on Your Local Network
   
   Zenovaa CONNECT needs to access your local
   network to communicate with your water level
   sensors via WiFi.
   
   [ Don't Allow ]    [ OK ]
   ```

7. Tap **OK**
8. WiFi connection should succeed!

---

## Common Issues

### Issue: Permission prompt doesn't appear
**Solution:** Delete and reinstall the app. iOS only prompts once, and you may have missed it.

### Issue: "Key already exists" error when pasting
**Solution:** Search for `NSLocalNetworkUsageDescription` in your Info.plist - you may have already added it. Update the value if needed.

### Issue: Build error after adding
**Solution:** 
- Check that all `<key>` tags have matching values
- Ensure array syntax is correct
- Verify closing tags: `</array>`, `</string>`, etc.

### Issue: Permission still denied in logs
**Solution:** Check Settings > Privacy & Security > Local Network > Zenovaa CONNECT is enabled

---

## After Adding

Check your logs for success:

### ❌ Before:
```
Error Domain=NSURLErrorDomain Code=-1009
_NSURLErrorNWPathKey=unsatisfied (Local network prohibited)
[ConnectionManager] WiFi failed: 192.168.1.17
```

### ✅ After:
```
[ConnectionManager] WiFi connected: 192.168.1.17
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
```

---

## Summary

**Just copy and paste the XML block at the top into your Info.plist file!**

The two keys required are:
1. `NSLocalNetworkUsageDescription` - Explains why you need local network access
2. `NSBonjourServices` - Declares which services you use (_http._tcp, _ws._tcp)

That's it! ✅
