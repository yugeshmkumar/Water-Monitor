#ifndef CONSTANTS_H
#define CONSTANTS_H

#include <stdint.h>

// ────────────────────────────────────────────────────────────
// Network & API Constants
// ────────────────────────────────────────────────────────────

#define HTTP_SERVER_PORT 80
#define HTTP_TIMEOUT_MS 5000
#define HTTP_STATUS_OK 200
#define HTTP_STATUS_ACCEPTED 202
#define HTTP_STATUS_BAD_REQUEST 400
#define HTTP_STATUS_NOT_FOUND 404

#define MDNS_TIMEOUT_MS 50
#define SEMAPHORE_TIMEOUT_MS 50

#define QUEUE_FLUSH_MAX_ENTRIES 50
#define REBOOT_DELAY_MS 500

// ────────────────────────────────────────────────────────────
// Buffer Sizes
// ────────────────────────────────────────────────────────────

#define OTA_URL_MAX_LEN 256
#define HTTP_RESPONSE_BUFFER_SIZE 256
#define COMMAND_RESULT_BUFFER_SIZE 128
#define JSON_BUFFER_SIZE 256
#define VERSION_BUFFER_SIZE 128

// ────────────────────────────────────────────────────────────
// FreeRTOS Task Configuration
// ────────────────────────────────────────────────────────────

#define OTA_TASK_STACK_SIZE 8192
#define OTA_TASK_PRIORITY 5

#define COMMS_TASK_STACK_SIZE 4096
#define COMMS_TASK_PRIORITY 4

#define SENSOR_TASK_STACK_SIZE 2048
#define SENSOR_TASK_PRIORITY 3

#define BLE_TASK_STACK_SIZE 4096
#define BLE_TASK_PRIORITY 2

// ────────────────────────────────────────────────────────────
// Sensor Configuration
// ────────────────────────────────────────────────────────────

#define SENSOR_READ_INTERVAL_MS 5000
#define SENSOR_FILTER_SAMPLES 10
#define SENSOR_ERROR_THRESHOLD 3

#define DISTANCE_MIN_CM 5
#define DISTANCE_MAX_CM 300

#define LEVEL_HISTORY_SIZE 100

// ────────────────────────────────────────────────────────────
// WiFi & BLE Configuration
// ────────────────────────────────────────────────────────────

#define WIFI_CONNECT_TIMEOUT_MS 15000
#define WIFI_RECONNECT_INTERVAL_MS 30000
#define WIFI_RSSI_UPDATE_INTERVAL_MS 30000

#define BLE_ADVERTISE_INTERVAL_MS 2000
#define BLE_MTU_SIZE 517

#define QUEUE_SYNC_INTERVAL_MS 60000

// ────────────────────────────────────────────────────────────
// BLE Buffer Sizes
// ────────────────────────────────────────────────────────────

#define BLE_CONFIG_READ_BUFFER_SIZE 450
#define BLE_CONFIG_UPDATE_BUFFER_SIZE 300
#define BLE_LEVEL_NOTIFY_BUFFER_SIZE 80
#define BLE_STATUS_NOTIFY_BUFFER_SIZE 96

// ────────────────────────────────────────────────────────────
// LED & Hardware
// ────────────────────────────────────────────────────────────

#define LED_BUILTIN_LEVEL HIGH
#define LED_FLASH_DURATION_MS 30

#define SERIAL_BAUD_RATE 115200
#define SERIAL_INIT_DELAY_MS 200

// ────────────────────────────────────────────────────────────
// MQTT Configuration
// ────────────────────────────────────────────────────────────

#define MQTT_BROKER_PORT 1883
#define MQTT_BUFFER_SIZE 1024
#define MQTT_PUBLISH_BUFFER_SIZE 192

// ────────────────────────────────────────────────────────────
// Auto-Calibration Thresholds
// ────────────────────────────────────────────────────────────

#define CALIBRATION_LEVEL_CHANGE_THRESHOLD 20
#define CALIBRATION_MIN_CYCLE_INTERVAL_S 600
#define CALIBRATION_CONFIDENCE_MAX 90
#define CALIBRATION_CONFIDENCE_INCREMENT 10

// ────────────────────────────────────────────────────────────
// Timing Configuration
// ────────────────────────────────────────────────────────────

#define SENSOR_STARTUP_DELAY_MS 500
#define SENSOR_ERROR_RETRY_DELAY_MS 2000
#define WIFI_CONNECT_RETRY_DELAY_MS 500
#define COMMS_TASK_LOOP_DELAY_MS 500
#define BLE_TASK_LOOP_DELAY_MS 100
#define MAIN_LOOP_IDLE_DELAY_MS 10000

// ────────────────────────────────────────────────────────────
// Semaphore Timeouts
// ────────────────────────────────────────────────────────────

#define STATE_MUTEX_TIMEOUT_MS 50
#define STATE_MUTEX_TIMEOUT_LONG_MS 100

// ────────────────────────────────────────────────────────────
// Ultrasonic Sensor Configuration
// ────────────────────────────────────────────────────────────

#define SOUND_SPEED_CM_US 0.0343f
#define TRIG_PULSE_US 15
#define ECHO_TIMEOUT_US 30000UL

#define SENSOR_READINGS_PER_SAMPLE 5
#define SENSOR_READING_DELAY_MS 60
#define SENSOR_MIN_VALID_PULSES 3
#define SENSOR_MIN_DISTANCE_CM 20.0f
#define SENSOR_MAX_DISTANCE_CM 600.0f
#define SENSOR_WARNING_LOG_INTERVAL_MS 10000

#define SENSOR_ECHO_PRE_DELAY_US 4

// ────────────────────────────────────────────────────────────
// Kalman Filter Configuration
// ────────────────────────────────────────────────────────────

#define KF_Q 4.0f
#define KF_R 25.0f
#define KF_OUTLIER_SIGMA 3.0f
#define KF_MAX_REJECT_STREAK 6

// ────────────────────────────────────────────────────────────
// Consensus Confirmation Window
// ────────────────────────────────────────────────────────────

#define CONFIRM_N 3
#define CONFIRM_TOL_PERCENT 0.03f
#define CONFIRM_TOL_MIN_CM 5.0f

// ────────────────────────────────────────────────────────────
// Level Percentage Calculation
// ────────────────────────────────────────────────────────────

#define LEVEL_PERCENTAGE_SCALE 100.0f

// ────────────────────────────────────────────────────────────
// Pin Command Buffer Size
// ────────────────────────────────────────────────────────────

#define PIN_COMMAND_PARTIAL_JSON_SIZE 64

#endif
