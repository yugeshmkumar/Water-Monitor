#pragma once

// ─── SR04M-2 Triggered UART Interface ────────────────────────────
// Sensor communicates via UART: MCU sends 0x55, sensor replies with 4-byte frame
// Frame format: [0xFF] [DataH] [DataL] [Checksum]
// Baud: 9600, Data: 8N1 (8 bits, no parity, 1 stop bit)
#define PIN_SENSOR_TX    GPIO_NUM_21    // D3  — MCU sends trigger command 0x55
#define PIN_SENSOR_RX    GPIO_NUM_20    // D9  — MCU receives 4-byte response
#define UART_NUM         UART_NUM_1     // Hardware UART 1 for sensor
#define UART_BAUD        9600           // SR04M-2 communication speed

// ─── Control & Status ────────────────────────────────────────────
#define PIN_RESET_BTN    GPIO_NUM_8     // D0  — Factory reset button
#define PIN_LED_STATUS   GPIO_NUM_15    // LED_BUILTIN — Status indicator

// ─── Optional Sensors ────────────────────────────────────────────
#define PIN_TEMP_SENSOR  GPIO_NUM_7     // D6  — DS18B20 (1-wire, optional)

// ─── Reserved for Phase 2 (Motor Control) ────────────────────────
// #define PIN_MOTOR_PWM    GPIO_NUM_9     // D5  — Motor PWM speed
// #define PIN_MOTOR_DIR    GPIO_NUM_18    // D7  — Motor direction control

// ─── DO NOT USE — RF Switch Control Lines ────────────────────────
// GPIO3  = WIFI_ENABLE (internal, automatic by WiFi stack)
// GPIO14 = WIFI_ANT_CONFIG (internal, automatic by WiFi stack)
// Using these pins will break WiFi connectivity!
