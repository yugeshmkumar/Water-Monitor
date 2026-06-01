# 📱 Notification System Quick Reference

## 🔥 Critical Alerts (≤5%)
```
Escalation: 0s → 30s → 1min → 2min → 5min (repeat)
Sound: Critical Alert (special)
Level: CRITICAL (breaks through ALL Focus/DND modes)
Message: "🚨 CRITICAL - Tank Nearly Empty"
```

## ⚠️ Important Alerts (Low/Full)
```
Escalation: 0s → 5min → 15min → 30min (repeat)
Sound: Default
Level: Time-Sensitive (bypasses some Focus modes)
Messages: 
  - "⚠️ Tank Low" (≤ alertLowPct)
  - "💧 Tank Full" (= 100%)
```

## 💡 Warning Alerts (Nearly Full)
```
Escalation: 0s → 5min → 15min → 30min (repeat)
Sound: Default
Level: Active (standard)
Message: "✅ Tank Full" (≥ alertHighPct, < 100%)
```

## 🎯 State Change Rule
**ANY state change = IMMEDIATE notification (count resets)**

## 📊 Example Timeline (Critical)
```
0:00  → Tank hits 3%     → 🔔 Alert #1
0:30  → Still 3%         → 🔔 Alert #2
1:30  → Still 3%         → 🔔 Alert #3
3:30  → Still 3%         → 🔔 Alert #4
8:30  → Still 3%         → 🔔 Alert #5
13:30 → Still 3%         → 🔔 Alert #6
...   → Every 5 minutes  → 🔔 Continues
```

## 🔧 Code Locations
- **Main Logic**: `NotificationService.swift`
- **Integration**: `ConnectionManager.swift` (3 callback locations)
- **Intervals**: Lines 13-28 in NotificationService.swift

## 🧪 Quick Test
1. Set tank to 3%
2. Watch console for escalation messages
3. Verify notifications appear every 30s, then 1min, then 2min
4. Enable Focus mode → Critical alerts should still appear
