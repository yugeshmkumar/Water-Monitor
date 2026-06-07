#pragma once
#include <Arduino.h>

// ─── System Health Monitoring ───────────────────────────────────────
// Tracks CPU, memory, and task health to detect degradation before restart

struct SystemHealth {
    // Memory metrics
    uint32_t heapFree;
    uint32_t heapFragmentation;
    uint32_t psramFree;

    // Task metrics
    bool sensorTaskHealthy;
    bool commsTaskHealthy;
    bool bleTaskHealthy;

    // WiFi metrics
    bool wifiConnected;
    int8_t wifiRssi;
    uint32_t wifiReconnectAttempts;

    // Sensor metrics
    uint32_t sensorReadCount;
    uint32_t sensorErrorCount;
    float sensorErrorRate;

    // Overall system health (0-100%)
    uint8_t healthScore;

    // Restart counter (for diagnostics)
    uint32_t restartCount;

    // Timestamp
    uint32_t timestampSec;
};

class HealthMonitor {
public:
    // Initialize health monitoring
    static void begin();

    // Update all health metrics
    static void update();

    // Get current health status
    static SystemHealth getHealth();

    // Check if system is healthy (>50%)
    static bool isHealthy();

    // Get detailed health report
    static String getHealthReport();

    // Check for specific failure conditions
    static bool hasMemoryLeak();      // Heap continuously decreasing
    static bool hasHighErrorRate();   // Sensor error rate >5%
    static bool isTaskStuck();        // Task not responding
    static bool isSensorFailing();    // Sensor not working

    // Trigger graceful restart on detected issues
    static void checkAndRecover();

private:
    static SystemHealth _health;
    static uint32_t _lastHeapFree;
    static unsigned long _lastUpdateMs;
    static uint8_t _consecutiveFailures;
};

extern HealthMonitor health;
