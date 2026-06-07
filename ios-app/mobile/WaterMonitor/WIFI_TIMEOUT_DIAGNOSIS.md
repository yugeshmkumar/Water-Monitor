# WiFi Timeout Diagnosis Guide

## 🎯 Your Current Issue

Your latest logs show:
```
Error Domain=NSURLErrorDomain Code=-1001 "The request timed out."
[ConnectionManager] WiFi failed: 192.168.1.17
[HealthMonitor] ⚠️ Device Tank-1 degraded (polling every 60s)
```

## ✅ Good News!

**Local network permission is working!** The error changed from:
- ❌ Before: `-1009` (Local network prohibited)
- ✅ Now: `-1001` (Request timeout)

This means iOS is **allowing** the connection attempt, but the device isn't responding.

---

## 🔍 What to Check

### Step 1: Is Tank-1 Appearing in BLE Scan?

**Look in your logs for:**
```
[BLE] found: Tank-1  RSSI: -XX
```

**Right now I see:**
```
[BLE] found: atomberg_R3_b0a6041a7848_3  RSSI: -63
[BLE] found: MacBook  RSSI: -51
[BLE] found: TY  RSSI: -98
```

❌ **Tank-1 is NOT appearing in BLE scan results**

**This could mean:**
1. Device is powered off
2. Device is out of BLE range (too far away)
3. Device is in sleep mode
4. Device has a different BLE name

---

### Step 2: Is BLE Fallback Working?

**After WiFi fails, you should see:**
```
[ConnectionManager] Starting BLE scan for Tank-1
```

**I don't see this in your logs**, which suggests:
- App is trying WiFi
- WiFi fails
- But BLE fallback may not be triggering

**Why this might happen:**
- The 2-second wait may not be enough
- The `isConnected()` check may be returning true incorrectly
- The BLE scan may already be running

---

### Step 3: Check Device Configuration

**Questions:**

1. **Did you configure WiFi on Tank-1?**
   - During initial setup, did you enter SSID and password?
   - Check: Open Tank-1 in the app → View config → Is WiFi SSID set?

2. **Is the device connected to WiFi?**
   - If it has WiFi configured, it should connect automatically
   - Check your router's connected devices list
   - Look for "Tank-1" or MAC address `58:E6:C5:16:4B:E8` (from your earlier logs)

3. **Has the IP address changed?**
   - The app is trying `192.168.1.17`
   - But your router may have assigned a different IP
   - Check router DHCP leases

---

## 🔧 How to Fix

### Option 1: Power Cycle the Device

1. Turn off Tank-1
2. Wait 10 seconds
3. Turn it back on
4. Wait 30 seconds for it to connect to WiFi
5. Check if it appears in your app

---

### Option 2: Connect via BLE and Check Status

Since BLE should work even if WiFi doesn't:

1. **Open the app**
2. **Go to Tank-1 device card**
3. **Tap on it** to open detail view
4. **Watch the logs** for BLE connection attempt
5. **Check the config** to see current WiFi settings

**Expected logs:**
```
[ConnectionManager] Attempting WiFi connection to 192.168.1.17
[ConnectionManager] WiFi failed: 192.168.1.17
[ConnectionManager] Starting BLE scan for Tank-1
[BLE] found: Tank-1  RSSI: -XX
[BLE] connected to Tank-1
[BLE] AA03 config decoded: node=Tank-1 ...
```

---

### Option 3: Delete and Re-add Device

If the device is stuck:

1. **In the app, delete Tank-1:**
   - Go to device list
   - Swipe left on Tank-1
   - Delete

2. **Re-add the device:**
   - Tap "+"
   - Ensure Tank-1 appears in BLE scan
   - Connect via BLE
   - Complete setup again
   - **This time, carefully verify WiFi credentials**

---

### Option 4: Check WiFi Network

**Make sure:**
- Tank-1 and your phone are on the **same WiFi network**
- Your WiFi has **2.4 GHz band** enabled (most IoT devices need 2.4 GHz, not 5 GHz)
- Your router isn't blocking communication between devices (check "AP Isolation" setting)
- WiFi password is correct (spaces, special characters matter!)

---

## 📊 Expected vs Actual Behavior

### Expected (Working WiFi):
```
[ConnectionManager] Attempting WiFi connection to 192.168.1.17
[ConnectionManager] Trying WiFi: 192.168.1.17 for Tank-1
[ConnectionManager] WiFi connected: 192.168.1.17
[ConnectionManager] Opening WebSocket for Tank-1...
[WiFi] WebSocket connected successfully
[WiFi] Received live reading: 35% @ 76.5cm
✅ Device showing real-time data
```

### Actual (Current):
```
[ConnectionManager] Trying WiFi: 192.168.1.17 for Tank-1
Task <...> finished with error [-1001] Error Domain=NSURLErrorDomain
[ConnectionManager] WiFi failed: 192.168.1.17
[HealthMonitor] ⚠️ Device Tank-1 degraded (polling every 60s)
❌ Device marked as degraded
```

### Expected (WiFi fails, BLE works):
```
[ConnectionManager] WiFi failed: 192.168.1.17
[ConnectionManager] Starting BLE scan for Tank-1
[BLE] found: Tank-1  RSSI: -55
[BLE] connected to Tank-1
[BLE] AA01 level: {"level_pct":35,"distance_cm":76.5,"ts":123}
✅ Device working via BLE
```

### Actual (BLE not found):
```
[ConnectionManager] WiFi failed: 192.168.1.17
[BLE] found: atomberg_R3_b0a6041a7848_3  RSSI: -63
[BLE] found: MacBook  RSSI: -51
❌ Tank-1 not in scan results
```

---

## 🎯 Most Likely Cause

Based on your logs, **Tank-1 is not powered on or is out of range**.

**Evidence:**
1. ✅ WiFi timeout (not local network block) → permission working
2. ❌ Tank-1 not in BLE scan results → device not broadcasting
3. ✅ Other BLE devices found → BLE is working
4. ❌ No BLE connection → device unavailable

**Recommendation:**
1. **Check if Tank-1 is powered on**
2. **Move closer to the device** (within 10 meters)
3. **Power cycle the device** if it's on
4. **Look at the device** for status LEDs (is it working?)

---

## 📱 Quick Test

Try this right now:

1. **Open your app**
2. **Go near Tank-1 physically** (within 5 meters)
3. **Pull down to refresh** the device list
4. **Watch the logs** for `[BLE] found: Tank-1`

**If you see Tank-1 in BLE scan:**
- ✅ Device is working
- ✅ BLE is fine
- ⚠️ Just WiFi needs configuration

**If you don't see Tank-1:**
- ❌ Device is off, dead battery, or broken
- 🔧 Power cycle or check hardware

---

## 🆘 Still Stuck?

**Share these logs:**

1. Full logs from app launch to WiFi failure
2. Whether Tank-1 appears in BLE scan
3. Device config screen (screenshot if possible)
4. Router's connected devices list (look for Tank-1 or its MAC)

**I can help further if you provide:**
- Complete logs showing the full connection attempt
- Confirmation of whether Tank-1 is powered on
- Whether you configured WiFi during initial setup

---

## 📚 Related Docs

- `CHANGELOG.md` - What was fixed
- `TESTING_GUIDE.md` - How to test thoroughly
- `TECHNICAL_DETAILS.md` - Deep dive into connection logic

---

**TL;DR: Tank-1 isn't responding because it's not broadcasting BLE. Check if it's powered on and nearby.**
