# 📊 DUAL NOTIFICATION SYSTEM - Visual Guide

## 🎯 **COMPLETE NOTIFICATION FLOW**

```
                    Tank Reading Arrives
                            ↓
              NotificationService.checkTankLevel()
                            ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌─────────────────┐                  ┌─────────────────┐
│ System          │                  │ In-App Alert    │
│ Notifications   │                  │ Manager         │
└────────┬────────┘                  └────────┬────────┘
         ↓                                     ↓
   (Background)                          (Foreground)
         ↓                                     ↓
  ┌─────────────┐                    ┌─────────────────┐
  │ Notification │                    │ Modal Alert     │
  │ Center       │                    │ Dialog          │
  └──────────────┘                    └─────────────────┘
```

---

## 📱 **SCENARIO 1: App is OPEN (Foreground)**

```
┌────────────────────────────────────────────────────────────┐
│  Your App (Active)                                         │
│  ┌──────────────────────────────────────────────┐          │
│  │                                              │          │
│  │   Tank Dashboard                            │          │
│  │   ┌──────────────┐                          │          │
│  │   │ Tank-2: 100% │                          │          │
│  │   └──────────────┘                          │          │
│  │                                              │          │
│  └──────────────────────────────────────────────┘          │
│                       ↓                                    │
│          📊 Reading arrives: 100%                          │
│                       ↓                                    │
│  ┌─────────────────────────────────────────────┐           │
│  │  💧 Tank Full                               │           │
│  │  ─────────────────────────────────────────  │           │
│  │  Tank-2 has reached 100%.                   │  ← IN-APP │
│  │  Stop filling to prevent overflow.          │  ← ALERT  │
│  │                                             │           │
│  │  💡 Tip: Connect a motor controller         │           │
│  │  to prevent overflow.                       │           │
│  │  ─────────────────────────────────────────  │           │
│  │           [OK]    [View Tank]               │           │
│  └─────────────────────────────────────────────┘           │
│                                                            │
└────────────────────────────────────────────────────────────┘

ALSO SENT:
┌────────────────────────────────────────────────┐
│ 🔔 Notification Center                         │
│ ──────────────────────────────────────────────│
│ 💧 Tank Full - Tank-2                         │
│ Tank at 100%. Stop filling...                 │
│                                    [now]       │
└────────────────────────────────────────────────┘
```

**User Experience:**
1. ✅ **Immediate alert dialog** pops up (can't miss it!)
2. ✅ **System notification** also sent (for history)
3. ✅ **Clear action buttons** (OK, View Tank)
4. ✅ **Helpful tips** if no motor controller

---

## 🔔 **SCENARIO 2: App is BACKGROUNDED**

```
┌────────────────────────────────────────────────────────────┐
│  iPhone Lock Screen                                        │
│                                                            │
│                  12:34                                     │
│                  ─────                                     │
│                                                            │
│  ┌──────────────────────────────────────────┐             │
│  │ 🔔 Notification Center                   │             │
│  │ ────────────────────────────────────────│             │
│  │                                          │             │
│  │ 💧 Tank Full - Tank-2          [now]    │  ← SYSTEM   │
│  │ Tank at 100%. Stop filling to prevent   │  ← NOTIFICATION
│  │ overflow.                                │             │
│  │                                          │             │
│  └──────────────────────────────────────────┘             │
│                                                            │
│  Reading arrived: 100%                                     │
│  ↓                                                         │
│  System notification sent                                 │
│  In-app alert NOT shown (app isn't visible)              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**User Experience:**
1. ✅ **System notification** appears on lock screen
2. ✅ **Sound/vibration** alerts user
3. ✅ **Tap notification** to open app
4. ⏸️ **No in-app dialog** (app wasn't visible)

---

## 🚨 **SCENARIO 3: CRITICAL Alert (≤5%)**

```
┌────────────────────────────────────────────────────────────┐
│  Your App (Active)                                         │
│  ┌──────────────────────────────────────────────┐          │
│  │   Tank-2: 3% ⚠️ CRITICAL                    │          │
│  └──────────────────────────────────────────────┘          │
│                       ↓                                    │
│  ┌─────────────────────────────────────────────┐           │
│  │  🚨 CRITICAL - Tank Nearly Empty            │           │
│  │  ───────────────────────────────────────────│           │
│  │  ⚠️ Tank-2 is at 3%!                       │  ← URGENT │
│  │  Refill IMMEDIATELY to prevent damage.      │  ← ALERT  │
│  │                                             │           │
│  │  💡 Tip: Connect a motor controller         │           │
│  │  to automate filling.                       │           │
│  │  ───────────────────────────────────────────│           │
│  │                  [OK]                        │           │
│  └─────────────────────────────────────────────┘           │
│                                                            │
│  ⏰ 30 seconds later (still at 3%)...                      │
│  ┌─────────────────────────────────────────────┐           │
│  │  🚨 CRITICAL - Tank Nearly Empty            │  ← REPEAT │
│  │  ───────────────────────────────────────────│  ← ALERT  │
│  │  ⚠️ Tank-2 is at 3%!                       │  ← (Spam  │
│  │  Refill IMMEDIATELY to prevent damage.      │  ← Prevention)
│  └─────────────────────────────────────────────┘           │
└────────────────────────────────────────────────────────────┘

PLUS: System notification with CRITICAL interruption level
→ Breaks through ALL Focus/DND modes!
```

**User Experience:**
1. 🚨 **Immediate critical alert** in app
2. 🚨 **System notification** breaks through Focus/DND
3. 🚨 **Repeat alert after 30 seconds** (very urgent!)
4. 🚨 **Special critical sound** on system notification

---

## 💡 **SCENARIO 4: Motor Controller Tips**

### **Without Motor Controller:**
```
┌─────────────────────────────────────────────┐
│  💧 Tank Full                               │
│  ─────────────────────────────────────────  │
│  Tank-2 has reached 100%.                   │
│  Stop filling to prevent overflow.          │
│                                             │
│  💡 Tip: Connect a motor controller         │ ← EDUCATION
│  to prevent overflow.                       │ ← FEATURE
│  ─────────────────────────────────────────  │
│           [OK]    [View Tank]               │
└─────────────────────────────────────────────┘
```

### **With Motor Controller:**
```
┌─────────────────────────────────────────────┐
│  💧 Tank Full                               │
│  ─────────────────────────────────────────  │
│  Tank-2 has reached 100%.                   │
│  Turn off Motor-1 NOW to prevent overflow.  │ ← ACTIONABLE
│  ─────────────────────────────────────────  │ ← INSTRUCTION
│           [OK]    [View Tank]               │
└─────────────────────────────────────────────┘
```

---

## 📊 **ALERT FREQUENCY COMPARISON**

### **Critical Alert (3%) - App is OPEN:**

```
Time    System Notification          In-App Alert
─────────────────────────────────────────────────────
0:00    🔔 CRITICAL #1               📱 CRITICAL #1
0:30    🔔 CRITICAL #2               📱 CRITICAL #2
1:30    🔔 CRITICAL #3               📱 CRITICAL #3
3:30    🔔 CRITICAL #4               📱 CRITICAL #4
8:30    🔔 CRITICAL #5               📱 CRITICAL #5

Both systems alert aggressively for critical conditions!
```

### **Full Alert (100%) - App is OPEN:**

```
Time    System Notification          In-App Alert
─────────────────────────────────────────────────────
0:00    🔔 FULL #1                   📱 FULL #1
1:00    ⏸️ Waiting (5min cooldown)   📱 FULL #2 ✓
5:00    🔔 FULL #2                   📱 FULL #3
6:00    ⏸️ Waiting                    📱 FULL #4 ✓

In-app alerts repeat more frequently (1min vs 5min)
because user is actively viewing the app!
```

---

## 🎯 **STATE TRANSITION EXAMPLES**

### **Example 1: Tank Filling**
```
State       Level   System Notification   In-App Alert
───────────────────────────────────────────────────────
Normal      50%     -                     -
Normal      70%     -                     -
Normal      90%     -                     -
NearlyFull  96%     🔔 "Nearly Full"      📱 "Nearly Full"
NearlyFull  98%     ⏸️ (same state)       ⏸️ (cooldown)
Full        100%    🔔 "FULL" ✓          📱 "FULL" ✓

State change (nearlyFull → full) = immediate alert!
```

### **Example 2: Tank Emptying**
```
State       Level   System Notification   In-App Alert
───────────────────────────────────────────────────────
Normal      50%     -                     -
Normal      30%     -                     -
Low         15%     🔔 "Low"              📱 "Low"
Low         10%     ⏸️ (same state)       ⏸️ (cooldown)
Critical    3%      🔔 "CRITICAL" ✓       📱 "CRITICAL" ✓

State change (low → critical) = immediate alert!
```

---

## 🔔 **NOTIFICATION PRIORITY LEVELS**

```
┌─────────────────────────────────────────────────────────┐
│  iOS Focus/DND Settings                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🔴 CRITICAL (≤5%)                                      │
│     InterruptionLevel: .critical                        │
│     ✅ ALWAYS breaks through Focus/DND                  │
│     ✅ Special critical alert sound                     │
│     ✅ Shows on lock screen                             │
│                                                         │
│  🟡 TIME-SENSITIVE (Low/Full)                           │
│     InterruptionLevel: .timeSensitive                   │
│     ✅ Bypasses most Focus modes                        │
│     ✅ Shows in Notification Center                     │
│     ⚠️ May be delayed in strict DND                     │
│                                                         │
│  🟢 ACTIVE (Nearly Full)                                │
│     InterruptionLevel: .active                          │
│     ⚠️ Respects Focus mode settings                     │
│     ✅ Shows in Notification Center                     │
│     ⚠️ May be silenced during Focus                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 **UI/UX BENEFITS**

### **In-App Alerts:**
✅ **Impossible to miss** (modal dialog)  
✅ **Immediate feedback** (no notification delay)  
✅ **Action buttons** (View Tank, OK)  
✅ **Educational tips** (motor controller suggestions)  
✅ **Context-aware** (only when app is visible)  

### **System Notifications:**
✅ **Persistent** (stays in Notification Center)  
✅ **Works in background** (app doesn't need to be open)  
✅ **Lock screen display** (see alerts when phone locked)  
✅ **Sound/vibration** (audio/haptic feedback)  
✅ **Focus mode integration** (critical alerts break through)  

---

## 🚀 **SUMMARY**

| Condition | App State | In-App Alert | System Notification |
|-----------|-----------|--------------|---------------------|
| Tank Full | Open | ✅ Modal dialog | ✅ Notification Center |
| Tank Full | Background | ❌ Not visible | ✅ Lock screen + sound |
| Tank Critical | Open | ✅ Modal (30s repeat) | ✅ Breaks through DND |
| Tank Critical | Background | ❌ Not visible | ✅ Critical sound + lock screen |

**Result:** 
- **Can't miss alerts** when using app (modal dialogs)
- **Can't miss alerts** when app backgrounded (notifications)
- **Education built-in** (motor controller tips)
- **Dual redundancy** for critical safety alerts

**Best of both worlds!** 🎉
