import SwiftUI
import SwiftData

@main
struct WaterMonitorApp: App {
    @State private var connectionManager = ConnectionManager()
    @State private var notificationManager = NotificationManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DeviceReading.self,
            SavedDevice.self,
            Tank.self,
            MotorGroup.self,
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("❌ ModelContainer creation failed: \(error)")

            // Schema mismatch — delete old store and recreate
            // (development only; in production, implement proper migration)
            try? FileManager.default.removeItem(at: config.url)
            print("🔄 Deleted old data store, will recreate with new schema")

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionManager)
                .environment(notificationManager)
                .onAppear {
                    let cache = DataCache(context: sharedModelContainer.mainContext)
                    connectionManager.configure(dataCache: cache)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
