//
//  Persistence.swift
//  Track It
//
//  Created by Arvoldek on 07/06/2026.
//

import CoreData

/// Core Data stack manager
final class PersistenceController {
    /// Shared instance for singleton access
    static let shared = PersistenceController()
    
    /// CloudKit container for iCloud sync
    let container: NSPersistentCloudKitContainer
    
    /// Main context for UI operations
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Background context for async operations
    var backgroundContext: NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// Initializer with iCloud support
    init(inMemory: Bool = false) {
        // Configure the container with the data model
        container = NSPersistentCloudKitContainer(name: "TrackIt")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure iCloud options
        if let description = container.persistentStoreDescriptions.first {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.arvoldek.TrackIt"
            )
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                // You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \{error\}, \{error.userInfo\}")
            }
        }
        
        // Enable automatic sync with iCloud
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// Save changes to the view context
    /// - Returns: Success status
    @discardableResult
    func save() -> Bool {
        guard viewContext.hasChanges else { return true }
        
        do {
            try viewContext.save()
            return true
        } catch {
            let nserror = error as NSError
            // Rollback changes if save fails
            viewContext.rollback()
            print("Core Data save failed: \{nserror\}, \{nserror.userInfo\}")
            return false
        }
    }
    
    /// Save changes in a background context
    /// - Parameter context: The background context
    /// - Returns: Success status
    @discardableResult
    func save(context: NSManagedObjectContext) -> Bool {
        guard context.hasChanges else { return true }
        
        do {
            try context.save()
            return true
        } catch {
            let nserror = error as NSError
            context.rollback()
            print("Core Data background save failed: \{nserror\}, \{nserror.userInfo\}")
            return false
        }
    }
    
    /// Perform a background task
    /// - Parameter block: The closure to execute in the background
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            block(context)
            _ = self.save(context: context)
        }
    }
    
    /// Delete an object
    /// - Parameter object: The object to delete
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        _ = save()
    }
    
    /// Delete multiple objects
    /// - Parameter objects: The objects to delete
    func delete(_ objects: [NSManagedObject]) {
        for object in objects {
            viewContext.delete(object)
        }
        _ = save()
    }
}
