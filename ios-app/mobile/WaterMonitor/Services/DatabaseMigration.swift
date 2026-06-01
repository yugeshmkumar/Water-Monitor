import Foundation
import SwiftData

/// Handles database migration and corruption recovery
enum DatabaseMigrationManager {
    
    // MARK: - Migration Entry Point
    
    static func migrateIfNeeded(modelContext: ModelContext) {
        do {
            // Test if database is accessible
            let descriptor = FetchDescriptor<SavedDevice>()
            _ = try modelContext.fetch(descriptor)
            print("[Migration] Database healthy, no migration needed")
        } catch {
            print("[Migration] Database error detected: \(error)")
            handleCorruptedDatabase(modelContext: modelContext, error: error)
        }
    }
    
    // MARK: - Corruption Recovery
    
    private static func handleCorruptedDatabase(modelContext: ModelContext, error: Error) {
        print("[Migration] Attempting to recover database...")
        
        // Show alert to user
        NotificationService.shared.sendImmediate(
            title: "Database Recovery",
            body: "App data is being recovered. Your devices may need to be re-added.",
            critical: false
        )
        
        // Try to export what we can
        backupRecoverableData(modelContext: modelContext)
        
        // Reset database (nuclear option)
        do {
            try modelContext.delete(model: SavedDevice.self)
            try modelContext.delete(model: DeviceReading.self)
            try modelContext.save()
            print("[Migration] Database reset complete")
        } catch {
            print("[Migration] Failed to reset database: \(error)")
            // Last resort: log error for debugging
            fatalError("Database is corrupted and cannot be recovered: \(error)")
        }
    }
    
    // MARK: - Backup & Restore
    
    private static func backupRecoverableData(modelContext: ModelContext) {
        // Store device list in UserDefaults as backup
        do {
            let devices = try modelContext.fetch(FetchDescriptor<SavedDevice>())
            let deviceData = devices.map { [
                "nodeID": $0.nodeID,
                "displayName": $0.displayName,
                "lastIP": $0.lastIP ?? "",
                "lastHost": $0.lastHost
            ] }
            
            UserDefaults.standard.set(deviceData, forKey: "backup_devices")
            print("[Migration] Backed up \(devices.count) devices to UserDefaults")
        } catch {
            print("[Migration] Could not backup devices: \(error)")
        }
    }
    
    static func restoreFromBackup(modelContext: ModelContext) -> [SavedDevice] {
        guard let backup = UserDefaults.standard.array(forKey: "backup_devices") as? [[String: String]] else {
            print("[Migration] No backup found")
            return []
        }
        
        var restored: [SavedDevice] = []
        for data in backup {
            guard let nodeID = data["nodeID"],
                  let displayName = data["displayName"],
                  let lastHost = data["lastHost"] else { continue }
            
            let device = SavedDevice(
                nodeID: nodeID,
                displayName: displayName,
                lastHost: lastHost,
                lastIP: data["lastIP"]?.isEmpty == false ? data["lastIP"] : nil
            )
            
            modelContext.insert(device)
            restored.append(device)
        }
        
        do {
            try modelContext.save()
            UserDefaults.standard.removeObject(forKey: "backup_devices")
            print("[Migration] Restored \(restored.count) devices from backup")
        } catch {
            print("[Migration] Failed to save restored devices: \(error)")
        }
        
        return restored
    }
    
    // MARK: - Version Migration (Future Use)
    
    static func migrateToVersion2(modelContext: ModelContext) {
        // Example: Add new fields to SavedDevice in future versions
        print("[Migration] Migrating to version 2...")
        
        do {
            let devices = try modelContext.fetch(FetchDescriptor<SavedDevice>())
            for _ in devices {
                // Apply migrations here
                // Example: device.newField = defaultValue
            }
            try modelContext.save()
            print("[Migration] Version 2 migration complete")
        } catch {
            print("[Migration] Version 2 migration failed: \(error)")
        }
    }
    
    // MARK: - Data Integrity Checks
    
    static func validateDataIntegrity(modelContext: ModelContext) -> Bool {
        do {
            // Check SavedDevice table
            let devices = try modelContext.fetch(FetchDescriptor<SavedDevice>())
            print("[Migration] Found \(devices.count) saved devices")
            
            // Check for duplicates
            let uniqueNodeIDs = Set(devices.map { $0.nodeID })
            if uniqueNodeIDs.count != devices.count {
                print("[Migration] ⚠️ Warning: Duplicate nodeIDs detected")
                removeDuplicateDevices(modelContext: modelContext, devices: devices)
            }
            
            // Check DeviceReading table
            let readings = try modelContext.fetch(FetchDescriptor<DeviceReading>())
            print("[Migration] Found \(readings.count) device readings")
            
            return true
        } catch {
            print("[Migration] Data integrity check failed: \(error)")
            return false
        }
    }
    
    private static func removeDuplicateDevices(modelContext: ModelContext, devices: [SavedDevice]) {
        var seen: Set<String> = []
        var toDelete: [SavedDevice] = []
        
        for device in devices {
            if seen.contains(device.nodeID) {
                toDelete.append(device)
            } else {
                seen.insert(device.nodeID)
            }
        }
        
        for device in toDelete {
            modelContext.delete(device)
            print("[Migration] Removed duplicate device: \(device.nodeID)")
        }
        
        do {
            try modelContext.save()
            print("[Migration] Removed \(toDelete.count) duplicate devices")
        } catch {
            print("[Migration] Failed to remove duplicates: \(error)")
        }
    }
    
    // MARK: - Cleanup Old Data
    
    static func cleanupOldReadings(modelContext: ModelContext, olderThan days: Int = 90) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        do {
            var descriptor = FetchDescriptor<DeviceReading>()
            descriptor.predicate = #Predicate { reading in
                reading.timestamp < cutoffDate
            }
            
            let oldReadings = try modelContext.fetch(descriptor)
            
            for reading in oldReadings {
                modelContext.delete(reading)
            }
            
            try modelContext.save()
            print("[Migration] Deleted \(oldReadings.count) readings older than \(days) days")
        } catch {
            print("[Migration] Failed to cleanup old readings: \(error)")
        }
    }
}
