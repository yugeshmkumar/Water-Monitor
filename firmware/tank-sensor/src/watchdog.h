#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

// ─── Hardware Watchdog Configuration ─────────────────────────────────
// ESP32 has built-in watchdog timers:
// - MWDT0 (Main WDT): Resets entire chip if task hangs
// - TWDT (Task WDT): Resets if specific tasks don't "feed" the watchdog

#define WATCHDOG_TIMEOUT_MS             30000   // 30 seconds global timeout
#define TASK_FEED_INTERVAL_MS           10000   // Feed watchdog every 10s
#define MEASUREMENT_TASK_TIMEOUT_MS     15000   // Sensor task must complete in 15s
#define COMMS_TASK_TIMEOUT_MS           20000   // Network task must complete in 20s
#define BLE_TASK_TIMEOUT_MS             10000   // BLE task must complete in 10s

// Task health monitoring structure
struct TaskHealth {
    const char* name;
    TaskHandle_t handle;
    unsigned long lastFedMs;
    unsigned long deadlineMs;
    uint32_t iterationCount;
    bool isHealthy;
};

// ─── Watchdog API ───────────────────────────────────────────────────
class WatchdogManager {
public:
    // Initialize hardware and software watchdog
    static void begin();

    // Feed the watchdog (must be called periodically from tasks)
    static void feed(const char* taskName);

    // Check if watchdog is armed
    static bool isArmed() { return _armed; }

    // Get task health status
    static bool isTaskHealthy(const char* taskName);

    // Get last feed time for a task
    static unsigned long lastFedMs(const char* taskName);

    // Force a restart (for graceful shutdown)
    static void triggerRestart(const char* reason);

    // Get restart reason (for diagnostics)
    static String getRestartReason();

    // Initialize task health monitoring
    static void registerTask(const char* taskName, TaskHandle_t handle, unsigned long deadlineMs);

private:
    static bool _armed;
    static unsigned long _lastGlobalFeed;
    static TaskHealth _taskHealth[4];  // Monitor up to 4 tasks
    static uint8_t _taskCount;
};

extern WatchdogManager watchdog;
