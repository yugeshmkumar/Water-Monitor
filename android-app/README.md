# Android App — Phase 2 (Future)

**Status:** Planned for Phase 2; currently out of scope.

## Overview

This directory is reserved for the Android implementation of the Water Monitor app. Phase 1 focuses exclusively on iOS + Firmware (see [CLAUDE.md](/CLAUDE.md)).

## Phase 1 Scope (Current)

- Firmware: Seeed XIAO ESP32-C6 sensor unit ✅
- iOS App: Full device management, calibration, history, cloud sync ✅
- Cloud: AWS backend (SQS, DynamoDB, Lambda) — Phase 2A

## Phase 2 Scope (Future)

- **Android App**: Jetpack Compose UI, same feature set as iOS
- **Architectural Notes**:
  - BLE: Android 12+ using Bluetooth Low Energy APIs
  - WiFi: Same REST + WebSocket as iOS
  - Storage: Room (SQLite ORM), not SwiftData
  - Cloud Sync: Same SQS/DynamoDB backend via AWS SDKs
  - Auth: Cognito integration via AWS Amplify for Android

## Implementation Plan

1. **Architecture** — Decide between Jetpack Compose (recommended) vs XML layouts
2. **Models** — Mirror iOS data models (Device, Tank, Reading, etc.)
3. **Services** — Replicate BLEService, WiFiService, DataCache for Android
4. **UI Layers** — Dashboard, History, Settings, Device Discovery, Calibration
5. **Testing** — Unit tests + instrumented tests for BLE/WiFi
6. **Cloud** — Integrate AWS SDK; share backend with iOS app

## Why Phase 2?

- iOS app has proven UX and feature completeness
- Firmware stability established through iOS testing
- AWS backend decoupled from platform; easier to reuse

## Getting Started (When Phase 2 Begins)

1. Create Android Studio project (`build.gradle`, dependencies)
2. Set up Jetpack Compose scaffold + navigation
3. Implement BluetoothManager (Android equivalent of BLEService)
4. Port DataCache via Room ORM
5. Integrate Cognito via `aws-android-sdk-cognitoidentityprovider`
