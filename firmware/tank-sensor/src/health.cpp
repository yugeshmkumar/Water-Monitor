#include "health.h"
#include "sensor.h"
#include "state.h"
#include "watchdog.h"
#include <WiFi.h>

// ─── Static Members ─────────────────────────────────────────────────
SystemHealth HealthMonitor::_health = {};
uint32_t HealthMonitor::_lastHeapFree = 0;
unsigned long HealthMonitor::_lastUpdateMs = 0;
uint8_t HealthMonitor::_consecutiveFailures = 0;

HealthMonitor health;

void HealthMonitor::begin() {
    Serial.println("[Health] Initializing system health monitoring");
    _lastHeapFree = ESP.getFreeHeap();
    _health.restartCount = 0;  // TODO: Load from NVS
    _health.healthScore = 100;
    _lastUpdateMs = millis();
}

void HealthMonitor::update() {
    if (millis() - _lastUpdateMs < 5000) return;  // Update every 5 seconds
    _lastUpdateMs = millis();

    // Memory metrics
    _health.heapFree = ESP.getFreeHeap();
    // heapFragmentation not available on ESP32-C6
    _health.psramFree = ESP.getFreePsram();

    // Task health (check if tasks are feeding watchdog)
    _health.sensorTaskHealthy = watchdog.isTaskHealthy("sensor");
    _health.commsTaskHealthy = watchdog.isTaskHealthy("comms");
    _health.bleTaskHealthy = watchdog.isTaskHealthy("ble");

    // WiFi metrics
    _health.wifiConnected = (WiFi.status() == WL_CONNECTED);
    _health.wifiRssi = _health.wifiConnected ? WiFi.RSSI() : 0;

    // Sensor metrics
    SensorDiag diag = getSensorDiagnostics();
    _health.sensorReadCount = diag.readCount;
    _health.sensorErrorCount = diag.frameErrorCount + diag.timeoutCount;
    _health.sensorErrorRate = diag.readCount > 0
        ? (float)_health.sensorErrorCount / diag.readCount * 100.0f
        : 0.0f;

    // Calculate overall health score (0-100)
    uint8_t score = 100;

    // Penalize for task failures (-25 each)
    if (!_health.sensorTaskHealthy) score -= 25;
    if (!_health.commsTaskHealthy) score -= 25;
    if (!_health.bleTaskHealthy) score -= 15;

    // Penalize for high error rate (-10 per 1%)
    if (_health.sensorErrorRate > 1.0f) {
        score -= min((uint8_t)((_health.sensorErrorRate - 1.0f) / 1.0f * 10), (uint8_t)20);
    }

    // Penalize for low heap (-5 per 5KB below 50KB)
    if (_health.heapFree < 50000) {
        score -= min((uint8_t)((50000 - _health.heapFree) / 5000), (uint8_t)15);
    }

    // Penalize for high fragmentation (-10 per 10%)
    if (_health.heapFragmentation > 50) {
        score -= min((uint8_t)((_health.heapFragmentation - 50) / 10), (uint8_t)20);
    }

    _health.healthScore = constrain(score, 0, 100);
    _health.timestampSec = millis() / 1000;
}

SystemHealth HealthMonitor::getHealth() {
    return _health;
}

bool HealthMonitor::isHealthy() {
    return _health.healthScore > 50;
}

String HealthMonitor::getHealthReport() {
    String report;
    report += "[System Health Report]\n";
    report += "Health Score: " + String(_health.healthScore) + "%\n\n";

    report += "Memory:\n";
    report += "  Heap Free: " + String(_health.heapFree) + " bytes\n";
    report += "  Heap Frag: " + String(_health.heapFragmentation) + "%\n";
    report += "  PSRAM Free: " + String(_health.psramFree) + " bytes\n\n";

    report += "Tasks:\n";
    report += "  Sensor: " + String(_health.sensorTaskHealthy ? "✓" : "✗") + "\n";
    report += "  Comms: " + String(_health.commsTaskHealthy ? "✓" : "✗") + "\n";
    report += "  BLE: " + String(_health.bleTaskHealthy ? "✓" : "✗") + "\n\n";

    report += "WiFi:\n";
    report += "  Connected: " + String(_health.wifiConnected ? "Yes" : "No") + "\n";
    report += "  RSSI: " + String(_health.wifiRssi) + " dBm\n\n";

    report += "Sensor:\n";
    report += "  Reads: " + String(_health.sensorReadCount) + "\n";
    report += "  Errors: " + String(_health.sensorErrorCount) + "\n";
    report += "  Error Rate: " + String(_health.sensorErrorRate, 1) + "%\n";

    return report;
}

bool HealthMonitor::hasMemoryLeak() {
    // Check if heap is continuously decreasing
    uint32_t heapDelta = _lastHeapFree - _health.heapFree;
    if (heapDelta > 5000) {  // Lost 5KB in 5 seconds
        _lastHeapFree = _health.heapFree;
        return true;
    }
    _lastHeapFree = _health.heapFree;
    return false;
}

bool HealthMonitor::hasHighErrorRate() {
    return _health.sensorErrorRate > 5.0f;  // >5% errors
}

bool HealthMonitor::isTaskStuck() {
    return !_health.sensorTaskHealthy || !_health.commsTaskHealthy;
}

bool HealthMonitor::isSensorFailing() {
    return _health.sensorReadCount > 100 && _health.sensorErrorRate > 10.0f;
}

void HealthMonitor::checkAndRecover() {
    // Check for failure conditions
    if (hasMemoryLeak()) {
        Serial.println("[Health] ALERT: Memory leak detected!");
        _consecutiveFailures++;
        if (_consecutiveFailures >= 3) {
            watchdog.triggerRestart("Memory leak (3 consecutive detections)");
        }
        return;
    }

    if (isTaskStuck()) {
        Serial.println("[Health] ALERT: Task stuck detected!");
        _consecutiveFailures++;
        if (_consecutiveFailures >= 2) {
            watchdog.triggerRestart("Task stuck/unresponsive");
        }
        return;
    }

    if (isSensorFailing()) {
        Serial.println("[Health] ALERT: Sensor failing!");
        _consecutiveFailures++;
        if (_consecutiveFailures >= 5) {
            watchdog.triggerRestart("Sensor error rate too high (>10%)");
        }
        return;
    }

    // If conditions improved, reset failure counter
    if (_health.healthScore > 70) {
        _consecutiveFailures = 0;
    }
}
