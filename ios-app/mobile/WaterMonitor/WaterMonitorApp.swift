import SwiftUI
import SwiftData

@main
struct WaterMonitorApp: App {
    let modelContainer: ModelContainer
    let connectionManager = ConnectionManager()
    
    init() {
        // Initialize SwiftData
        do {
            modelContainer = try ModelContainer(
                for: SavedDevice.self, DeviceReading.self
            )
        } catch {
            print("[App] Failed to load database: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // ✅ Migrate database if needed
        DatabaseMigrationManager.migrateIfNeeded(
            modelContext: modelContainer.mainContext
        )
        
        // ✅ Configure background tasks
        BackgroundTaskManager.shared.configure(
            connectionManager: connectionManager
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionManager)
                .modelContainer(modelContainer)
                .onAppear {
                    // ✅ Restore devices from backup if needed
                    _ = DatabaseMigrationManager.restoreFromBackup(
                        modelContext: modelContainer.mainContext
                    )
                }
        }
    }
}