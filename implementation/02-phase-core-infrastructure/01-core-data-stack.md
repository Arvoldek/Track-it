# Phase 2: Core Data Stack

## Overview

This document details the Core Data stack implementation for the Track It application, including persistence controller, model versioning, and iCloud synchronization setup.

## 1. Core Data Stack Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                          │
│  SwiftUI Views, ViewModels                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                               │
│  Tracker, Reminder, History, Settings models                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Repositories                           │  │
│  │  CoreDataTrackerRepository                              │  │
│  │  UserDefaultsSettingsRepository                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Persistence Controller                 │  │
│  │  - NSPersistentContainer (with iCloud)                  │  │
│  │  - Managed Object Context                               │  │
│  │  - Save/Load operations                                 │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Core Data Stack                         │  │
│  │  - NSPersistentStoreCoordinator                         │  │
│  │  - NSPersistentStore (SQLite)                            │  │
│  │  - NSManagedObjectModel                                 │  │
│  │  - NSPersistentCloudKitContainer (iCloud sync)          │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 2. Persistence Controller

### 2.1 PersistenceController Implementation

```swift
// PersistenceController.swift
import CoreData
import CloudKit

final class PersistenceController {
    
    // MARK: - Properties
    
    let container: NSPersistentContainer
    let context: NSManagedObjectContext
    
    private let containerName: String
    private let cloudKitContainerOptions: CloudKitContainerOptions?
    
    // MARK: - Initialization
    
    init(
        containerName: String = "TrackIt",
        cloudKitContainerOptions: CloudKitContainerOptions? = CloudKitContainerOptions()
    ) {
        self.containerName = containerName
        self.cloudKitContainerOptions = cloudKitContainerOptions
        
        // Create the persistent container
        container = NSPersistentContainer(name: containerName)
        
        // Configure the store description
        configureStoreDescription()
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure the view context
        configureViewContext()
        
        // Set up iCloud notifications
        setupCloudKitNotifications()
    }
    
    // MARK: - Configuration
    
    private func configureStoreDescription() {
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        // Enable automatic migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Configure for iCloud
        if let cloudKitOptions = cloudKitContainerOptions {
            description.cloudKitContainerOptions = cloudKitOptions
        }
        
        // Enable history tracking for change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Configure SQLite pragmas for better performance
        description.setOption("DELETE" as NSNumber, forKey: NSSQLiteManualVacuumPragmaKey)
        description.setOption("WAL" as NSNumber, forKey: NSSQLiteJournalingModePragmaKey)
        description.setOption("EXCLUSIVE" as NSNumber, forKey: NSSQLiteSynchronousPragmaKey)
    }
    
    private func loadPersistentStores() {
        container.loadPersistentStores { description, error in
            if let error = error {
                // This is a fatal error in development
                // In production, we might want to handle this more gracefully
                #if DEBUG
                fatalError("Unable to load persistent stores: \(error)")
                #else
                Logger.shared.error("Unable to load persistent stores: %{private}@", error.localizedDescription)
                #endif
            }
            
            // Configure the context after stores are loaded
            self.configureContexts()
        }
    }
    
    private func configureViewContext() {
        context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        
        // Observe changes in the view context
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: context
        )
    }
    
    private func configureContexts() {
        // Configure all contexts in the container
        for store in container.persistentStoreCoordinator.persistentStores {
            if let sqliteStore = store as? NSSQLiteStore {
                // Configure SQLite-specific options
                do {
                    try sqliteStore.setOption(
                        true as NSNumber,
                        forKey: NSSQLiteAnalyzePragmaKey
                    )
                } catch {
                    Logger.shared.warning("Failed to set SQLite options: %{private}@", error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - iCloud Setup
    
    private func setupCloudKitNotifications() {
        // Observe CloudKit account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitAccountDidChange(_:)),
            name: NSNotification.Name.NSUbiquitousKeyValueStoreDidChangeExternally,
            object: nil
        )
        
        // Observe CloudKit errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitError(_:)),
            name: Notification.Name("NSPersistentCloudKitContainerEventNotification"),
            object: nil
        )
    }
    
    // MARK: - Save Operations
    
    /// Save changes in the view context
    func save() throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            Logger.shared.debug("Context saved successfully")
        } catch {
            // Roll back the changes on error
            context.rollback()
            Logger.shared.error("Failed to save context: %{private}@", error.localizedDescription)
            throw error
        }
    }
    
    /// Save changes in a background context
    func save(in context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            Logger.shared.debug("Background context saved successfully")
        } catch {
            context.rollback()
            Logger.shared.error("Failed to save background context: %{private}@", error.localizedDescription)
            throw error
        }
    }
    
    /// Save changes and wait for completion
    @discardableResult
    func saveAndWait() throws -> Bool {
        var result = false
        
        let semaphore = DispatchSemaphore(value: 0)
        
        performBackgroundTask { context in
            do {
                try context.save()
                result = true
            } catch {
                Logger.shared.error("Failed to save: %{private}@", error.localizedDescription)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // MARK: - Background Operations
    
    /// Perform a task in a background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            // Configure the background context
            context.automaticallyMergesChangesFromParent = false
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            block(context)
            
            // Save the background context
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                Logger.shared.error("Failed to save background context: %{private}@", error.localizedDescription)
            }
        }
    }
    
    /// Perform a blocking background task
    func performAndWait<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) rethrows -> T {
        var result: T?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        performBackgroundTask { context in
            do {
                result = try block(context)
            } catch {
                self.error = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        guard let result = result else {
            throw PersistenceError.unknown
        }
        
        return result
    }
    
    // MARK: - Delete Operations
    
    /// Delete all objects of a specific entity type
    func deleteAll<T: NSManagedObject>(_ entity: T.Type) throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: String(describing: entity))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        // Execute in a background context
        try performAndWait { context in
            try context.execute(deleteRequest)
        }
    }
    
    /// Delete a specific object
    func delete(_ object: NSManagedObject) {
        context.delete(object)
    }
    
    /// Delete objects matching a predicate
    func delete<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate) throws {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = predicate
        
        let objects = try context.fetch(fetchRequest)
        
        for object in objects {
            context.delete(object)
        }
        
        try save()
    }
    
    // MARK: - Fetch Operations
    
    /// Fetch all objects of a specific entity type
    func fetch<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [T] {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        
        if let sortDescriptors = sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetch objects in batches (for large datasets)
    func fetchBatch<T: NSManagedObject>(
        _ entity: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        batchSize: Int = 100,
        completion: @escaping ([T]) -> Bool
    ) rethrows {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchBatchSize = batchSize
        fetchRequest.fetchLimit = batchSize
        
        var offset = 0
        var shouldContinue = true
        
        repeat {
            fetchRequest.fetchOffset = offset
            
            let results = try context.fetch(fetchRequest)
            
            if results.isEmpty {
                shouldContinue = false
            } else {
                shouldContinue = completion(results)
                offset += batchSize
            }
        } while shouldContinue
    }
    
    /// Count objects matching a predicate
    func count<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil) throws -> Int {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = predicate
        
        return try context.count(for: fetchRequest)
    }
    
    /// Check if any objects exist matching a predicate
    func exists<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil) -> Bool {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            return false
        }
    }
    
    // MARK: - Object Operations
    
    /// Create a new object in the context
    func create<T: NSManagedObject>() -> T {
        T(context: context)
    }
    
    /// Get an object by ID
    func get<T: NSManagedObject>(_ entity: T.Type, id: UUID) -> T? {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            Logger.shared.error("Failed to fetch object with id \(id): %{private}@", error.localizedDescription)
            return nil
        }
    }
    
    /// Get objects by IDs
    func get<T: NSManagedObject>(_ entity: T.Type, ids: [UUID]) -> [T] {
        let fetchRequest: NSFetchRequest<T> = T.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids as CVarArg)
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            Logger.shared.error("Failed to fetch objects: %{private}@", error.localizedDescription)
            return []
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        if context === self.context {
            // This is our view context, changes have been saved
            Logger.shared.debug("View context did save")
        } else if let parentContext = context.parent {
            // Merge changes from child contexts
            Logger.shared.debug("Child context did save, merging changes to parent")
        }
    }
    
    @objc private func cloudKitAccountDidChange(_ notification: Notification) {
        Logger.shared.info("CloudKit account did change")
        
        // Handle account changes (e.g., user switched iCloud accounts)
        // This might require re-syncing data
    }
    
    @objc private func cloudKitError(_ notification: Notification) {
        Logger.shared.error("CloudKit error: %{private}@", notification.userInfo ?? [:])
    }
    
    // MARK: - iCloud Management
    
    /// Enable iCloud synchronization
    func enableCloudSync() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        if description.cloudKitContainerOptions == nil {
            description.cloudKitContainerOptions = cloudKitContainerOptions
        }
        
        // Migrate existing data to iCloud
        migrateToCloud()
    }
    
    /// Disable iCloud synchronization
    func disableCloudSync() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        description.cloudKitContainerOptions = nil
    }
    
    /// Check if iCloud is available
    var isCloudSyncAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    /// Check if iCloud is enabled
    var isCloudSyncEnabled: Bool {
        container.persistentStoreDescriptions.first?.cloudKitContainerOptions != nil
    }
    
    // MARK: - Migration
    
    private func migrateToCloud() {
        Logger.shared.info("Starting migration to iCloud")
        
        // This is handled automatically by Core Data when cloudKitContainerOptions is set
        // but we can trigger a migration if needed
        
        do {
            try container.persistentStoreCoordinator.migratePersistentStore(
                container.persistentStoreCoordinator.persistentStores.first!,
                to: container.persistentStoreDescriptions.first!,
                options: nil,
                withType: NSSQLiteStoreType
            )
            Logger.shared.info("Migration to iCloud completed")
        } catch {
            Logger.shared.error("Migration to iCloud failed: %{private}@", error.localizedDescription)
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Error Types

enum PersistenceError: Error, LocalizedError {
    case unknown
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        }
    }
}

// MARK: - CloudKitContainerOptions

struct CloudKitContainerOptions {
    let containerIdentifier: String
    let databaseScope: CKDatabase.Scope
    
    init(
        containerIdentifier: String = "iCloud.com.arvoldek.TrackIt",
        databaseScope: CKDatabase.Scope = .private
    ) {
        self.containerIdentifier = containerIdentifier
        self.databaseScope = databaseScope
    }
}
```

### 2.2 CloudKitContainerOptions Extension

```swift
// CloudKitContainerOptions+CKContainerOptions.swift
import CloudKit

exension CloudKitContainerOptions {
    var ckContainerOptions: CKContainerOptions {
        CKContainerOptions(databaseScope: databaseScope)
    }
    
    var nsPersistentCloudKitContainerOptions: NSPersistentCloudKitContainerOptions {
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        options.databaseScope = databaseScope
        return options
    }
}
```

## 3. Core Data Model File

### 3.1 TrackIt.xcdatamodeld

Create a Core Data model file named `TrackIt.xcdatamodeld` with the following entities:

#### Entity: TrackerEntity

| Property | Type | Optional | Indexed | Default | Notes |
|----------|------|----------|---------|---------|-------|
| id | UUID | NO | YES | UUID() | Unique identifier |
| name | String | NO | NO | "" | Tracker name |
| type | String | NO | YES | "streak" | TrackerType rawValue |
| isCompleted | Boolean | NO | NO | NO | Current state |
| completionCount | Integer 64 | NO | NO | 0 | Total completions |
| targetCount | Integer 64 | NO | NO | 1 | Target count |
| completionFrequency | String | NO | NO | "once" | CompletionFrequency rawValue |
| autoCompleteDays | Transformable | YES | NO | nil | Set<DayOfWeek> as Data |
| createdAt | Date | NO | YES | now() | Creation timestamp |
| updatedAt | Date | NO | YES | now() | Last update timestamp |
| lastCompletedAt | Date | YES | NO | nil | Last completion timestamp |

**Relationships:**
- **reminder**: To One, ReminderEntity, Nullify, No inverse
- **histories**: To Many, TrackerHistoryEntity, Cascade, Inverse: tracker

**Constraints:**
- id: Unique

#### Entity: ReminderEntity

| Property | Type | Optional | Indexed | Default | Notes |
|----------|------|----------|---------|---------|-------|
| id | UUID | NO | YES | UUID() | Unique identifier |
| isEnabled | Boolean | NO | NO | YES | Whether active |
| time | Date | NO | NO | now() | Reminder time |
| daysOfWeek | Transformable | NO | NO | All days | Set<DayOfWeek> as Data |
| repeatInterval | String | NO | NO | "daily" | RepeatInterval rawValue |
| notificationId | String | YES | NO | nil | System notification ID |

**Relationships:**
- **tracker**: To One, TrackerEntity, Nullify, Inverse: reminder

**Constraints:**
- id: Unique

#### Entity: TrackerHistoryEntity

| Property | Type | Optional | Indexed | Default | Notes |
|----------|------|----------|---------|---------|-------|
| id | UUID | NO | YES | UUID() | Unique identifier |
| trackerId | UUID | NO | YES | UUID() | Reference to TrackerEntity |
| date | Date | NO | YES | now() | Date of history entry |
| isCompleted | Boolean | NO | NO | NO | Completion state |
| completionCount | Integer 64 | NO | NO | 0 | Completions that day |
| value | Integer 64 | YES | NO | 0 | Counter value |
| notes | String | YES | NO | nil | Optional notes |

**Relationships:**
- **tracker**: To One, TrackerEntity, Nullify, Inverse: histories

**Constraints:**
- id: Unique
- trackerId + date: Unique (one history entry per tracker per day)

#### Entity: SettingsEntity

| Property | Type | Optional | Indexed | Default | Notes |
|----------|------|----------|---------|---------|-------|
| id | UUID | NO | YES | UUID() | Unique identifier |
| weekStartDay | Integer 64 | NO | NO | 1 | DayOfWeek rawValue |
| isICloudSyncEnabled | Boolean | NO | NO | YES | iCloud toggle |
| showCompletionAnimation | Boolean | NO | NO | YES | Animation preference |
| useHapticFeedback | Boolean | NO | NO | YES | Haptic preference |
| theme | String | NO | NO | "system" | Theme rawValue |

**Constraints:**
- id: Unique (should only have one instance)

### 3.2 Model Configuration

1. **Editor Version**: Use the latest available (Xcode 15+)
2. **Code Generation**: Manual/None (we're using our own subclasses)
3. **Entity Inheritance**: None (all entities inherit directly from NSManagedObject)
4. **Validation Rules**: Add appropriate validation for required fields

### 3.3 Indexes

Create the following indexes for performance:

- TrackerEntity: id, type, createdAt, updatedAt
- TrackerHistoryEntity: trackerId, date
- ReminderEntity: id, isEnabled

### 3.4 Lightweight Migrations

Enable automatic lightweight migration in the PersistenceController:

```swift
// In PersistenceController.init
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

For manual migrations, create NSEntityMigrationPolicy subclasses and .xcmappingmodel files as needed.

## 4. Core Data Stack Integration

### 4.1 Dependency Container Integration

```swift
// In DependencyContainer.swift
extension DependencyContainer {
    private(set) lazy var persistenceController: PersistenceController = {
        let cloudKitOptions = isICloudSyncEnabled ? 
            CloudKitContainerOptions(containerIdentifier: "iCloud.com.arvoldek.TrackIt") :
            nil
        
        return PersistenceController(
            containerName: "TrackIt",
            cloudKitContainerOptions: cloudKitOptions
        )
    }()
    
    private(set) lazy var trackerRepository: TrackerRepositoryProtocol = {
        CoreDataTrackerRepository(persistenceController: persistenceController)
    }()
    
    private(set) lazy var settingsRepository: SettingsRepositoryProtocol = {
        CoreDataSettingsRepository(persistenceController: persistenceController)
    }()
}
```

### 4.2 Settings Repository

```swift
// CoreDataSettingsRepository.swift
import CoreData
import Foundation

final class CoreDataSettingsRepository: SettingsRepositoryProtocol {
    
    private let persistenceController: PersistenceController
    private var cachedSettings: AppSettings?
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    var settings: AppSettings {
        get {
            if let cached = cachedSettings {
                return cached
            }
            
            let settings = (try? fetchSettings()) ?? .default
            cachedSettings = settings
            return settings
        }
        set {
            cachedSettings = newValue
            try? saveSettings(newValue)
        }
    }
    
    func getSettings() async throws -> AppSettings {
        try await persistenceController.performAndWait { context in
            try self.fetchSettings(in: context)
        }
    }
    
    func saveSettings(_ settings: AppSettings) async throws {
        try await persistenceController.performAndWait { context in
            try self.saveSettings(settings, in: context)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchSettings(in context: NSManagedObjectContext = nil) throws -> AppSettings {
        let context = context ?? persistenceController.context
        
        let request: NSFetchRequest<SettingsEntity> = SettingsEntity.fetchRequest()
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        
        if let entity = entities.first {
            return entity.toDomain()
        } else {
            // Create default settings
            let defaultSettings = AppSettings.default
            try saveSettings(defaultSettings, in: context)
            return defaultSettings
        }
    }
    
    private func saveSettings(_ settings: AppSettings, in context: NSManagedObjectContext = nil) throws {
        let context = context ?? persistenceController.context
        
        let request: NSFetchRequest<SettingsEntity> = SettingsEntity.fetchRequest()
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        
        let entity: SettingsEntity
        
        if let existing = entities.first {
            entity = existing
        } else {
            entity = SettingsEntity(context: context)
        }
        
        entity.weekStartDay = Int64(settings.weekStartDay.rawValue)
        entity.isICloudSyncEnabled = settings.isICloudSyncEnabled
        entity.showCompletionAnimation = settings.showCompletionAnimation
        entity.useHapticFeedback = settings.useHapticFeedback
        entity.theme = settings.theme.rawValue
        
        try context.save()
        
        // Update cache
        cachedSettings = settings
    }
}
```

## 5. Testing Core Data Stack

### 5.1 Test Configuration

```swift
// PersistenceController+Test.swift
import CoreData

#IF TEST

extension PersistenceController {
    static func testController() -> PersistenceController {
        // Create an in-memory store for testing
        let container = NSPersistentContainer(name: "TrackIt")
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        return PersistenceController(
            container: container,
            context: container.viewContext
        )
    }
}

final class PersistenceControllerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = .testController()
        context = persistenceController.context
    }
    
    override func tearDown() {
        persistenceController = nil
        context = nil
        super.tearDown()
    }
    
    func testSaveAndFetchTracker() throws {
        // Create a tracker
        let trackerEntity = TrackerEntity(context: context)
        trackerEntity.id = UUID()
        trackerEntity.name = "Test Tracker"
        trackerEntity.type = TrackerType.streak.rawValue
        trackerEntity.isCompleted = false
        trackerEntity.completionCount = 0
        trackerEntity.targetCount = 1
        trackerEntity.completionFrequency = CompletionFrequency.once.rawValue
        trackerEntity.createdAt = Date()
        trackerEntity.updatedAt = Date()
        
        try persistenceController.save()
        
        // Fetch the tracker
        let fetchRequest: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Test Tracker")
    }
    
    func testDeleteTracker() throws {
        // Create and save a tracker
        let trackerEntity = TrackerEntity(context: context)
        trackerEntity.id = UUID()
        trackerEntity.name = "Test Tracker"
        
        try persistenceController.save()
        
        // Delete the tracker
        context.delete(trackerEntity)
        try persistenceController.save()
        
        // Verify deletion
        let fetchRequest: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        let results = try context.fetch(fetchRequest)
        
        XCTAssertEqual(results.count, 0)
    }
    
    func testFetchWithPredicate() throws {
        // Create multiple trackers
        for i in 0..<5 {
            let tracker = TrackerEntity(context: context)
            tracker.id = UUID()
            tracker.name = "Tracker \(i)"
            tracker.type = i % 2 == 0 ? TrackerType.streak.rawValue : TrackerType.counter.rawValue
        }
        
        try persistenceController.save()
        
        // Fetch only streak trackers
        let predicate = NSPredicate(format: "type == %@", TrackerType.streak.rawValue)
        let results = try persistenceController.fetch(TrackerEntity.self, predicate: predicate)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.type == TrackerType.streak.rawValue })
    }
}

#endif
```

## 6. Delivery Checklist

- [ ] PersistenceController implemented
- [ ] Core Data model file created (TrackIt.xcdatamodeld)
- [ ] All entities defined with correct properties and relationships
- [ ] Indexes configured for performance
- [ ] Lightweight migration enabled
- [ ] iCloud sync configured
- [ ] Settings repository implemented
- [ ] Test configuration created
- [ ] Tests written and passing

---

**Duration**: 2 days
**Priority**: Critical
**Next**: Proceed to [02-icloud-sync.md](./02-icloud-sync.md)
