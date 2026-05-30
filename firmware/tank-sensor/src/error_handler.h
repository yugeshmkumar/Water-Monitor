#pragma once

#include <Arduino.h>

/**
 * Error codes for the system
 */
enum ErrorCode {
    ERROR_NONE = 0,
    ERROR_SENSOR_FAILURE = 1,
    ERROR_WIFI_CONNECT_FAILED = 2,
    ERROR_API_CALL_FAILED = 3,
    ERROR_BLE_FAILURE = 4,
    ERROR_QUEUE_FULL = 5,
    ERROR_CONFIG_LOAD_FAILED = 6,
    ERROR_MEMORY_INSUFFICIENT = 7
};

/**
 * Error handler - logs and tracks errors
 */
class ErrorHandler {
private:
    int error_count;
    ErrorCode last_error;
    unsigned long last_error_time;
    
public:
    ErrorHandler();
    
    /**
     * Log an error with context
     * @param code - Error code
     * @param message - Human-readable error message
     * @param recovery - Optional recovery action
     */
    void log_error(ErrorCode code, const char* message, const char* recovery = nullptr);
    
    /**
     * Get last error code
     */
    ErrorCode get_last_error() const;
    
    /**
     * Get error count
     */
    int get_error_count() const;
    
    /**
     * Reset error counter
     */
    void reset_error_count();
    
    /**
     * Check if in error state
     */
    bool has_errors() const;
};

extern ErrorHandler gErrorHandler;

