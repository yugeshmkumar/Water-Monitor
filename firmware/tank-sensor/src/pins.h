#pragma once

// JSN-SR04T Mode 0 — trigger/echo wiring (confirmed from pinout image)
#define PIN_TRIG    D2          // GPIO2  — output to sensor TRIG
#define PIN_ECHO    D1          // GPIO1  — input from sensor ECHO (via 1kΩ+2kΩ divider)

// Status LED
#define PIN_LED     LED_BUILTIN // GPIO15 — yellow onboard LED

// Available for future use
#define PIN_SPARE_1 D3          // GPIO21
#define PIN_SPARE_2 D4          // GPIO22

// DO NOT USE — RF switch lines
// GPIO3  = WIFI_ENABLE
// GPIO14 = WIFI_ANT_CONFIG
