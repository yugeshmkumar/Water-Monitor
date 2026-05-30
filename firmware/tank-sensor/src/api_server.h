/**
 * REST API & WebSocket Server for Water Monitor
 *
 * OVERVIEW:
 * ApiServer provides the complete HTTP interface for the water monitor device.
 * It combines:
 * - REST API endpoints for querying status, config, and commands
 * - WebSocket connection at /live for real-time sensor streaming
 * - OTA firmware update support via ElegantOTA
 *
 * PORTS:
 * - Single AsyncWebServer on port 80 handles both REST and WebSocket
 * - mDNS advertises device as {node_id}.local (e.g., sensor-a.local)
 *
 * REST ENDPOINTS:
 * - GET /api/status        → Current sensor reading + WiFi + queue status (JSON)
 * - GET /api/config        → Full device config + runtime info (JSON)
 * - POST /api/config       → Update partial config fields (JSON)
 * - POST /api/queue/flush  → Fetch up to 50 pending queue entries
 * - POST /api/queue/ack    → Acknowledge queue entries {"seq_up_to": N}
 * - POST /api/command      → Send device commands {"cmd": "test_pin", ...}
 * - GET /api/ota/check     → Check current firmware version
 * - POST /api/ota/start    → Start OTA update {"url": "http://..."}
 * - GET /update            → ElegantOTA browser interface (upload .bin)
 *
 * WEBSOCKET:
 * - WS /live               → Real-time sensor streaming
 *   • On connect: server sends current status immediately
 *   • Broadcasts new readings as they arrive
 *   • Message format: {"level_pct": 45, "distance_cm": 87.5, "ts": 12345, ...}
 *
 * THREAD SAFETY:
 * ApiServer is designed to run on the FreeRTOS commsTask (high priority).
 * - broadcastLevel() is thread-safe (uses internal locks)
 * - REST/WebSocket callbacks execute in async context (safe for I/O)
 * - Never call device_state directly from REST handlers; use snapshots
 *
 * RESPONSE FORMAT:
 * All endpoints return JSON-formatted responses:
 * - Success (HTTP 200): {"field": value, ...}
 * - Error (HTTP 4xx/5xx): {"error": "description"}
 */

#pragma once
#include <ESPAsyncWebServer.h>

class ApiServer {
public:
    // Initialize server with default port 80 and /live WebSocket path
    ApiServer() : _http(80), _ws("/live") {}

    /**
     * Start the HTTP server, mDNS, WebSocket, and OTA.
     * Called from commsTask during initialization.
     * Blocks until server is listening on port 80.
     */
    void begin();

    /**
     * Per-loop maintenance (WebSocket cleanup, state broadcasts).
     * Called frequently from commsTask main loop.
     * Must be called regularly to keep WebSocket connections healthy.
     */
    void loop();

    /**
     * Broadcast current sensor reading to all connected WebSocket clients.
     * Thread-safe: can be called from any FreeRTOS task.
     * If no clients are connected, does nothing (early return).
     * Message format: {"level_pct": uint8, "distance_cm": float, "ts": uint32, ...}
     *
     * Parameters:
     *   distCM   - Distance reading in centimeters
     *   levelPct - Calculated tank fill percentage (0-100)
     *   ts       - Seconds since device boot
     *
     * Example usage:
     *   apiServer.broadcastLevel(87.5, 45, millis() / 1000);
     */
    void broadcastLevel(float distCM, uint8_t levelPct, uint32_t ts);

private:
    AsyncWebServer _http;    // HTTP server on port 80 (REST + OTA)
    AsyncWebSocket _ws;      // WebSocket at /live for streaming readings

    void _setupRest();       // Configure all REST endpoints
    void _setupWebSocket();  // Configure WebSocket handlers
    void _onWsEvent(AsyncWebSocket* server, AsyncWebSocketClient* client,
                    AwsEventType type, void* arg, uint8_t* data, size_t len);
};

/**
 * CONNECTION & TIMEOUT LIMITS:
 * • Max concurrent WebSocket clients: 10 (enforced by AsyncWebSocket)
 * • WebSocket heartbeat/keepalive timeout: 30 seconds (no messages = disconnect)
 * • HTTP request timeout: 30 seconds (AsyncWebServer default)
 * • Stale connection cleanup: Runs every loop() call (~100ms)
 * These limits prevent DoS and memory exhaustion from hung clients.
 */

// Global ApiServer instance used by all modules
extern ApiServer apiServer;
