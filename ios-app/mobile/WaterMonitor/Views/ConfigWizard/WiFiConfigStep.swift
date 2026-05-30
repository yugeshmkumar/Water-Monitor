import SwiftUI

/// WiFi configuration step for ConfigWizardView
struct WiFiConfigStep: View {
    @State private var ssid = ""
    @State private var password = ""
    @State private var showPassword = false
    var onNext: (String, String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("WiFi Setup")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name (SSID)")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Enter SSID", text: $ssid)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack {
                    if showPassword {
                        TextField("Enter password", text: $password)
                    } else {
                        SecureField("Enter password", text: $password)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            Button(action: { onNext(ssid, password) }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(ssid.isEmpty || password.isEmpty)
        }
        .padding()
    }
}

#Preview {
    WiFiConfigStep { _, _ in }
}
