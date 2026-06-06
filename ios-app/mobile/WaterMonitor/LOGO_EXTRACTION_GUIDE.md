# Quick Guide: Extracting Logo from Brand Image

## What You Need to Extract

From your brand image, you need to extract **two different assets**:

### 1. App Icon (Icon Only)
```
┌─────────────────┐
│                 │
│   [Z symbol]    │  ← Just this rounded square icon
│  with gradient  │     NO text below
│                 │
└─────────────────┘
```
- **Format**: Square (1:1 aspect ratio)
- **Recommended size**: 1024x1024 pixels
- **Content**: Just the blue rounded square with the "Z" connection symbol
- **Background**: Keep the gradient blue background

### 2. Splash Screen Logo (Icon Only, Same as Above)
- Same as the app icon
- Will be displayed at 120x120 points on the splash screen
- Needs @1x, @2x, @3x versions (120px, 240px, 360px)

## Extraction Methods

### Method 1: Using Online Tools (Easiest)
1. Go to [remove.bg](https://remove.bg) or similar
2. Upload your brand image
3. Download the icon only (crop to just the square icon)
4. Resize to 1024x1024 using [resizeimage.net](https://resizeimage.net)
5. Generate icon sizes using [appicon.co](https://appicon.co)

### Method 2: Using Figma (Free)
1. Create a Figma account (free)
2. Upload your brand image
3. Use the crop tool to select just the icon portion
4. Export as PNG at 1024x1024
5. Create additional exports at 120px, 240px, 360px for splash logo

### Method 3: Using Preview (macOS)
1. Open your brand image in Preview
2. Select the icon area using the "Rectangular Selection" tool
3. `Cmd + K` to crop to selection
4. `Tools > Adjust Size...` to resize to 1024x1024
5. Save as PNG
6. Repeat for smaller sizes (120px, 240px, 360px)

### Method 4: Using Photoshop/GIMP
1. Open the brand image
2. Use the Crop tool to select just the icon
3. `Image > Image Size` to resize to 1024x1024
4. Save for Web as PNG
5. Create additional sizes as needed

## What NOT to Include

❌ **DO NOT include in the app icon:**
- The "Zenovaa" text below the icon
- The "CONNECT" text
- Any white space around the icon
- A transparent background (keep the blue gradient)

✅ **DO include:**
- Just the rounded square icon
- The "Z" connection symbol with circles
- The blue gradient background (dark blue to cyan)

## File Naming Convention

Once you have the extracted images:

### For App Icon (via appicon.co):
- Let the tool generate all sizes automatically
- It will create a folder with all required sizes

### For Splash Logo (manual):
**Name them clearly before adding to Xcode:**
- `zenovaa-logo-120.png` (for @1x)
- `zenovaa-logo-240.png` (for @2x)
- `zenovaa-logo-360.png` (for @3x)

**Then in Xcode, add them to an image set named:** `ZenovaaLogo`

## Verification Checklist

Before proceeding to Xcode:

- [ ] Icon is perfectly square (1:1 aspect ratio)
- [ ] Icon contains only the "Z" symbol in the rounded square
- [ ] No text is included
- [ ] Blue gradient background is preserved
- [ ] Image is high quality (no pixelation)
- [ ] File is saved as PNG
- [ ] You have a 1024x1024 version for the app icon
- [ ] You have 120px, 240px, 360px versions for the splash logo

## Next Steps

Once you have the extracted assets:
1. Follow the "APP_ICON_AND_SPLASH_SETUP.md" guide
2. Add the app icon to Assets.xcassets > AppIcon
3. Create a new image set "ZenovaaLogo" and add the splash logo
4. Build and test your app

---

**The splash screen will automatically combine:**
- The logo icon you provide (from image set)
- The "Zenovaa" text (rendered programmatically)
- The "CONNECT" text (rendered programmatically)
- The gradient background (rendered programmatically)

**So you only need to provide the icon itself!**
