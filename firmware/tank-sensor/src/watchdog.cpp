#include "watchdog.h"
#include "config.h"
#include <esp_task_wdt.h>
#include <esp_chip_info.h>

// ─── Static Members ─────────────────────────────────────────────────
bool WatchdogManager::_armed = false;
unsigned long WatchdogManager::_lastGlobalFeed = 0;
TaskHealth WatchdogManager::_taskHealth[4] = {};
uint8_t WatchdogManager::_taskCount = 0;

WatchdogManager watchdog;

// ─── Watchdog Implementation ─────────────────────────────────────────

void WatchdogManager::begin() {
    // Check if watchdog is enabled in config
    if (!config.d.watchdog_enabled) {
        Serial.println("[Watchdog] DISABLED (config.watchdog_enabled = false)");
        _armed = false;
        return;
    }

    Serial.println("[Watchdog] Initializing hardware watchdog (30s timeout)...");

    // Configure Task WDT (watches for task hangs)
    // This resets ONLY if a task fails to "feed" within timeout
    esp_task_wdt_config_t twdt_config = {
        .timeout_ms = WATCHDOG_TIMEOUT_MS,  // 30 seconds
        .idle_core_mask = 0,                 // Don't watch idle tasks
        .trigger_panic = true                // Trigger panic on timeout (restart)
    };

    // Initialize Task WDT
    if (esp_task_wdt_init(&twdt_config) == ESP_OK) {
        Serial.println("[Watchdog] Task WDT initialized (30s)");
        _armed = true;
    } else {
        Serial.println("[Watchdog] ERROR: Failed to initialize Task WDT");
        _armed = false;
        return;
    }

    // Subscribe main loop to watchdog
    esp_task_wdt_add(NULL);  // Add current task (setup loop)
    _lastGlobalFeed = millis();

    // Log watchdog configuration
    Serial.printf("[Watchdog] Task monitoring enabled\n");
    Serial.printf("[Watchdog] Timeout: %u ms\n", WATCHDOG_TIMEOUT_MS);
    Serial.printf("[Watchdog] Restart reason: %s\n", getRestartReason().c_str());
}

void WatchdogManager::feed(const char* taskName) {
    if (!_armed) return;

    // Reset Task WDT for current task
    esp_task_wdt_reset();
    _lastGlobalFeed = millis();

    // Update task health tracking
    for (uint8_t i = 0; i < _taskCount; i++) {
        if (strcmp(_taskHealth[i].name, taskName) == 0) {
            _taskHealth[i].lastFedMs = millis();
            _taskHealth[i].iterationCount++;
            _taskHealth[i].isHealthy = true;
            break;
        }
    }
}

bool WatchdogManager::isTaskHealthy(const char* taskName) {
    for (uint8_t i = 0; i < _taskCount; i++) {
        if (strcmp(_taskHealth[i].name, taskName) == 0) {
            // Check if task fed within deadline
            unsigned long timeSinceFeed = millis() - _taskHealth[i].lastFedMs;
            return (timeSinceFeed < _taskHealth[i].deadlineMs);
        }
    }
    return false;  // Task not registered
}

unsigned long WatchdogManager::lastFedMs(const char* taskName) {
    for (uint8_t i = 0; i < _taskCount; i++) {
        if (strcmp(_taskHealth[i].name, taskName) == 0) {
            return _taskHealth[i].lastFedMs;
        }
    }
    return 0;
}

void WatchdogManager::registerTask(const char* taskName, TaskHandle_t handle, unsigned long deadlineMs) {
    if (_taskCount >= 4) {
        Serial.printf("[Watchdog] ERROR: Max tasks (4) already registered\n");
        return;
    }

    _taskHealth[_taskCount].name = taskName;
    _taskHealth[_taskCount].handle = handle;
    _taskHealth[_taskCount].deadlineMs = deadlineMs;
    _taskHealth[_taskCount].lastFedMs = millis();
    _taskHealth[_taskCount].iterationCount = 0;
    _taskHealth[_taskCount].isHealthy = true;

    // Subscribe task to Task WDT
    esp_task_wdt_add(handle);

    Serial.printf("[Watchdog] Registered task: %s (deadline: %lums)\n", taskName, deadlineMs);
    _taskCount++;
}

void WatchdogManager::triggerRestart(const char* reason) {
    Serial.printf("[Watchdog] Triggering restart: %s\n", reason);
    Serial.flush();
    delay(1000);
    ESP.restart();
}

String WatchdogManager::getRestartReason() {
    esp_reset_reason_t reason = esp_reset_reason();

    switch (reason) {
        case ESP_RST_UNKNOWN:
            return "Unknown reset";
        case ESP_RST_POWERON:
            return "Power-on reset";
        case ESP_RST_EXT:
            return "External reset";
        case ESP_RST_SW:
            return "Software reset";
        case ESP_RST_PANIC:
            return "Panic/Exception reset";
        case ESP_RST_INT_WDT:
            return "Interrupt watchdog timeout";
        case ESP_RST_TASK_WDT:
            return "Task watchdog timeout";
        case ESP_RST_WDT:
            return "Watchdog reset";
        case ESP_RST_DEEPSLEEP:
            return "Deep sleep wakeup";
        case ESP_RST_BROWNOUT:
            return "Brownout reset";
        case ESP_RST_SDIO:
            return "SDIO reset";
#ifdef ESP_RST_USB_JTAG
        case ESP_RST_USB_JTAG:
            return "USB JTAG reset";
#endif
        case ESP_RST_JTAG:
            return "JTAG reset";
        default:
            return "Unknown reason";
    }
}

// ─── Diagnostics Helper ──────────────────────────────────────────────

void printWatchdogStatus() {
    Serial.println("\n[Watchdog Status]");
    Serial.printf("  Armed: %s\n", watchdog.isArmed() ? "YES" : "NO");
    Serial.printf("  Last feed: %lums ago\n", millis() - watchdog.lastFedMs("main"));

    // Print individual task health
    Serial.println("  Task Health:");
    // Note: In actual implementation, we'd iterate through registered tasks
    // This is a placeholder for the diagnostics output
}
