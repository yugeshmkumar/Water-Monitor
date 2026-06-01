# Water Monitor - Complete Project Structure

## Overview
This document defines the canonical file structure for the Water Monitor project, following iOS best practices and the architecture defined in `docs/architecture/ARCHITECTURE.md`.

---

## Root Structure

```
Water-Monitor/
├── docs/                           # All documentation
│   ├── architecture/               # Architecture & requirements docs
│   │   ├── ARCHITECTURE.md         # Main architecture document (canonical)
│   │   ├── REQUIREMENTS.md         # Phase 2 requirements
│   │   ├── IMPLEMENTATION_TODO.md  # Phase 2A/2B/2C tasks
│   │   └── CLOUD_PERFORMANCE_ANALYSIS.md
│   │
│   ├── api/                        # API specifications
│   │   ├── PHASE_2A_AWS_IMPLEMENTATION.md
│   │   └── PHASE_2A_AWS_IMPLEMENTATION_REVISED.md
│   │
│   └── guides/                     # Development & deployment guides
│       ├── ios/                    # iOS app-specific guides
│       │   ├── DEPLOYMENT_CHECKLIST.md
│       │   ├── IMPLEMENTATION_GUIDE.md
│       │   ├── QUICK_START.md
│       │   ├── SUMMARY.md
│       │   ├── STATUS_CHECK.md
│       │   ├── POST_CRASH_STATUS.md
│       │   └── INDEX.md
│       │
│       └── firmware/               # Firmware-specific guides
│           └── (future)
│
├── firmware/                       # ESP32 firmware
│   └── tank-sensor/
│       ├── platformio.ini
│       ├── partitions.csv
│       └── src/
│           ├── main.cpp
│           ├── state.h
│           ├── pins.h
│           ├── config.h/.cpp
│           ├── sensor.h/.cpp
│           ├── queue_store.h/.cpp
│           ├── ble_server.h/.cpp
│           └── api_server.h/.cpp
│
└── ios-app/                        # iOS application
    └── mobile/
        └── WaterMonitor/
            ├── WaterMonitorApp.swift       # App entry point
            ├── ContentView.swift           # Root view coordinator
            │
            ├── Models/                     # SwiftData models & Codable structs
            │   ├── DeviceReading.swift
            │   ├── DeviceConfig.swift
            │   ├── DeviceStatus.swift
            │   ├── SavedDevice.swift
            │   ├── Tank.swift
            │   └── MotorGroup.swift
            │
            ├── Services/                   # Backend services (networking, BLE, data)
            │   ├── BLEService.swift
            │   ├── WiFiService.swift
            │   ├── ConnectionManager.swift
            │   ├── DataCache.swift
            │   ├── DeviceService.swift     # Protocol
            │   ├── HealthMonitor.swift
            │   ├── BackgroundTaskManager.swift
            │   ├── DatabaseMigration.swift
            │   ├── NotificationService.swift
            │   ├── Constants.swift
            │   └── AppError.swift
            │
            ├── ViewModels/                 # (Future - if needed)
            │   └── (currently views manage their own state)
            │
            └── Views/                      # SwiftUI views
                ├── WelcomeView.swift
                ├── MainAppView.swift
                ├── DevicesHubView.swift
                ├── DeviceCardView.swift
                ├── DeviceDetailView.swift
                ├── AddDeviceView.swift
                ├── AppSettingsView.swift
                ├── HistoryView.swift
                ├── InsightsView.swift
                ├── ConfigWizardView.swift
                ├── TankCalibrationView.swift
                ├── DeviceConfigView.swift
                ├── DeviceHealthCheckView.swift
                ├── DashboardView.swift     # Legacy (reference)
                └── ScanView.swift          # Legacy (reference)
```

---

## File Categorization Rules

### Documentation (`/docs/`)
**Rule**: All `.md` files except README.md go in `/docs/`

- **Architecture docs** (`/docs/architecture/`):
  - System architecture
  - Requirements specifications
  - Implementation roadmaps
  
- **API docs** (`/docs/api/`):
  - REST API specifications
  - WebSocket protocols
  - BLE GATT definitions
  
- **Guides** (`/docs/guides/`):
  - Development guides
  - Deployment procedures
  - Testing checklists
  - Status reports

### iOS App (`/ios-app/mobile/WaterMonitor/`)
**Rule**: Only Swift source files, Info.plist, Assets, and Xcode project files

- **Models/**: `@Model` classes (SwiftData) and `Codable` structs
- **Services/**: Business logic, networking, device communication
- **Views/**: SwiftUI view files only
- **ViewModels/**: (Reserved for future MVVM if needed)

### Firmware (`/firmware/tank-sensor/`)
**Rule**: PlatformIO project structure

- **src/**: C++ source files (.cpp, .h)
- **platformio.ini**: Build configuration
- **partitions.csv**: ESP32 partition table

---

## Current File Locations (INCORRECT - Need to Move)

These files are currently in the wrong location and need to be moved:

### Currently in `/repo/` (root) - Should be in `/docs/guides/ios/`:
- ✗ `DEPLOYMENT_CHECKLIST.md`
- ✗ `IMPLEMENTATION_GUIDE.md`
- ✗ `INDEX.md`
- ✗ `POST_CRASH_STATUS.md`
- ✗ `QUICK_START.md`
- ✗ `STATUS_CHECK.md`
- ✗ `SUMMARY.md`
- ✗ `DocumentationPROJECT_STRUCTURE.md`

### Currently in `/repo/` - Should be in `/ios-app/mobile/WaterMonitor/Services/`:
- ✓ `AppError.swift` (already correct conceptually, just in wrong folder view)
- ✓ `BackgroundTaskManager.swift`
- ✓ `Constants.swift`
- ✓ `DatabaseMigration.swift`
- ✓ `DeviceService.swift`
- ✓ `HealthMonitor.swift`

### Currently in `/repo/` - Should be in `/ios-app/mobile/WaterMonitor/Models/`:
- ✓ `DeviceConfig.swift`
- ✓ `Tank.swift`

### Currently in `/repo/` - Should be in `/ios-app/mobile/WaterMonitor/Views/`:
- ✓ `AddDeviceView.swift`
- ✓ `AppSettingsView.swift`
- ✓ `DashboardView.swift`
- ✓ `DeviceConfigView.swift`
- ✓ `DeviceDetailView.swift`
- ✓ `DeviceHealthCheckView.swift`
- ✓ `DevicesHubViewMulti.swift`
- ✓ `HistoryView.swift`
- ✓ `InsightsView.swift`
- ✓ `MainAppView.swift`
- ✓ `TankCalibrationView.swift`
- ✓ `WelcomeView.swift`

### Currently in `/repo/` - Should be in `/ios-app/mobile/WaterMonitor/Services/`:
- ✓ `BLEService.swift`
- ✓ `ConnectionManager.swift`
- ✓ `NotificationService.swift`
- ✓ `WiFiService.swift`

### Currently in `/repo/` - Root level (correct):
- ✓ `WaterMonitorApp.swift`
- ✓ `ContentView.swift`

---

## Naming Conventions

### Swift Files
- **Format**: PascalCase
- **Examples**: `BLEService.swift`, `DeviceDetailView.swift`, `SavedDevice.swift`
- **Rule**: One primary type per file, filename matches type name

### Documentation Files
- **Format**: SCREAMING_SNAKE_CASE.md
- **Examples**: `DEPLOYMENT_CHECKLIST.md`, `ARCHITECTURE.md`
- **Exception**: README.md (standard convention)

### Folders
- **Format**: lowercase or PascalCase (iOS convention)
- **Examples**: `Models/`, `Services/`, `Views/`, `docs/`, `architecture/`

---

## File Organization by Type

### Models (SwiftData & Codable)
```swift
// @Model classes (SwiftData persistence)
SavedDevice.swift
DeviceReading.swift
Tank.swift
MotorGroup.swift

// Codable structs (firmware protocol)
DeviceConfig.swift      // Mirrors NVS config exactly
DeviceStatus.swift      // Live state from AA01+AA02 or /api/status
```

### Services (Business Logic)
```swift
// Device Communication
BLEService.swift              // CoreBluetooth GATT
WiFiService.swift             // URLSession REST + WebSocket
ConnectionManager.swift        // Transport coordinator
DeviceService.swift           // Protocol

// Data & State
DataCache.swift               // SwiftData queries
HealthMonitor.swift           // Adaptive polling
BackgroundTaskManager.swift   // iOS BackgroundTasks

// Utilities
DatabaseMigration.swift       // Migration & recovery
NotificationService.swift     // Local notifications
Constants.swift               // Centralized config
AppError.swift                // Error types
```

### Views (SwiftUI)
```swift
// Navigation
MainAppView.swift             // TabView root
WelcomeView.swift             // First launch
ContentView.swift             // App state router

// Device Management
DevicesHubView.swift          // Multi-device list
DeviceCardView.swift          // Device summary card
DeviceDetailView.swift        // Full device dashboard
AddDeviceView.swift           // Device onboarding
DeviceHealthCheckView.swift   // Diagnostics

// Configuration
ConfigWizardView.swift        // 3-step setup
DeviceConfigView.swift        // Settings editor
TankCalibrationView.swift     // Calibration UI

// Data Views
HistoryView.swift             // Swift Charts
InsightsView.swift            // AI analytics
AppSettingsView.swift         // App settings

// Legacy (Reference)
DashboardView.swift           // Original single-device view
ScanView.swift                // Original BLE scan
```

---

## README Files

Each major directory should have a README:

```
/README.md                              # Project overview
/docs/README.md                         # Documentation index
/docs/guides/ios/README.md              # iOS guides index
/firmware/README.md                     # Firmware overview
/ios-app/README.md                      # iOS app overview
```

---

## Xcode Project Structure

In Xcode, groups should mirror the filesystem:

```
WaterMonitor (Xcode Project)
├── WaterMonitor (Target)
│   ├── App
│   │   ├── WaterMonitorApp.swift
│   │   └── ContentView.swift
│   │
│   ├── Models
│   │   ├── DeviceReading.swift
│   │   ├── DeviceConfig.swift
│   │   ├── DeviceStatus.swift
│   │   ├── SavedDevice.swift
│   │   ├── Tank.swift
│   │   └── MotorGroup.swift
│   │
│   ├── Services
│   │   ├── BLEService.swift
│   │   ├── WiFiService.swift
│   │   ├── ConnectionManager.swift
│   │   ├── DataCache.swift
│   │   ├── DeviceService.swift
│   │   ├── HealthMonitor.swift
│   │   ├── BackgroundTaskManager.swift
│   │   ├── DatabaseMigration.swift
│   │   ├── NotificationService.swift
│   │   ├── Constants.swift
│   │   └── AppError.swift
│   │
│   └── Views
│       ├── (all view files)
│
├── Assets.xcassets
├── Info.plist
└── WaterMonitor.entitlements
```

**Rule**: Xcode groups should reference actual folders on disk, not virtual groups.

---

## Migration Checklist

To fix current structure:

- [ ] Create `/docs/guides/ios/` folder
- [ ] Move all `.md` files from `/repo/` to `/docs/guides/ios/`
- [ ] Verify all Swift files are in correct folders
- [ ] Update Xcode project groups to match filesystem
- [ ] Create README files for each major directory
- [ ] Verify Info.plist is in correct location
- [ ] Test build after migration

---

## Summary

**Simple Rule**:
- **Documentation** → `/docs/`
- **Swift code** → `/ios-app/mobile/WaterMonitor/`
- **Firmware** → `/firmware/tank-sensor/`

**Within iOS app**:
- **Models/** = Data structures
- **Services/** = Business logic & networking
- **Views/** = SwiftUI components

This structure follows:
- ✅ iOS community standards
- ✅ SwiftUI best practices
- ✅ Xcode conventions
- ✅ Your architecture.md specifications

