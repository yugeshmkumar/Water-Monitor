import SwiftUI

/**
 * WiFiConfigStep — WiFi and node identification form
 *
 * Fields:
 * - WiFi SSID (network name)
 * - WiFi password with visibility toggle
 * - Node ID (device identifier)
 * - MQTT broker IP (optional)
 *
 * Isolated WiFi configuration UI. Used in ConfigWizardView.
 */
struct WiFiConfigStep: View {
    @Binding var config: DeviceConfig
    @State private var showPassword = false

    var body: some View {
        Form {
            Section("WiFi Credentials") {
                TextField("SSID", text: $config.wifiSSID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack {
                    if showPassword {
                        TextField("Password", text: $config.wifiPass)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Password", text: $config.wifiPass)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Node") {
                TextField("Node ID", text: $config.nodeID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                TextField("MQTT Broker IP (optional)", text: $config.mqttBrokerIP)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
    }
}

#Preview {
    @State var config = DeviceConfig()
    return WiFiConfigStep(config: $config)
}
