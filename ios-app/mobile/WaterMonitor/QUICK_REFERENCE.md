# Quick Reference Card - Zenovaa CONNECT Rebranding

## 🚨 Issues in Your App Logs

| Device | IP | Status | Action Needed |
|--------|-----|--------|---------------|
| **Tank-1** | 192.168.1.161 | 🔴 Offline | Check device power & WiFi |
| **Tank-2** | 192.168.1.17 | ✅ Online | Working correctly |

**Minor Issues:**
- Tank-2 IP mismatch (saved: .165, actual: .17) - auto-corrects
- WebSocket occasional timeouts - app recovers automatically
- Network metadata warnings - harmless

---

## ✅ What I've Done

### 1. Updated Splash Screen Code
**File:** `ContentView.swift`
- ✅ Added blue gradient background
- ✅ Changed to "Zenovaa CONNECT" branding
- ✅ Added professional typography
- ✅ Added logo shadow effect

### 2. Created Documentation
- ✅ `APP_ICON_AND_SPLASH_SETUP.md` - Complete Xcode setup guide
- ✅ `LOGO_EXTRACTION_GUIDE.md` - How to extract icon from your image
- ✅ `SPLASH_SCREEN_PREVIEW.md` - Visual preview
- ✅ `ZenovaaSplashPreview.swift` - Preview code you can test
- ✅ `REBRANDING_SUMMARY.md` - Full summary

---

## 📋 Your 3-Step Checklist

### ☐ Step 1: Extract Logo (5 min)
1. Open your brand image in any image editor
2. Crop to **just the icon** (rounded square with Z symbol)
3. Export as PNG at **1024x1024 pixels**
4. Save as `zenovaa-icon-1024.png`

**Tools:** Preview (Mac), Photoshop, Figma, or online croppers

---

### ☐ Step 2: Generate Icon Sizes (2 min)
1. Go to [appicon.co](https://appicon.co)
2. Upload your 1024x1024 PNG
3. Select "iOS"
4. Click "Generate"
5. Download the zip file

**Also create for splash:**
- 120x120 (save as `logo-120.png`)
- 240x240 (save as `logo-240.png`)
- 360x360 (save as `logo-360.png`)

---

### ☐ Step 3: Add to Xcode (5 min)

#### App Icon:
1. Open Xcode project
2. Navigate to **Assets.xcassets**
3. Click **AppIcon**
4. Drag all sizes from appicon.co zip into their slots

#### Splash Logo:
1. In **Assets.xcassets**, click **+** button
2. Select **New Image Set**
3. Name it **`ZenovaaLogo`** (exact spelling!)
4. Drag images:
   - `logo-120.png` → @1x slot
   - `logo-240.png` → @2x slot
   - `logo-360.png` → @3x slot

#### Build & Test:
```bash
Cmd + Shift + K  # Clean
Cmd + B          # Build
Cmd + R          # Run
```

---

## 🎨 Design Specs (Quick Reference)

**Colors:**
- Deep Blue: `#3869D2`
- Cyan Blue: `#4FB6ED`
- Text Accent: `#B2E6FF`

**Logo:**
- Format: Square PNG
- App Icon: 1024x1024
- Splash: 120/240/360px

**Typography:**
- "Zenovaa": 48pt, bold, serif
- "CONNECT": 24pt, +8 tracking

---

## 🎯 What You'll Get

**App Icon:**
```
[Z Logo Icon]  ← On home screen
```

**Splash Screen:**
```
╔══════════════════╗
║  Blue Gradient   ║
║                  ║
║    [Z Icon]      ║
║                  ║
║    Zenovaa       ║
║   C O N N E C T  ║
║                  ║
╚══════════════════╝
```

---

## ⚠️ Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| Image not found | Check name is exactly `ZenovaaLogo` |
| Icon not updating | Delete app, clean build, reinstall |
| Blurry icon | Ensure PNG is high quality |
| Wrong colors | Verify hex codes in extracted image |

---

## 📱 Test Checklist

After setup, verify:
- [ ] App icon shows on home screen
- [ ] Splash shows gradient background
- [ ] Logo appears (no missing image error)
- [ ] "Zenovaa" and "CONNECT" text display
- [ ] Looks good on iPhone
- [ ] Looks good on iPad (if applicable)

---

## ⏱️ Total Time: 15-30 minutes

**Questions?** See full docs:
- `REBRANDING_SUMMARY.md` - Complete overview
- `APP_ICON_AND_SPLASH_SETUP.md` - Detailed instructions

---

**You're almost done! Just extract the logo and add it to Xcode.** 🚀
