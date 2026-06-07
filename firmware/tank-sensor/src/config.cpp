#include "config.h"
#include <Preferences.h>

Config config;

static Preferences _prefs;

void Config::load() {
    _prefs.begin("config", true);

    strlcpy(d.wifi_ssid,        _prefs.getString("wifi_ssid", "").c_str(),       sizeof(d.wifi_ssid));
    strlcpy(d.wifi_pass,        _prefs.getString("wifi_pass", "").c_str(),       sizeof(d.wifi_pass));
    strlcpy(d.pin_trig,         _prefs.getString("pin_trig",  "D2").c_str(),     sizeof(d.pin_trig));
    strlcpy(d.pin_echo,         _prefs.getString("pin_echo",  "D1").c_str(),     sizeof(d.pin_echo));
    strlcpy(d.node_id,          _prefs.getString("node_id",   "sensor-a").c_str(), sizeof(d.node_id));
    strlcpy(d.mqtt_broker_ip,   _prefs.getString("mqtt_ip",   "").c_str(),       sizeof(d.mqtt_broker_ip));
    strlcpy(d.firmware_version, _prefs.getString("fw_ver",    "1.0.0").c_str(),  sizeof(d.firmware_version));

    d.tank_empty_cm   = _prefs.getFloat("tank_empty",  150.0f);
    d.tank_full_cm    = _prefs.getFloat("tank_full",    20.0f);
    d.tank_volume_l   = _prefs.getUInt ("tank_vol",     1000);
    d.alert_low_pct   = _prefs.getUInt ("alert_low",    15);
    d.alert_high_pct  = _prefs.getUInt ("alert_high",   95);
    d.poll_interval_s = _prefs.getUInt ("poll_int",     10);
    d.testing_mode    = _prefs.getBool ("testing_mode", false);
    d.test_poll_interval_s = _prefs.getUChar("test_poll_int", 3);

    _prefs.end();
}

void Config::save() {
    _prefs.begin("config", false);

    _prefs.putString("wifi_ssid", d.wifi_ssid);
    _prefs.putString("wifi_pass", d.wifi_pass);
    _prefs.putString("pin_trig",  d.pin_trig);
    _prefs.putString("pin_echo",  d.pin_echo);
    _prefs.putString("node_id",   d.node_id);
    _prefs.putString("mqtt_ip",   d.mqtt_broker_ip);
    _prefs.putString("fw_ver",    d.firmware_version);

    _prefs.putFloat("tank_empty", d.tank_empty_cm);
    _prefs.putFloat("tank_full",  d.tank_full_cm);
    _prefs.putUInt ("tank_vol",   d.tank_volume_l);
    _prefs.putUInt ("alert_low",  d.alert_low_pct);
    _prefs.putUInt ("alert_high", d.alert_high_pct);
    _prefs.putUInt ("poll_int",   d.poll_interval_s);
    _prefs.putBool ("testing_mode", d.testing_mode);
    _prefs.putUChar("test_poll_int", d.test_poll_interval_s);

    _prefs.end();
}

bool Config::applyPartialJson(const char* json) {
    JsonDocument doc;
    if (deserializeJson(doc, json) != DeserializationError::Ok) return false;

    if (!doc["wifi_ssid"].isNull())
        strlcpy(d.wifi_ssid, doc["wifi_ssid"].as<const char*>(), sizeof(d.wifi_ssid));
    if (!doc["wifi_pass"].isNull())
        strlcpy(d.wifi_pass, doc["wifi_pass"].as<const char*>(), sizeof(d.wifi_pass));
    if (!doc["pin_trig"].isNull())
        strlcpy(d.pin_trig, doc["pin_trig"].as<const char*>(), sizeof(d.pin_trig));
    if (!doc["pin_echo"].isNull())
        strlcpy(d.pin_echo, doc["pin_echo"].as<const char*>(), sizeof(d.pin_echo));
    if (!doc["node_id"].isNull())
        strlcpy(d.node_id, doc["node_id"].as<const char*>(), sizeof(d.node_id));
    if (!doc["mqtt_broker_ip"].isNull())
        strlcpy(d.mqtt_broker_ip, doc["mqtt_broker_ip"].as<const char*>(), sizeof(d.mqtt_broker_ip));

    bool calibrationUpdated = false;
    if (!doc["tank_empty_cm"].isNull()) {
        d.tank_empty_cm = doc["tank_empty_cm"].as<float>();
        calibrationUpdated = true;
    }
    if (!doc["tank_full_cm"].isNull()) {
        d.tank_full_cm = doc["tank_full_cm"].as<float>();
        calibrationUpdated = true;
    }

    // Validate only if calibration was being updated
    if (calibrationUpdated && fabsf(d.tank_empty_cm - d.tank_full_cm) < 1.0f) {
        Serial.println("[Config] WARNING: Invalid calibration (empty≈full). Rejecting calibration update.");
        return false;
    }
    
    // Validate tank distances are within sensor range (200-6000mm)
    if (d.tank_empty_cm < 20.0f || d.tank_empty_cm > 600.0f ||
        d.tank_full_cm < 20.0f || d.tank_full_cm > 600.0f) {
        Serial.printf("[Config] WARNING: Tank distances out of sensor range (200-6000mm). empty=%u, full=%u\n",
                      (uint16_t)(d.tank_empty_cm * 10), (uint16_t)(d.tank_full_cm * 10));
        // Continue anyway - user may have intentional configuration
    }
    
    if (!doc["tank_volume_l"].isNull())        d.tank_volume_l        = doc["tank_volume_l"].as<uint32_t>();
    if (!doc["alert_low_pct"].isNull())        d.alert_low_pct        = doc["alert_low_pct"].as<uint8_t>();
    if (!doc["alert_high_pct"].isNull())       d.alert_high_pct       = doc["alert_high_pct"].as<uint8_t>();
    if (!doc["poll_interval_s"].isNull())      d.poll_interval_s      = doc["poll_interval_s"].as<uint16_t>();
    if (!doc["testing_mode"].isNull())         d.testing_mode         = doc["testing_mode"].as<bool>();
    if (!doc["test_poll_interval_s"].isNull()) d.test_poll_interval_s = doc["test_poll_interval_s"].as<uint8_t>();
    if (!doc["auto_calibration_enabled"].isNull()) d.auto_calibration_enabled = doc["auto_calibration_enabled"].as<bool>();
    if (!doc["auto_cal_min_cm"].isNull())      d.auto_cal_min_cm      = doc["auto_cal_min_cm"].as<float>();
    if (!doc["auto_cal_max_cm"].isNull())      d.auto_cal_max_cm      = doc["auto_cal_max_cm"].as<float>();
    if (!doc["calibration_cycles"].isNull())   d.calibration_cycles   = doc["calibration_cycles"].as<uint16_t>();
    if (!doc["calibration_confidence"].isNull()) d.calibration_confidence = doc["calibration_confidence"].as<uint8_t>();

    save();
    return true;
}

void Config::toJson(JsonDocument& out) const {
    out["wifi_ssid"]               = d.wifi_ssid;
    out["wifi_pass"]               = d.wifi_pass;
    out["tank_empty_cm"]           = d.tank_empty_cm;
    out["tank_full_cm"]            = d.tank_full_cm;
    out["tank_volume_l"]           = d.tank_volume_l;
    out["alert_low_pct"]           = d.alert_low_pct;
    out["alert_high_pct"]          = d.alert_high_pct;
    out["poll_interval_s"]         = d.poll_interval_s;
    out["testing_mode"]            = d.testing_mode;
    out["test_poll_interval_s"]    = d.test_poll_interval_s;
    out["pin_trig"]                = d.pin_trig;
    out["pin_echo"]                = d.pin_echo;
    out["node_id"]                 = d.node_id;
    out["mqtt_broker_ip"]          = d.mqtt_broker_ip;
    out["firmware_version"]        = d.firmware_version;
    out["auto_calibration_enabled"] = d.auto_calibration_enabled;
    out["auto_cal_min_cm"]         = d.auto_cal_min_cm;
    out["auto_cal_max_cm"]         = d.auto_cal_max_cm;
    out["calibration_cycles"]      = d.calibration_cycles;
    out["calibration_confidence"]  = d.calibration_confidence;
}

void Config::toJsonString(char* buf, size_t len) const {
    JsonDocument doc;
    toJson(doc);
    serializeJson(doc, buf, len);
}
