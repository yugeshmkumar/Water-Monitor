import SwiftUI

struct WelcomeView: View {
    var onAddDevice: () -> Void

    @State private var showAddDevice = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Water Monitor")
                        .font(.largeTitle.bold())

                    Text("Monitor your tank levels from anywhere")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Button {
                    showAddDevice = true
                } label: {
                    Text("Add Your First Sensor")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(onComplete: onAddDevice)
        }
    }
}
