# 📱 In-App Alerts - Quick Reference

## 🎯 What You Get
✅ Modal alert dialogs when app is open  
✅ Motor controller tips when not attached  
✅ Smart cooldown (30s critical, 1min others)  
✅ Works alongside system notifications  

## 🔔 Alert Types

### 🚨 Critical (≤5%)
```
Title: 🚨 CRITICAL - Tank Nearly Empty
Cooldown: 30 seconds
Tip: "Connect motor controller to automate filling"
```

### ⚠️ Low (≤15%)
```
Title: ⚠️ Tank Low
Cooldown: 1 minute
Tip: "Connect motor controller to automate filling"
```

### 💧 Full (100%)
```
Title: 💧 Tank Full
Cooldown: 1 minute
Tip: "Connect motor controller to prevent overflow"
Buttons: [OK] [View Tank]
```

### ✅ Nearly Full (≥95%)
```
Title: ✅ Tank Nearly Full
Cooldown: 1 minute
Tip: "Connect motor controller to prevent overflow"
Buttons: [OK] [View Tank]
```

## 📊 Behavior

### State Changes = Immediate Alert
```
50% → 96% → 📱 Alert (state changed!)
96% → 100% → 📱 Alert (state changed!)
100% → 94% → 📱 Alert (state changed!)
```

### Same State = Cooldown
```
0:00 → 100% → 📱 Alert #1
0:30 → 100% → ⏸️ Skip (cooldown)
1:00 → 100% → 📱 Alert #2
```

## 🧪 Quick Test
```bash
1. Build & Run (Cmd+R)
2. Keep app in foreground
3. Fill tank to 100%
4. Watch for modal alert
5. Check console: [InAppAlert] 📱 Showing alert: ...
```

## 🔍 Key Files
- `InAppAlertManager.swift` - Alert logic
- `NotificationService.swift` - Integration
- `WaterMonitorApp.swift` - UI attachment
- `IN_APP_ALERTS.md` - Full docs
