# 📖 Zenovaa CONNECT Documentation

Welcome to the Zenovaa CONNECT documentation! This guide will help you get started, understand the system, and troubleshoot issues.

## 🚀 Quick Start

**New to the project?** Start here:

1. **[Getting Started](setup/getting-started.md)** - First-time setup guide
2. **[Info.plist Configuration](setup/info-plist-configuration.md)** - Required permissions
3. **[Assets Setup](setup/assets-setup.md)** - App icon and branding

## 📚 Documentation Structure

```
docs/
├── README.md (this file)
├── setup/                          # Getting started guides
│   ├── getting-started.md          # Initial setup
│   ├── info-plist-configuration.md # Permissions setup
│   └── assets-setup.md             # Logo and app icon
├── development/                    # Development guides
│   ├── architecture.md             # System architecture
│   ├── troubleshooting.md          # Common issues and fixes
│   └── testing.md                  # Testing guide
├── features/                       # Feature documentation
│   ├── notifications.md            # Notification system
│   ├── in-app-alerts.md           # In-app alert dialogs
│   └── connectivity.md             # BLE and WiFi connection
└── reference/                      # Quick references
    └── changelog.md                # Version history
```

---

## 📖 Documentation by Category

### 🔧 Setup & Configuration

| Document | Description | When to Read |
|----------|-------------|--------------|
| [Getting Started](setup/getting-started.md) | First-time setup, Xcode project setup | **Start here** |
| [Info.plist Configuration](setup/info-plist-configuration.md) | Local network permissions (required) | Before testing WiFi |
| [Assets Setup](setup/assets-setup.md) | App icon and logo setup | When adding branding |

### 💻 Development

| Document | Description | When to Read |
|----------|-------------|--------------|
| [Architecture](development/architecture.md) | System design, data flow, components | Understanding the system |
| [Troubleshooting](development/troubleshooting.md) | Common issues and solutions | When things go wrong |
| [Testing](development/testing.md) | How to test features | Before deployment |

### ✨ Features

| Document | Description | When to Read |
|----------|-------------|--------------|
| [Notifications](features/notifications.md) | System notification guide | Setting up alerts |
| [In-App Alerts](features/in-app-alerts.md) | Modal alert dialogs | Customizing UX |
| [Connectivity](features/connectivity.md) | BLE and WiFi connection guide | Debugging connections |

### 📋 Reference

| Document | Description | When to Read |
|----------|-------------|--------------|
| [Changelog](reference/changelog.md) | Version history and fixes | Understanding changes |

---

## 🎯 Common Tasks

### "I want to set up the project for the first time"

1. Read [Getting Started](setup/getting-started.md)
2. Add [Info.plist permissions](setup/info-plist-configuration.md)
3. Add [assets](setup/assets-setup.md) (logo, app icon)
4. Build and run!

### "WiFi connections aren't working"

1. Check [Info.plist Configuration](setup/info-plist-configuration.md) is complete
2. See [Troubleshooting - WiFi Issues](development/troubleshooting.md#wifi-connection-issues)
3. Verify device is powered on and on same network

### "I want to understand the notification system"

1. Read [Notifications Feature Guide](features/notifications.md)
2. See [Architecture - Notification Flow](development/architecture.md#notification-system)
3. Test using [Testing Guide](development/testing.md#testing-notifications)

### "The app won't navigate after adding a device"

✅ **This is already fixed!** See [Changelog](reference/changelog.md#fix-4-app-navigation-after-adding-device)

### "I need to add the app logo"

1. See [Assets Setup](setup/assets-setup.md)
2. Extract logo from brand image (instructions included)
3. Add to `Assets.xcassets` as `ZenovaaLogo`

---

## ⚠️ Critical Information

### Required Configurations

Before the app will work properly, you **must**:

1. ✅ **Add local network permission** to Info.plist
   - See: [Info.plist Configuration](setup/info-plist-configuration.md)
   - Error without this: `-1009 Local network prohibited`

2. ⚠️ **Add logo assets** (optional but recommended)
   - See: [Assets Setup](setup/assets-setup.md)
   - App works without this (uses placeholder)

### Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| App Navigation | ✅ Fixed | Returns to home after adding device |
| WiFi Connectivity | ⚠️ Requires Info.plist | Add permission to work |
| Splash Screen | ✅ Updated | Shows Zenovaa CONNECT branding |
| Logo Asset | ⏳ Pending | Uses placeholder until added |
| Notifications | ✅ Working | System + in-app alerts |

---

## 🔍 Search by Topic

### Permissions
- [Local Network Permission](setup/info-plist-configuration.md)
- [Bluetooth Permission](setup/info-plist-configuration.md#bluetooth-permission)

### Connectivity
- [WiFi Connection](features/connectivity.md#wifi-connection)
- [BLE Connection](features/connectivity.md#ble-connection)
- [Troubleshooting Timeouts](development/troubleshooting.md#wifi-timeout-error-1001)

### Alerts
- [System Notifications](features/notifications.md)
- [In-App Alert Dialogs](features/in-app-alerts.md)
- [Alert Thresholds](development/architecture.md#alert-thresholds)

### Assets
- [App Icon](setup/assets-setup.md#app-icon-setup)
- [Splash Screen Logo](setup/assets-setup.md#splash-screen-logo)

---

## 📚 Additional Resources

### External Documentation
- [Apple: Local Network Privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
- [Apple: User Notifications](https://developer.apple.com/documentation/usernotifications)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)

### Project Resources
- **README.md** - Project overview
- **COMMIT_GUIDE.md** - Git commit guidelines

---

## 🎓 Learning Path

### For Developers

```
1. Setup Phase
   └→ Read: Getting Started
   └→ Complete: Info.plist configuration
   └→ Build and run

2. Understanding Phase
   └→ Read: Architecture
   └→ Explore: Feature guides
   └→ Review: Code structure

3. Development Phase
   └→ Use: Testing guide
   └→ Reference: Troubleshooting
   └→ Contribute: Follow commit guide
```

### For Testers

```
1. Setup
   └→ Install app on device
   └→ Grant permissions when prompted

2. Testing
   └→ Follow: Testing Guide
   └→ Report: Issues found
   └→ Verify: Fixes applied

3. Documentation
   └→ Check: Changelog for recent fixes
   └→ Refer: Troubleshooting for known issues
```

---

## 🆘 Need Help?

### Quick Troubleshooting

**App won't connect to devices:**
→ [Troubleshooting - Connectivity](development/troubleshooting.md#connectivity-issues)

**Notifications not appearing:**
→ [Troubleshooting - Notifications](development/troubleshooting.md#notification-issues)

**Build errors:**
→ [Getting Started - Troubleshooting](setup/getting-started.md#troubleshooting)

### Still Stuck?

1. Check the [Troubleshooting Guide](development/troubleshooting.md)
2. Review the [Changelog](reference/changelog.md) for recent fixes
3. Search the documentation for your specific error

---

## ✅ Documentation Checklist

Before deploying or demoing:

- [ ] Info.plist has local network permission
- [ ] Info.plist has Bluetooth permission
- [ ] Assets include app icon (all sizes)
- [ ] Assets include ZenovaaLogo (or app uses placeholder)
- [ ] Tested on physical device
- [ ] Permissions granted (Local Network, Bluetooth, Notifications)
- [ ] At least one device added successfully
- [ ] WiFi connection working
- [ ] Notifications tested

---

**Last Updated:** 2026-06-08  
**Documentation Version:** 2.0  
**App Version:** 1.0.1

---

## 🎉 Ready to Get Started?

Head over to **[Getting Started](setup/getting-started.md)** to begin! 🚀
