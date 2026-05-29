#pragma once
#include <ESPAsyncWebServer.h>

class ApiServer {
public:
    ApiServer() : _http(80), _ws("/live") {}

    void begin();
    void loop();  // WebSocket cleanup + periodic state push

    // Thread-safe broadcast to all WebSocket clients
    void broadcastLevel(float distCM, uint8_t levelPct, uint32_t ts);

private:
    AsyncWebServer _http;    // REST + WebSocket on port 80
    AsyncWebSocket _ws;

    void _setupRest();
    void _setupWebSocket();
    void _onWsEvent(AsyncWebSocket* server, AsyncWebSocketClient* client,
                    AwsEventType type, void* arg, uint8_t* data, size_t len);
};

extern ApiServer apiServer;
