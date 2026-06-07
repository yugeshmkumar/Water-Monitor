# Watchdog Configuration Guide

**Date:** 2026-06-07  
**Status:** Ready for Production & Development

---

## Overview

The hardware watchdog system can be **enabled or disabled** via configuration, making it perfect for both production deployment and development/debugging scenarios.

---

## Disabling Watchdog (Development Mode)

### Via REST API (While Connected)

```http
POST http://device.local/api/config
Content-Type: application/json

{
  "watchdog_enabled": false
}
```

**Response:**
```json
{"ok": true}
```

**Effect:** Watchdog disabled immediately on this boot. Survives restart (persisted in NVS).

### Via Serial Monitor (Before WiFi)

Edit `src/config.h` before compilation:

```cpp
bool watchdog_enabled = false;  // Disable for development
```

Then recompile and flash.

### Via Configuration File (NVS)

The watchdog_enabled flag is stored in NVS and persists across restarts.

---

## Re-Enabling Watchdog (Production Mode)

### Via REST API

```http
POST http://device.local/api/config
{
  "watchdog_enabled": true
}
```

### Via Serial Monitor

Edit `src/config.h`:

```cpp
bool watchdog_enabled = true;  // Enable for production
```

---

## When to Disable Watchdog

### ✅ Development & Debugging
- Stepping through code with debugger
- Testing timeout edge cases (intentionally blocking tasks)
- Debugging firmware hangs (won't restart unexpectedly)
- Long serial debugging sessions

### ✅ Troubleshooting Crashes
- If device keeps restarting, disable watchdog to identify root cause
- Check Serial logs for actual errors (not watchdog timeouts)
- Re-enable once root cause is fixed

### ❌ Production Deployment
- **NEVER** disable in production
- Watchdog is your safety net for field failures
- Without it, hung device = data loss until manual recovery

---

## Configuration Details

### Config Structure (src/config.h)

```cpp
struct DeviceConfig {
    // ... other fields ...
    bool watchdog_enabled = true;  // Hardware watchdog (auto-restart on hang)
    // ... other fields ...
};
```

### Default Value

**Default:** `true` (watchdog enabled)

### Persistence

- Changes via REST API are automatically saved to NVS
- Survives power loss and restart
- Reset to defaults via factory reset command

---

## Serial Output

### Watchdog Enabled ✅

```
[Boot] Production-Grade Firmware with Watchdog & Health Monitoring
[Watchdog] Initializing hardware watchdog (30s timeout)...
[Watchdog] Task WDT initialized (30s)
[Watchdog] Task monitoring enabled
[Watchdog] Timeout: 30000 ms
[Watchdog] Restart reason: Power-on reset
```

### Watchdog Disabled ❌

```
[Boot] Production-Grade Firmware with Watchdog & Health Monitoring
[Watchdog] DISABLED (config.watchdog_enabled = false)
```

---

## Task Watchdog Behavior

### When Enabled

- Each task registers with hardware watchdog
- Must call `watchdog.feed(taskName)` before deadline
- Missing deadline → automatic system restart
- Restart reason logged for diagnostics

### When Disabled

- `watchdog.feed()` calls are no-ops (safe)
- Tasks can hang without restarting
- Health monitoring still runs (logs warnings)
- System stays alive indefinitely (useful for debugging)

---

## Recommended Settings

| Scenario | Watchdog | Reason |
|----------|----------|--------|
| **Production Deployment** | ✅ ENABLED | Auto-recovery on failures |
| **Field Testing** | ✅ ENABLED | Catches real-world issues |
| **Development** | ❌ DISABLED | Better for debugging |
| **Hardware Debug** | ❌ DISABLED | Prevents restart during step-through |
| **Stability Testing** | ✅ ENABLED | Find edge cases that hang |
| **Serial Troubleshooting** | ❌ DISABLED | Stays alive for log inspection |

---

## API Reference

### Enable Watchdog

```
POST /api/config
{"watchdog_enabled": true}
```

### Disable Watchdog

```
POST /api/config
{"watchdog_enabled": false}
```

### Check Current Setting

```
GET /api/diagnostics
```

Returns in `config` section:
```json
{
  "config": {
    "watchdog_enabled": true,
    ...
  }
}
```

---

## Troubleshooting

### Device Keeps Restarting

1. Disable watchdog (temporary):
   ```
   POST /api/config
   {"watchdog_enabled": false}
   ```

2. Check Serial logs for actual error messages
3. Fix the issue
4. Re-enable watchdog

### Watchdog Doesn't Restart on Timeout

Verify it's actually enabled:
```
GET /api/diagnostics
→ Check "watchdog_enabled": true
```

If disabled, re-enable:
```
POST /api/config
{"watchdog_enabled": true}
```

### Need to Debug Without Restarting

Disable watchdog first:
```
POST /api/config
{"watchdog_enabled": false}
```

Then you can:
- Pause execution in debugger
- Read Serial logs at leisure
- Step through functions
- All without 30-second timeout

---

## Code Examples

### Check Watchdog Status (in firmware)

```cpp
if (watchdog.isArmed()) {
    Serial.println("Watchdog is active");
} else {
    Serial.println("Watchdog is disabled");
}
```

### Safe Watchdog Feeding (Always Safe)

```cpp
// Safe to call even if watchdog is disabled
watchdog.feed("myTask");  // No-op if disabled, feeds if enabled
```

### Force Graceful Restart

```cpp
// Triggered by health monitoring on critical failures
watchdog.triggerRestart("Custom reason");
```

---

## Production Checklist

Before field deployment:

- [ ] Watchdog enabled in config: `watchdog_enabled = true`
- [ ] All tasks feed watchdog periodically (before deadline)
- [ ] Health monitoring enabled (detects failures)
- [ ] Restart reason logging verified (Serial output on boot)
- [ ] Tested forced timeout (verify restart works)
- [ ] Tested recovery (verify data preserved)

---

## Safety Notes

1. **Never disable in production** — Device will hang forever if bug occurs
2. **Watchdog is non-invasive** — Safe to leave enabled during development
3. **Feed calls are safe** — No harm in extra feeds or when disabled
4. **Timeout is generous** — 30 seconds is plenty for normal operation
5. **Health monitoring continues** — Even with watchdog disabled

---

## Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Configurable | ✅ YES | Via REST API or config.h |
| Persistent | ✅ YES | Survives reboot (NVS storage) |
| Default | ✅ ENABLED | Safe for most scenarios |
| Development | ✅ SAFE | Easy to disable for debugging |
| Production | ✅ REQUIRED | Critical for field reliability |

**Watchdog is your safety net. Enable it in production, disable only when needed for development.**
