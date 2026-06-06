# App Icon and Splash Screen Setup Guide

## Overview
This guide will help you update the Zenovaa CONNECT app with the new branding, including the app icon and splash screen.

## ✅ Completed
- Updated `ContentView.swift` splash screen with Zenovaa CONNECT branding
- Added gradient background matching the logo colors
- Updated typography to match the brand identity

## 📋 Next Steps: Adding Assets to Xcode

### 1. Extract the Logo from Your Image

From the image you provided, you need to extract just the icon portion (the "Z" symbol with the gradient blue background). The icon should be:
- Square format (1024x1024px recommended)
- Just the rounded square icon with the "Z" symbol
- No text below it

### 2. Create App Icon Assets

You'll need to create multiple sizes for the app icon. Here are the required sizes for iOS:

#### App Icon Sizes (iOS):
- **1024x1024** - App Store
- **180x180** - iPhone (3x)
- **120x120** - iPhone (2x)
- **167x167** - iPad Pro
- **152x152** - iPad (2x)
- **76x76** - iPad (1x)
- **60x60** - iPhone Notification (3x)
- **40x40** - iPhone Spotlight (2x)
- **58x58** - iPhone Settings (2x)
- **87x87** - iPhone Settings (3x)
- **80x80** - iPad Spotlight (2x)
- **29x29** - iPad Settings (1x)

**Tools to Generate Icon Sizes:**
- Use online tools like [appicon.co](https://appicon.co) or [makeappicon.com](https://makeappicon.com)
- Or use a design tool like Figma, Sketch, or Photoshop to export all sizes

### 3. Add App Icon to Xcode

1. Open your Xcode project
2. In the **Project Navigator** (left sidebar), locate your **Assets.xcassets** folder
3. Click on **AppIcon** inside Assets.xcassets
4. Drag and drop each icon size into the appropriate slot
5. Ensure the 1024x1024 icon is placed in the "App Store iOS" slot

### 4. Add Logo Asset for Splash Screen

The splash screen code now references `Image("ZenovaaLogo")`. You need to add this asset:

1. In **Assets.xcassets**, click the **+** button at the bottom
2. Select **New Image Set**
3. Name it **"ZenovaaLogo"**
4. Add three sizes of your logo (just the icon, no text):
   - **1x**: 120x120 pixels
   - **2x**: 240x240 pixels  
   - **3x**: 360x360 pixels

**Note:** The logo should be the icon only (the rounded square with the "Z"), extracted from your brand image. It should have a transparent background or the gradient background built in.

### 5. Update Launch Screen (Optional)

If your app has a `LaunchScreen.storyboard` or `Launch Screen.storyboard`:

1. Open the storyboard file in Xcode
2. Add an Image View to the center
3. Set the image to "ZenovaaLogo"
4. Add appropriate constraints to center it
5. Optionally add a label below with "Zenovaa CONNECT"

**Note:** The programmatic splash screen in `ContentView.swift` will show immediately after the launch screen, providing a smooth transition.

## 🎨 Design Specifications

### Color Palette (from your logo)
- **Deep Blue**: `#3869D2` or `rgb(56, 105, 210)`
- **Cyan Blue**: `#4FB6ED` or `rgb(79, 182, 237)`
- **Light Accent**: `#B3E5FC` (used for "CONNECT" text)
- **White**: `#FFFFFF` (for "Zenovaa" text)

### Typography
- **Company Name (Zenovaa)**: Serif font, 48pt, bold, white
- **Product Name (CONNECT)**: Sans-serif, 24pt, medium weight, letter spacing +8, light blue

### Gradient
- From deep blue (top-left) to cyan blue (bottom-right)
- Creates depth and matches the icon design

## 📱 Testing

After adding the assets:

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **Build**: `Cmd + B`
3. **Run on Simulator/Device**: `Cmd + R`
4. Check that:
   - App icon appears on the home screen
   - Splash screen shows the Zenovaa logo with gradient background
   - Text displays correctly: "Zenovaa" and "CONNECT"

## 🔧 Troubleshooting

### Issue: Image not found
- Ensure the image set is named exactly **"ZenovaaLogo"** (case-sensitive)
- Verify the image is in **Assets.xcassets**
- Clean and rebuild the project

### Issue: App icon not updating
- Delete the app from your device/simulator
- Clean build folder (`Cmd + Shift + K`)
- Rebuild and reinstall

### Issue: Splash screen looks wrong
- Check that you've added all three sizes (@1x, @2x, @3x)
- Verify the logo has the correct aspect ratio (square)
- Ensure the background is transparent or matches the gradient

## 📝 Files Modified

- ✅ `ContentView.swift` - Updated splash screen with new branding

## 🎯 Expected Result

When complete, your app will have:
1. **App Icon**: The Zenovaa "Z" logo icon on the home screen
2. **Splash Screen**: 
   - Beautiful blue gradient background
   - Zenovaa logo icon centered
   - "Zenovaa" in large serif font
   - "CONNECT" in spaced letters below
   - Professional, modern appearance

---

**Need Help?** If you encounter any issues, check that:
- All image assets are added to **Assets.xcassets**
- Image names match exactly what's in the code
- You've cleaned and rebuilt the project
