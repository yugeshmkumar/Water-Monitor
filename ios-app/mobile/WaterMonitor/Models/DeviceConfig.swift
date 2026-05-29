import Foundation

struct DeviceConfig: Equatable {
    var wifiSSID: String = ""
    var wifiPass: String = ""
    var tankEmptyCM: Double = 150
    var tankFullCM: Double = 20
    var tankVolumeL: Int = 1000
    var alertLowPct: Int = 15
    var alertHighPct: Int = 95
    var pollIntervalS: Int = 30         // Normal polling: 15s–15min (default 30s)
    var testingMode: Bool = false       // When true, use testPollIntervalS instead
    var testPollIntervalS: Int = 3      // Test polling: 1s–10s (default 3s)
    var pinTrig: String = "D2"
    var pinEcho: String = "D1"
    var nodeID: String = "sensor-a"
    var mqttBrokerIP: String = ""
    var firmwareVersion: String = "?"
    // Auto-calibration tracking
    var autoCalibrationEnabled: Bool = false
    var autoCalMinCM: Double = 999      // Detected minimum
    var autoCalMaxCM: Double = -1       // Detected maximum
    var calibrationCycles: Int = 0      // Fill/drain events seen
    var calibrationConfidence: Int = 0  // 0-100%
    // Runtime-only: populated from device but never written back via patch()
    var ip: String = ""
    var mac: String = ""
    var hostname: String = ""

    enum CodingKeys: String, CodingKey {
        case wifiSSID = "wifi_ssid"
        case wifiPass = "wifi_pass"
        case tankEmptyCM = "tank_empty_cm"
        case tankFullCM = "tank_full_cm"
        case tankVolumeL = "tank_volume_l"
        case alertLowPct = "alert_low_pct"
        case alertHighPct = "alert_high_pct"
        case pollIntervalS = "poll_interval_s"
        case testingMode = "testing_mode"
        case testPollIntervalS = "test_poll_interval_s"
        case pinTrig = "pin_trig"
        case pinEcho = "pin_echo"
        case nodeID = "node_id"
        case mqttBrokerIP = "mqtt_broker_ip"
        case firmwareVersion = "firmware_version"
        case autoCalibrationEnabled = "auto_calibration_enabled"
        case autoCalMinCM = "auto_cal_min_cm"
        case autoCalMaxCM = "auto_cal_max_cm"
        case calibrationCycles = "calibration_cycles"
        case calibrationConfidence = "calibration_confidence"
        case ip, mac, hostname
    }

    func patch(from edited: DeviceConfig) -> [String: Any] {
        var diff: [String: Any] = [:]
        if edited.wifiSSID              != wifiSSID              { diff["wifi_ssid"]                  = edited.wifiSSID }
        if edited.wifiPass              != wifiPass              { diff["wifi_pass"]                  = edited.wifiPass }
        if edited.tankEmptyCM           != tankEmptyCM           { diff["tank_empty_cm"]              = edited.tankEmptyCM }
        if edited.tankFullCM            != tankFullCM            { diff["tank_full_cm"]               = edited.tankFullCM }
        if edited.tankVolumeL           != tankVolumeL           { diff["tank_volume_l"]              = edited.tankVolumeL }
        if edited.alertLowPct           != alertLowPct           { diff["alert_low_pct"]              = edited.alertLowPct }
        if edited.alertHighPct          != alertHighPct          { diff["alert_high_pct"]             = edited.alertHighPct }
        if edited.pollIntervalS         != pollIntervalS         { diff["poll_interval_s"]            = edited.pollIntervalS }
        if edited.testingMode           != testingMode           { diff["testing_mode"]               = edited.testingMode }
        if edited.testPollIntervalS     != testPollIntervalS     { diff["test_poll_interval_s"]      = edited.testPollIntervalS }
        if edited.pinTrig               != pinTrig               { diff["pin_trig"]                   = edited.pinTrig }
        if edited.pinEcho               != pinEcho               { diff["pin_echo"]                   = edited.pinEcho }
        if edited.nodeID                != nodeID                { diff["node_id"]                    = edited.nodeID }
        if edited.mqttBrokerIP          != mqttBrokerIP          { diff["mqtt_broker_ip"]             = edited.mqttBrokerIP }
        if edited.autoCalibrationEnabled != autoCalibrationEnabled { diff["auto_calibration_enabled"] = edited.autoCalibrationEnabled }
        if edited.calibrationCycles     != calibrationCycles     { diff["calibration_cycles"]         = edited.calibrationCycles }
        if edited.calibrationConfidence != calibrationConfidence { diff["calibration_confidence"]    = edited.calibrationConfidence }
        return diff
    }
}

// MARK: - Codable with default values
extension DeviceConfig: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        wifiSSID = try container.decodeIfPresent(String.self, forKey: .wifiSSID) ?? ""
        wifiPass = try container.decodeIfPresent(String.self, forKey: .wifiPass) ?? ""
        tankEmptyCM = try container.decodeIfPresent(Double.self, forKey: .tankEmptyCM) ?? 150
        tankFullCM = try container.decodeIfPresent(Double.self, forKey: .tankFullCM) ?? 20
        tankVolumeL = try container.decodeIfPresent(Int.self, forKey: .tankVolumeL) ?? 1000
        alertLowPct = try container.decodeIfPresent(Int.self, forKey: .alertLowPct) ?? 15
        alertHighPct = try container.decodeIfPresent(Int.self, forKey: .alertHighPct) ?? 95
        pollIntervalS = try container.decodeIfPresent(Int.self, forKey: .pollIntervalS) ?? 30
        testingMode = try container.decodeIfPresent(Bool.self, forKey: .testingMode) ?? false
        testPollIntervalS = try container.decodeIfPresent(Int.self, forKey: .testPollIntervalS) ?? 3
        pinTrig = try container.decodeIfPresent(String.self, forKey: .pinTrig) ?? "D2"
        pinEcho = try container.decodeIfPresent(String.self, forKey: .pinEcho) ?? "D1"
        nodeID = try container.decodeIfPresent(String.self, forKey: .nodeID) ?? "sensor-a"
        mqttBrokerIP = try container.decodeIfPresent(String.self, forKey: .mqttBrokerIP) ?? ""
        firmwareVersion = try container.decodeIfPresent(String.self, forKey: .firmwareVersion) ?? "?"
        autoCalibrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoCalibrationEnabled) ?? false
        autoCalMinCM = try container.decodeIfPresent(Double.self, forKey: .autoCalMinCM) ?? 999
        autoCalMaxCM = try container.decodeIfPresent(Double.self, forKey: .autoCalMaxCM) ?? -1
        calibrationCycles = try container.decodeIfPresent(Int.self, forKey: .calibrationCycles) ?? 0
        calibrationConfidence = try container.decodeIfPresent(Int.self, forKey: .calibrationConfidence) ?? 0
        ip = try container.decodeIfPresent(String.self, forKey: .ip) ?? ""
        mac = try container.decodeIfPresent(String.self, forKey: .mac) ?? ""
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(wifiSSID, forKey: .wifiSSID)
        try container.encode(wifiPass, forKey: .wifiPass)
        try container.encode(tankEmptyCM, forKey: .tankEmptyCM)
        try container.encode(tankFullCM, forKey: .tankFullCM)
        try container.encode(tankVolumeL, forKey: .tankVolumeL)
        try container.encode(alertLowPct, forKey: .alertLowPct)
        try container.encode(alertHighPct, forKey: .alertHighPct)
        try container.encode(pollIntervalS, forKey: .pollIntervalS)
        try container.encode(testingMode, forKey: .testingMode)
        try container.encode(testPollIntervalS, forKey: .testPollIntervalS)
        try container.encode(pinTrig, forKey: .pinTrig)
        try container.encode(pinEcho, forKey: .pinEcho)
        try container.encode(nodeID, forKey: .nodeID)
        try container.encode(mqttBrokerIP, forKey: .mqttBrokerIP)
        try container.encode(firmwareVersion, forKey: .firmwareVersion)
        try container.encode(autoCalibrationEnabled, forKey: .autoCalibrationEnabled)
        try container.encode(autoCalMinCM, forKey: .autoCalMinCM)
        try container.encode(autoCalMaxCM, forKey: .autoCalMaxCM)
        try container.encode(calibrationCycles, forKey: .calibrationCycles)
        try container.encode(calibrationConfidence, forKey: .calibrationConfidence)
        try container.encode(ip, forKey: .ip)
        try container.encode(mac, forKey: .mac)
        try container.encode(hostname, forKey: .hostname)
    }
}
