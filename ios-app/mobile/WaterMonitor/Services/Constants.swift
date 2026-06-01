import Foundation

/// Centralized configuration constants for the app
enum NetworkConstants {
    static let wifiTimeout: TimeInterval = 8
    static let wifiResourceTimeout: TimeInterval = 20
    static let webSocketTimeout: TimeInterval = 30
    static let webSocketResourceTimeout: TimeInterval = 180
    static let webSocketPingInterval: TimeInterval = 30
    
    static let bleConfigReadDelay: TimeInterval = 0.5
    static let bleConfigWriteEchoDelay: TimeInterval = 0.8
    
    static let connectionRetryDelay: TimeInterval = 2
    static let maxConnectionRetries: Int = 3
}

enum HealthConstants {
    static let healthyPollInterval: TimeInterval = 15       // Normal: 15s
    static let degradedPollInterval: TimeInterval = 60      // Degraded: 1 min
    static let unhealthyPollInterval: TimeInterval = 300    // Offline: 5 min
    static let backgroundPollInterval: TimeInterval = 60    // Background: 1 min
    static let maxFailuresBeforeSlow: Int = 3
}

enum TestModeConstants {
    static let minInterval: Int = 1
    static let maxInterval: Int = 15
    static let defaultInterval: Int = 3
}

enum CalibrationConstants {
    static let stabilityThreshold: Double = 1.0  // cm
    static let minStabilityScore: Int = 2
    static let minRangeForValidation: Double = 5.0  // cm
    static let maxReadingsForStability: Int = 10
    static let stabilityCheckInterval: Int = 500  // milliseconds - how often to check stability
}

enum DeviceLimits {
    static let maxMotorControllers: Int = 10
    static let maxWaterMonitors: Int = 40
    static let maxTotalDevices: Int = 50
}
