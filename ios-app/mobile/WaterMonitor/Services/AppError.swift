import Foundation

/// Unified error types for the app
enum AppError: LocalizedError {
    case deviceNotFound(nodeID: String)
    case connectionFailed(host: String, reason: String)
    case configurationFailed(reason: String)
    case calibrationFailed(reason: String)
    case firmwareError(message: String)
    case timeout
    case invalidData
    case networkUnavailable
    case maxDevicesReached
    case databaseError(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Device '\(id)' not found"
        case .connectionFailed(let host, let reason):
            return "Failed to connect to \(host): \(reason)"
        case .configurationFailed(let reason):
            return "Configuration failed: \(reason)"
        case .calibrationFailed(let reason):
            return "Calibration failed: \(reason)"
        case .firmwareError(let msg):
            return "Device error: \(msg)"
        case .timeout:
            return "Connection timed out"
        case .invalidData:
            return "Received invalid data from device"
        case .networkUnavailable:
            return "Network is unavailable"
        case .maxDevicesReached:
            return "Maximum device limit reached (\(DeviceLimits.maxTotalDevices))"
        case .databaseError(let reason):
            return "Database error: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Make sure the device is powered on and try again."
        case .connectionFailed:
            return "Check WiFi connection and device power."
        case .configurationFailed:
            return "Try reconnecting to the device."
        case .calibrationFailed:
            return "Ensure water level is stable and sensor is working."
        case .firmwareError:
            return "Restart the device or check sensor connections."
        case .timeout:
            return "Check network connection and try again."
        case .invalidData:
            return "This might be a firmware issue. Try updating firmware."
        case .networkUnavailable:
            return "Connect to WiFi and try again."
        case .maxDevicesReached:
            return "Remove unused devices before adding new ones."
        case .databaseError:
            return "App data may be corrupted. Try restarting the app."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .timeout, .networkUnavailable, .connectionFailed:
            return true
        case .databaseError, .invalidData:
            return false
        default:
            return true
        }
    }
}
