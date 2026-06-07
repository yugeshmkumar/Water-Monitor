# 📁 Project Structure Guide

## Recommended Folder Organization

```
WaterMonitor/
├── WaterMonitor/                    # Main app target
│   ├── App/                         # App lifecycle
│   │   ├── WaterMonitorApp.swift
│   │   └── Info.plist
│   │
│   ├── Models/                      # Data models
│   │   ├── DeviceConfig.swift
│   │   ├── DeviceStatus.swift
│   │   ├── DeviceReading.swift
│   │   └── SavedDevice.swift
│   │
│   ├── Services/                    # Business logic & networking
│   │   ├── Connection/
│   │   │   ├── ConnectionManager.swift
│   │   │   ├── DeviceService.swift (protocol)
│   │   │   ├── WiFiService.swift
│   │   │   └── BLEService.swift
│   │   ├── Health/
│   │   │   └── HealthMonitor.swift
│   │   ├── Background/
│   │   │   └── BackgroundTaskManager.swift
│   │   ├── Data/
│   │   │   ├── DataCache.swift
│   │   │   └── DatabaseMigration.swift
│   │   └── Notifications/
│   │       └── NotificationService.swift
│   │
│   ├── Views/                       # SwiftUI views
│   │   ├── Main/
│   │   │   ├── ContentView.swift
│   │   │   ├── MainAppView.swift
│   │   │   └── WelcomeView.swift
│   │   ├── Device/
│   │   │   ├── DeviceDetailView.swift
│   │   │   ├── DeviceConfigView.swift
│   │   │   ├── AddDeviceView.swift
│   │   │   └── DeviceHealthCheckView.swift
│   │   ├── Calibration/
│   │   │   └── TankCalibrationView.swift
│   │   ├── Analytics/
│   │   │   ├── HistoryView.swift
│   │   │   └── InsightsView.swift
│   │   ├── Settings/
│   │   │   └── AppSettingsView.swift
│   │   └── Components/
│   │       └── ErrorBanner.swift (to be added)
│   │
│   ├── Utilities/                   # Helpers & extensions
│   │   ├── Constants.swift
│   │   ├── AppError.swift
│   │   └── Extensions/
│   │       ├── View+Extensions.swift
│   │       └── Font+Extensions.swift
│   │
│   └── Resources/                   # Assets, colors, etc.
│       ├── Assets.xcassets
│       └── Localizable.strings
│
├── WaterMonitorTests/               # Unit tests
│   ├── ConnectionManagerTests.swift
│   ├── HealthMonitorTests.swift
│   └── DatabaseMigrationTests.swift
│
├── WaterMonitorUITests/             # UI tests
│   └── WaterMonitorUITests.swift
│
└── Documentation/                   # Project documentation
    ├── README.md
    ├── ARCHITECTURE.md
    ├── DEPLOYMENT.md
    ├── API.md
    └── Assets/
        └── diagrams/
```

## How to Organize Your Files

### 1. Move Implementation Files

**In Xcode:**
1. Create Groups (not folders): Right-click project → New Group
2. Create this structure:
   ```
   WaterMonitor
   ├── Services
   │   ├── Connection
   │   ├── Health
   │   ├── Background
   │   ├── Data
   │   └── Notifications
   ├── Views
   │   ├── Main
   │   ├── Device
   │   ├── Calibration
   │   ├── Analytics
   │   └── Settings
   ├── Utilities
   └── Resources
   ```

3. Drag files into appropriate groups:
   - ConnectionManager.swift → Services/Connection
   - HealthMonitor.swift → Services/Health
   - Constants.swift → Utilities
   - etc.

### 2. Move Documentation Files

**In Finder** (not Xcode):
1. Create `Documentation` folder at project root (same level as .xcodeproj)
2. Move these files there:
   - README.md
   - INDEX.md
   - QUICK_START.md
   - DEPLOYMENT_CHECKLIST.md
   - SUMMARY.md
   - ARCHITECTURE.md
   - IMPLEMENTATION_GUIDE.md
   - CHANGELOG.md
   - ACTION_ITEMS.md

**DO NOT add documentation to Xcode target** - they're reference only

### 3. Update Import Statements

After moving files, you may need to update imports. Since all files are in the same target, imports should still work.

## Best Practices

### ✅ DO
- Group related files together
- Use nested groups for clarity
- Keep documentation outside Xcode project
- Follow Apple's conventions (Models, Views, Services)

### ❌ DON'T
- Mix view code with business logic
- Put documentation in app target
- Create flat file structure
- Use filesystem folders instead of Xcode groups (unless needed)

## Documentation Location

```
project-root/
├── WaterMonitor.xcodeproj
├── WaterMonitor/              # Source code
└── Documentation/             # All .md files go here
    ├── README.md
    ├── Guides/
    │   ├── QUICK_START.md
    │   ├── DEPLOYMENT_CHECKLIST.md
    │   └── ACTION_ITEMS.md
    ├── Architecture/
    │   ├── ARCHITECTURE.md
    │   └── IMPLEMENTATION_GUIDE.md
    └── Reference/
        ├── SUMMARY.md
        ├── CHANGELOG.md
        └── INDEX.md
```

This keeps documentation separate from code while maintaining clear organization.
