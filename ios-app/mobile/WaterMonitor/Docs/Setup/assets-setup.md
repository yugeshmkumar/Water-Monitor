# Assets Setup Guide

## 🎯 Overview

This guide shows you how to add app icons and branding assets to Zenovaa CONNECT.

## ⚠️ Current Status

**Logo Asset:** ⏳ Optional - App uses placeholder  
**App Icon:** ⏳ Optional - Pending setup

**The app works without these!** They're for branding and polish.

---

## 🎨 Splash Screen Logo

### Current Behavior

**Without logo asset:**
- App shows blue rounded square with water drop icon (SF Symbol)
- No console errors
- Professional placeholder appearance

**With logo asset:**
- Shows your actual Zenovaa brand icon
- Matches your company branding
- Professional final appearance

### How to Add Logo

#### Step 1: Prepare Logo Files

You need **3 sizes** of your logo (icon only, no text):

| Size | Resolution | Filename | Use |
|------|------------|----------|-----|
| @1x | 120 x 120 px | `logo-120.png` | Standard displays |
| @2x | 240 x 240 px | `logo-240.png` | Retina displays |
| @3x | 360 x 360 px | `logo-360.png` | High-res displays |

**Requirements:**
- **Format:** PNG
- **Content:** Just the icon (rounded square with "Z" symbol)
- **No text:** Don't include "Zenovaa" or "CONNECT" (splash screen adds those)
- **Background:** Transparent or solid (your choice)

#### Step 2: Extract Logo from Brand Image

If you have your brand image:

1. **Open in image editor:**
   - macOS: Preview, Photoshop, Figma
   - Online: Canva.com, Photopea.com, ResizeImage.net

2. **Crop to icon:**
   - Select only the rounded square icon with "Z"
   - Do NOT include text below the icon

3. **Make square:**
   - Ensure width = height (e.g., 360x360)

4. **Export 3 sizes:**
   - 360x360 → `logo-360.png`
   - 240x240 → `logo-240.png`
   - 120x120 → `logo-120.png`

**Quick method:**
1. Upload full-size logo to [resizeimage.net](https://resizeimage.net)
2. Crop to square
3. Resize to 360x360, download
4. Repeat for 240x240 and 120x120

#### Step 3: Add to Xcode

1. **Open Xcode project**

2. **Find Assets.xcassets:**
   - Project Navigator (left sidebar)
   - Click `Assets.xcassets`

3. **Create Image Set:**
   - Click **+** button (bottom left)
   - Select **"New Image Set"**

4. **Rename to `ZenovaaLogo`:**
   - Select the new image set
   - Right panel > Attributes Inspector
   - Change name to: **`ZenovaaLogo`** (exact spelling, case-sensitive!)

5. **Add images:**
   - Drag `logo-120.png` to **1x** slot
   - Drag `logo-240.png` to **2x** slot
   - Drag `logo-360.png` to **3x** slot

6. **Build and run:**
   ```bash
   Cmd + Shift + K  # Clean
   Cmd + B          # Build
   Cmd + R          # Run
   ```

#### Step 4: Verify

**Splash screen should show:**
- ✅ Your Zenovaa logo icon
- ✅ "Zenovaa" text below (48pt serif)
- ✅ "CONNECT" text (24pt, letter-spaced)
- ✅ Blue gradient background
- ✅ No console errors

---

## 📱 App Icon

### What You Need

App icons appear on the home screen and in various system locations. You need multiple sizes:

#### Required iOS App Icon Sizes

| Size | Resolution | Use |
|------|------------|-----|
| App Store | 1024x1024 | App Store listing |
| iPhone 3x | 180x180 | iPhone home screen |
| iPhone 2x | 120x120 | iPhone home screen (older) |
| iPad Pro | 167x167 | iPad Pro home screen |
| iPad 2x | 152x152 | iPad home screen |
| iPad 1x | 76x76 | iPad home screen (older) |
| Spotlight 3x | 120x120 | iPhone search |
| Spotlight 2x | 80x80 | iPad search |
| Settings 3x | 87x87 | iPhone settings |
| Settings 2x | 58x58 | iPad settings |
| Notification 3x | 60x60 | Notifications |
| Notification 2x | 40x40 | Notifications |

**Don't panic!** Use a tool to generate all sizes automatically.

### Easy Method: Use Online Tool

#### Option 1: AppIcon.co (Recommended)

1. **Create 1024x1024 master icon:**
   - Export your logo icon at 1024x1024
   - Should be square, no transparency (iOS requirement)
   - Solid background or fill with color

2. **Go to [AppIcon.co](https://appicon.co)**

3. **Upload your 1024x1024 image**

4. **Select "iOS"**

5. **Click "Generate"**

6. **Download ZIP file**

7. **In Xcode:**
   - Open `Assets.xcassets`
   - Click `AppIcon`
   - Drag each icon from ZIP into the corresponding slot

8. **Build and run:**
   - Delete app from device (to clear cache)
   - Clean: `Cmd + Shift + K`
   - Build: `Cmd + B`
   - Run: `Cmd + R`

9. **Check home screen:**
   - Your icon should appear on device home screen

#### Option 2: MakeAppIcon.com

Similar to AppIcon.co:
1. Upload 1024x1024 master
2. Download generated sizes
3. Add to Xcode `AppIcon` in Assets.xcassets

### Manual Method (Advanced)

If you prefer to create each size manually:

1. **Open Xcode > Assets.xcassets > AppIcon**
2. **For each empty slot:**
   - Note the required size (shown in slot)
   - Export icon at that size
   - Drag into slot
3. **Ensure all slots filled**

---

## 🎯 Visual Checklist

### Splash Screen Logo

- [ ] Logo extracted from brand image
- [ ] 3 sizes created (120px, 240px, 360px)
- [ ] Image set created in Assets.xcassets
- [ ] Named exactly `ZenovaaLogo`
- [ ] All 3 images added (@1x, @2x, @3x)
- [ ] App rebuilt
- [ ] Logo appears on splash screen
- [ ] No console errors

### App Icon

- [ ] 1024x1024 master icon created
- [ ] Used AppIcon.co or similar to generate sizes
- [ ] All icons added to AppIcon in Assets.xcassets
- [ ] App deleted from device
- [ ] App rebuilt and reinstalled
- [ ] Icon appears on home screen

---

## 🔧 Troubleshooting

### Logo Not Appearing

**Issue:** Still seeing placeholder icon

**Check:**
1. Image set named **exactly** `ZenovaaLogo` (case-sensitive)
2. Images added to correct slots (@1x, @2x, @3x)
3. Clean build performed
4. App fully rebuilt

**Solution:**
```bash
# In Xcode
Cmd + Shift + K  # Clean
Cmd + B          # Build
Cmd + R          # Run
```

---

### Logo Looks Blurry

**Issue:** Logo appears pixelated or blurry

**Causes:**
- Missing one or more size variants
- Using JPEG instead of PNG
- Low-quality source image

**Solution:**
1. Ensure all 3 sizes added (@1x, @2x, @3x)
2. Use PNG format
3. Use high-quality source (don't upscale small images)

---

### App Icon Not Updating

**Issue:** Old icon still showing on home screen

**Causes:**
- iOS caches icons aggressively
- App not deleted before reinstall

**Solution:**
```bash
1. Delete app from device
2. Clean build: Cmd + Shift + K
3. Rebuild: Cmd + B
4. Reinstall: Cmd + R
5. Wait 10 seconds
6. Check home screen
```

---

### "Image set not found" Error

**Issue:** Console shows image not found

**Check:**
- Spelling of image set name
- Assets.xcassets included in build target
- Image set in correct location (not inside AppIcon)

---

## 📊 Before vs After

### Splash Screen

**Before (Placeholder):**
```
╔═══════════════════════╗
║ Blue Gradient         ║
║   ┌───────────┐       ║
║   │    💧     │       ║ ← SF Symbol placeholder
║   └───────────┘       ║
║     Zenovaa           ║
║   C O N N E C T       ║
╚═══════════════════════╝
```

**After (With Logo):**
```
╔═══════════════════════╗
║ Blue Gradient         ║
║   ┌───────────┐       ║
║   │     Z     │       ║ ← Your actual logo
║   └───────────┘       ║
║     Zenovaa           ║
║   C O N N E C T       ║
╚═══════════════════════╝
```

### App Icon

**Before:**
- Default Xcode placeholder (often blank or generic)
- Unprofessional appearance

**After:**
- Your Zenovaa brand icon
- Professional appearance
- Instant brand recognition

---

## 🎨 Design Tips

### Logo Requirements

**Do:**
- ✅ Use high-quality source images
- ✅ Keep design simple and recognizable
- ✅ Ensure good contrast with background
- ✅ Test on different screen sizes
- ✅ Use PNG format for transparency

**Don't:**
- ❌ Include text in app icon (illegible at small sizes)
- ❌ Use gradients that don't work at small sizes
- ❌ Use transparency in app icon (iOS requirement)
- ❌ Upscale small images (will look blurry)

### Color Scheme

Your Zenovaa brand colors (for reference):
- **Deep Blue:** `#3869D2` / `rgb(56, 105, 210)`
- **Cyan Blue:** `#4FB6ED` / `rgb(79, 182, 237)`
- **Light Accent:** `#B2E6FF` / `rgb(178, 230, 255)`

---

## 📱 Testing on Device

1. **Build and install** on physical device
2. **Check home screen** for app icon
3. **Open app** to see splash screen
4. **Take screenshots** for comparison
5. **Verify** on different device sizes (iPhone, iPad)

---

## 📚 Related Documentation

- [Getting Started](getting-started.md) - Initial project setup
- [Info.plist Configuration](info-plist-configuration.md) - Required permissions
- [Troubleshooting](../development/troubleshooting.md) - Common issues

---

## 🎯 Priority

**Current Priority:** 🟡 Low-Medium

**Why it's optional:**
- ✅ App works perfectly without assets
- ✅ Placeholder looks professional
- ⏳ Add when polishing for release

**When to add:**
- Before App Store submission
- Before client demos
- Before production deployment
- When you have 15 minutes

**More urgent:**
1. 🔴 Info.plist configuration (required for WiFi)
2. 🟡 Assets setup (this guide)
3. 🟢 App polish and refinements

---

**Next:** [Troubleshooting Guide](../development/troubleshooting.md) →
