# Phase 2: iCloud Synchronization

## Overview

This document details the iCloud synchronization implementation for the Track It application using Core Data's built-in NSPersistentCloudKitContainer integration. This allows seamless synchronization of tracker data across all the user's devices.

## 1. iCloud Sync Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVICE 1                                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Core Data Stack                                       │  │
│  │  - NSPersistentContainer                              │  │
│  │  - NSPersistentCloudKitContainer                       │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ iCloud Sync
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CLOUDKIT                                    │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Private Database                                       │  │
│  │  - Tracker records                                     │  │
│  │  - History records                                     │  │
│  │  - Reminder records                                    │  │
│  │  - Settings records                                    │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DEVICE 2                                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Core Data Stack                                       │  │
│  │  - NSPersistentContainer                              │  │
│  │  - NSPersistentCloudKitContainer                       │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 2. iCloud Configuration

### 2.1 Entitlements

Ensure the following entitlements are configured in your project:

**Signing & Capabilities:**
- [x] iCloud enabled
- [x] CloudKit enabled

**Entitlements File (TrackIt.entitlements):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.arvoldek.TrackIt</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-containers</key>
    <array>
        <string>iCloud.com.arvoldek.TrackIt</string>
    </array>
</dict>
</plist>
```

### 2.2 CloudKit Container Setup

```swift
// CloudKitContainer.swift
import CloudKit

final class CloudKitContainer {
    
    static let shared = CloudKitContainer()
    
    let container: CKContainer
    let publicDatabase: CKDatabase
    let privateDatabase: CKDatabase
    let sharedDatabase: CKDatabase
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.arvoldek.TrackIt")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        // Request application permission if needed
        requestApplicationPermission()
    }
    
    func requestApplicationPermission() {
        container.requestApplicationPermission(.userDiscoverability) { status, error in
            if let error = error {
                Logger.shared.error("Failed to request CloudKit permission: %{private}@", error.localizedDescription)
                return
            }
            
            switch status {
            case .granted:
                Logger.shared.info("CloudKit permission granted")
            case .denied:
                Logger.shared.warning("CloudKit permission denied")
            case .initialState:
                Logger.shared.debug("CloudKit permission initial state")
            @unknown default:
                Logger.shared.warning("Unknown CloudKit permission status")
            }
        }
    }
    
    func checkAccountStatus(completion: @escaping (CKAccountStatus) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                Logger.shared.error("Failed to check account status: %{private}@", error.localizedDescription)
                completion(.couldNotDetermine)
                return
            }
            
            completion(status)
        }
    }
    
    func checkiCloudAvailability() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
```

## 3. iCloud Sync Management

### 3.1 CloudSyncManager

```swift
// CloudSyncManager.swift
import CoreData
import CloudKit

/// Manages iCloud synchronization for Core Data
final class CloudSyncManager {
    
    enum SyncStatus {
        case notAvailable // iCloud not available on device
        case disabled // iCloud sync disabled in settings
        case available // iCloud available and sync enabled
        case syncing // Currently syncing
        case error(Error) // Error occurred
    }
    
    @Published private(set) var status: SyncStatus = .notAvailable
    
    private let persistenceController: PersistenceController
    private let settingsRepository: SettingsRepositoryProtocol
    private let container: CKContainer
    
    private var cloudKitObserver: NSObjectProtocol?
    
    init(
        persistenceController: PersistenceController,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.persistenceController = persistenceController
        self.settingsRepository = settingsRepository
        self.container = CKContainer(identifier: "iCloud.com.arvoldek.TrackIt")
        
        setupObservers()
        updateStatus()
    }
    
    deinit {
        cloudKitObserver = nil
    }
    
    // MARK: - Status Management
    
    func updateStatus() {
        let isAvailable = CloudKitContainer.shared.checkiCloudAvailability()
        let isEnabled = settingsRepository.settings.isICloudSyncEnabled
        
        if !isAvailable {
            status = .notAvailable
        } else if !isEnabled {
            status = .disabled
        } else {
            status = .available
        }
    }
    
    var isSyncAvailable: Bool {
        if case .available = status { return true }
        return false
    }
    
    // MARK: - Enable/Disable Sync
    
    func enableSync() async throws {
        guard CloudKitContainer.shared.checkiCloudAvailability() else {
            throw CloudSyncError.iCloudNotAvailable
        }
        
        // Update settings
        var settings = settingsRepository.settings
        settings.isICloudSyncEnabled = true
        settingsRepository.settings = settings
        
        // Enable CloudKit in Core Data
        persistenceController.enableCloudSync()
        
        // Wait for sync to start
        try await waitForSyncToStart()
        
        updateStatus()
    }
    
    func disableSync() async throws {
        // Update settings
        var settings = settingsRepository.settings
        settings.isICloudSyncEnabled = false
        settingsRepository.settings = settings
        
        // Disable CloudKit in Core Data
        persistenceController.disableCloudSync()
        
        updateStatus()
    }
    
    private func waitForSyncToStart(timeout: TimeInterval = 10.0) async throws {
        let startDate = Date()
        
        while Date().timeIntervalSince(startDate) < timeout {
            if persistenceController.isCloudSyncEnabled {
                return
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        throw CloudSyncError.syncTimeout
    }
    
    // MARK: - Sync Operations
    
    func forceSync() async throws {
        guard isSyncAvailable else {
            throw CloudSyncError.syncNotAvailable
        }
        
        // Trigger a manual sync
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation()
            
            // This is a bit of a hack to trigger a sync
            // In practice, Core Data handles sync automatically
            // but we can force it by creating a dummy operation
            
            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            
            container.privateCloudDatabase.add(operation)
        }
    }
    
    func getSyncStatus() async -> CloudSyncStatus {
        guard isSyncAvailable else {
            return CloudSyncStatus(notAvailable: true)
        }
        
        // Check if there are pending changes
        let hasLocalChanges = persistenceController.context.hasChanges
        
        // Check CloudKit server for changes
        var serverStatus = CloudKitServerStatus()
        
        do {
            serverStatus = try await checkServerStatus()
        } catch {
            Logger.shared.error("Failed to check server status: %{private}@", error.localizedDescription)
        }
        
        return CloudSyncStatus(
            notAvailable: false,
            isEnabled: true,
            hasLocalChanges: hasLocalChanges,
            hasServerChanges: serverStatus.hasChanges,
            lastSyncDate: serverStatus.lastSyncDate,
            error: nil
        )
    }
    
    private func checkServerStatus() async throws -> CloudKitServerStatus {
        // Query the server for recent changes
        // This is a simplified implementation
        
        let query = CKQuery(
            recordType: "CD_Tracker",
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        query.resultsLimit = 1
        
        do {
            let results = try await container.privateCloudDatabase.records(matching: query)
            
            if let firstRecord = results.matchResults.first?.1.first {
                return CloudKitServerStatus(
                    hasChanges: true,
                    lastSyncDate: firstRecord.modificationDate ?? Date()
                )
            }
            
            return CloudKitServerStatus()
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe iCloud account changes
        cloudKitObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquitousKeyValueStoreDidChangeExternally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAccountChange()
        }
        
        // Observe Core Data CloudKit events
        NotificationCenter.default.addObserver(
            forName: .NSPersistentCloudKitContainerInitialAccountSetupDidComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleInitialSyncComplete()
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSPersistentCloudKitContainerAccountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAccountNotification(notification)
        }
    }
    
    private func handleAccountChange() {
        Logger.shared.info("iCloud account changed")
        updateStatus()
        
        // When the iCloud account changes, we might need to:
        // 1. Re-enable sync if it was disabled
        // 2. Re-authenticate with the new account
        // 3. Handle data migration between accounts
    }
    
    private func handleInitialSyncComplete() {
        Logger.shared.info("Initial iCloud sync completed")
        updateStatus()
    }
    
    private func handleAccountNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        Logger.shared.info("CloudKit account notification: %{private}@", userInfo)
        
        // Handle different types of account notifications
        updateStatus()
    }
    
    // MARK: - Error Handling
    
    func handleCloudKitError(_ error: Error) {
        Logger.shared.error("CloudKit error: %{private}@", error.localizedDescription)
        
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                status = .error(CloudSyncError.notAuthenticated)
            case .permissionFailure:
                status = .error(CloudSyncError.permissionDenied)
            case .networkUnavailable, .networkFailure:
                status = .error(CloudSyncError.networkError(ckError))
            case .quotaExceeded:
                status = .error(CloudSyncError.quotaExceeded)
            default:
                status = .error(CloudSyncError.unknown(ckError))
            }
        } else {
            status = .error(CloudSyncError.unknown(error))
        }
    }
}

// MARK: - Models

struct CloudSyncStatus {
    let notAvailable: Bool
    let isEnabled: Bool
    let hasLocalChanges: Bool
    let hasServerChanges: Bool
    let lastSyncDate: Date?
    let error: Error?
}

struct CloudKitServerStatus {
    let hasChanges: Bool
    let lastSyncDate: Date?
    
    init(hasChanges: Bool = false, lastSyncDate: Date? = nil) {
        self.hasChanges = hasChanges
        self.lastSyncDate = lastSyncDate
    }
}

// MARK: - Errors

enum CloudSyncError: Error, LocalizedError {
    case iCloudNotAvailable
    case syncNotAvailable
    case syncTimeout
    case notAuthenticated
    case permissionDenied
    case networkError(CKError)
    case quotaExceeded
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available on this device"
        case .syncNotAvailable:
            return "iCloud sync is not available"
        case .syncTimeout:
            return "Sync operation timed out"
        case .notAuthenticated:
            return "Please sign in to iCloud"
        case .permissionDenied:
            return "iCloud permission denied"
        case .networkError:
            return "Network error occurred"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}
```

### 3.2 CloudKitRecordManager

```swift
// CloudKitRecordManager.swift
import CloudKit

/// Manages direct CloudKit record operations (for advanced use cases)
final class CloudKitRecordManager {
    
    private let database: CKDatabase
    
    init(database: CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.database = database
    }
    
    // MARK: - Record Operations
    
    func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        do {
            return try await database.save(record)
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        do {
            return try await database.modifyRecords(
                saving: records,
                deleting: []
            ).savedRecords ?? []
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func deleteRecord(withId recordID: CKRecord.ID) async throws {
        do {
            try await database.deleteRecord(withID: recordID)
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func fetchRecord(withId recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await database.record(forID: recordID)
        } catch let error as CKError where error.code == .notFound {
            return nil
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func queryRecords(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int? = nil
    ) async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: recordType,
            predicate: predicate
        )
        
        if let sortDescriptors = sortDescriptors {
            query.sortDescriptors = sortDescriptors
        }
        
        if let limit = limit {
            query.resultsLimit = limit
        }
        
        do {
            let result = try await database.records(matching: query)
            return result.matchResults.compactMap { try? $0.1.get() }
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    // MARK: - Subscription Management
    
    func createSubscription(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        options: CKSubscription.Options = []
    ) async throws -> CKSubscription {
        let subscriptionID = "com.arvoldek.TrackIt.\(recordType)"
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: options
        )
        
        // Configure notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.title = "Track It Update"
        notificationInfo.body = "New data available in Track It"
        notificationInfo.soundName = "default"
        notificationInfo.shouldSendContentAvailable = true
        
        subscription.notificationInfo = notificationInfo
        
        do {
            return try await database.save(subscription)
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func deleteSubscription(withId subscriptionID: String) async throws {
        do {
            try await database.deleteSubscription(withID: subscriptionID)
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    func fetchSubscriptions() async throws -> [CKSubscription] {
        do {
            return try await database.fetchAllSubscriptions()
        } catch let error as CKError {
            handleCloudKitError(error)
            throw error
        }
    }
    
    // MARK: - Error Handling
    
    private func handleCloudKitError(_ error: CKError) {
        Logger.shared.error("CloudKit error: %{private}@", error.localizedDescription)
        
        // Log error details
        var clientError: String? = nil
        if let partialError = error as? CKPartialErrorsByItemID {
            for (_, error) in partialError.errors {
                if let ckError = error as? CKError {
                    clientError = ckError.localizedDescription
                    break
                }
            }
        }
        
        if let clientError = clientError {
            Logger.shared.error("Client error: %{private}@", clientError)
        }
    }
}
```

## 4. Core Data + CloudKit Integration

### 4.1 PersistenceController CloudKit Extensions

```swift
// PersistenceController+CloudKit.swift
extension PersistenceController {
    
    // MARK: - CloudKit Configuration
    
    func configureCloudKit() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        let options = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.arvoldek.TrackIt"
        )
        options.databaseScope = .private
        
        description.cloudKitContainerOptions = options
    }
    
    // MARK: - CloudKit Status
    
    var isCloudKitAvailable: Bool {
        guard let description = container.persistentStoreDescriptions.first else {
            return false
        }
        return description.cloudKitContainerOptions != nil
    }
    
    var cloudKitContainerIdentifier: String? {
        container.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier
    }
    
    // MARK: - Sync Status
    
    func getCloudKitSyncStatus() -> (hasChanges: Bool, lastSyncDate: Date?) {
        // This is a simplified implementation
        // Core Data doesn't expose sync status directly
        
        // Check if there are local changes
        let hasLocalChanges = context.hasChanges
        
        // For last sync date, we would need to track this ourselves
        // For now, return a placeholder
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
        
        return (hasLocalChanges, lastSyncDate)
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync() {
        // Core Data handles sync automatically, but we can try to force it
        // by saving the context
        
        do {
            try save()
        } catch {
            Logger.shared.error("Failed to trigger manual sync: %{private}@", error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling
    
    func handleCloudKitError(_ error: Error) {
        if let ckError = error as? CKError {
            handleCloudKitError(ckError)
        } else {
            Logger.shared.error("CloudKit error: %{private}@", error.localizedDescription)
        }
    }
    
    private func handleCloudKitError(_ error: CKError) {
        Logger.shared.error("CloudKit error: %{private}@", error.localizedDescription)
        
        switch error.code {
        case .notAuthenticated:
            Logger.shared.warning("User not authenticated with iCloud")
        case .permissionFailure:
            Logger.shared.warning("Permission denied for iCloud")
        case .networkUnavailable, .networkFailure:
            Logger.shared.warning("Network error occurred")
        case .quotaExceeded:
            Logger.shared.error("iCloud storage quota exceeded")
        case .zoneBusy:
            Logger.shared.warning("CloudKit zone busy, will retry")
        default:
            Logger.shared.error("Unknown CloudKit error: \(error.code)")
        }
    }
}
```

### 4.2 CoreDataTrackerRepository CloudKit Integration

```swift
// CoreDataTrackerRepository+CloudKit.swift
extension CoreDataTrackerRepository {
    
    // MARK: - CloudKit Metadata
    
    /// Get CloudKit metadata for a tracker
    func getCloudKitMetadata(for tracker: Tracker) -> CloudKitMetadata? {
        guard let entity = getEntity(for: tracker) else { return nil }
        
        // Get the managed object ID
        guard let objectID = entity.objectID.uriRepresentation().absoluteString.components(separatedBy: "/").last else {
            return nil
        }
        
        return CloudKitMetadata(
            recordName: "CD_Tracker_\(objectID)",
            recordType: "Tracker",
            lastModified: entity.updatedAt
        )
    }
    
    /// Sync a specific tracker to CloudKit
    func syncTrackerToCloudKit(_ tracker: Tracker) async throws {
        // This is handled automatically by Core Data
        // but we can force a sync by updating the tracker
        
        var mutableTracker = tracker
        mutableTracker.updatedAt = Date()
        
        try await updateTracker(mutableTracker)
    }
    
    // MARK: - Conflict Resolution
    
    /// Handle conflicts between local and CloudKit versions
    func resolveConflict(local: Tracker, cloud: Tracker) -> Tracker {
        // Compare timestamps to determine which version is newer
        
        if local.updatedAt > cloud.updatedAt {
            return local
        } else if cloud.updatedAt > local.updatedAt {
            return cloud
        } else {
            // If timestamps are equal, merge the changes
            var merged = local
            
            // Merge non-conflicting changes
            // For example, if the name changed on one but not the other, take the new name
            // This is a simplified merge strategy
            
            if cloud.name != local.name {
                // Take the cloud version's name (arbitrary choice)
                merged.name = cloud.name
            }
            
            // For history, merge both
            let localHistoryDates = Set(local.history.map { $0.date })
            let cloudHistoryDates = Set(cloud.history.map { $0.date })
            
            for cloudHistory in cloud.history {
                if !localHistoryDates.contains(cloudHistory.date) {
                    merged.history.append(cloudHistory)
                }
            }
            
            // Update timestamp
            merged.updatedAt = Date()
            
            return merged
        }
    }
    
    // MARK: - Private Helpers
    
    private func getEntity(for tracker: Tracker) -> TrackerEntity? {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            Logger.shared.error("Failed to fetch entity for tracker \(tracker.id): %{private}@", error.localizedDescription)
            return nil
        }
    }
}

struct CloudKitMetadata {
    let recordName: String
    let recordType: String
    let lastModified: Date
}
```

## 5. iCloud Settings Synchronization

### 5.1 Settings Sync Strategy

For settings, we'll use a simpler approach with UserDefaults and iCloud Key-Value Store:

```swift
// UserDefaults+CloudKit.swift
import Foundation

extension UserDefaults {
    
    private static let iCloudKeyValueStore = NSUbiquitousKeyValueStore(defaults: UserDefaults.standard)
    
    static func syncToICloud() {
        iCloudKeyValueStore.synchronize()
    }
    
    static func getICloudValue(forKey key: String) -> Any? {
        return iCloudKeyValueStore.object(forKey: key)
    }
    
    static func setICloudValue(_ value: Any?, forKey key: String) {
        iCloudKeyValueStore.set(value, forKey: key)
        syncToICloud()
    }
    
    static func removeICloudValue(forKey key: String) {
        iCloudKeyValueStore.removeObject(forKey: key)
        syncToICloud()
    }
}

// CloudSettingsRepository.swift
final class CloudSettingsRepository: SettingsRepositoryProtocol {
    
    private let localRepository: SettingsRepositoryProtocol
    private let iCloudStore = NSUbiquitousKeyValueStore()
    
    init(localRepository: SettingsRepositoryProtocol) {
        self.localRepository = localRepository
        setupObservers()
    }
    
    var settings: AppSettings {
        get {
            // Try to get from iCloud first, fall back to local
            if let iCloudSettings = getICloudSettings() {
                return iCloudSettings
            }
            return localRepository.settings
        }
        set {
            // Save to both local and iCloud
            localRepository.settings = newValue
            saveICloudSettings(newValue)
        }
    }
    
    func getSettings() async throws -> AppSettings {
        settings
    }
    
    func saveSettings(_ settings: AppSettings) async throws {
        self.settings = settings
    }
    
    // MARK: - iCloud Settings
    
    private func getICloudSettings() -> AppSettings? {
        guard let data = iCloudStore.object(forKey: "AppSettings") as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
    
    private func saveICloudSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            iCloudStore.set(data, forKey: "AppSettings")
            iCloudStore.synchronize()
        } catch {
            Logger.shared.error("Failed to encode settings: %{private}@", error.localizedDescription)
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
    }
    
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "AppSettings" {
                    // iCloud settings changed, update local
                    if let iCloudSettings = getICloudSettings() {
                        localRepository.settings = iCloudSettings
                    }
                    break
                }
            }
        }
    }
}
```

## 6. UI Integration

### 6.1 iCloud Sync Status View

```swift
// CloudSyncStatusView.swift
import SwiftUI

struct CloudSyncStatusView: View {
    @ObservedObject var syncManager: CloudSyncManager
    
    var body: some View {
        switch syncManager.status {
        case .notAvailable:
            iCloudNotAvailableView
        case .disabled:
            iCloudDisabledView
        case .available:
            iCloudAvailableView
        case .syncing:
            iCloudSyncingView
        case .error(let error):
            iCloudErrorView(error: error)
        }
    }
    
    private var iCloudNotAvailableView: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.slash.fill")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("iCloud Not Available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Sign in to iCloud to enable sync across devices")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var iCloudDisabledView: some View {
        Button(action: {
            // Enable sync
            Task {
                try? await syncManager.enableSync()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .font(.title)
                    .foregroundColor(.primary)
                
                Text("Enable iCloud Sync")
                    .font(.headline)
                
                Text("Sync your trackers across all devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
    
    private var iCloudAvailableView: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.fill")
                .foregroundColor(.green)
            
            Text("Synced")
                .font(.caption)
                .foregroundColor(.green)
        }
    }
    
    private var iCloudSyncingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.5)
            
            Text("Syncing...")
                .font(.caption)
        }
    }
    
    private func iCloudErrorView(error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.slash.fill")
                .font(.title)
                .foregroundColor(.red)
            
            Text("Sync Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    try? await syncManager.forceSync()
                }
            }
            .font(.caption)
        }
        .padding()
    }
}
```

### 6.2 Settings View Integration

```swift
// iCloudSettingsSection.swift
import SwiftUI

struct iCloudSettingsSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var syncManager: CloudSyncManager
    
    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
        
        let persistenceController = DependencyContainer.shared.persistenceController
        let settingsRepository = DependencyContainer.shared.settingsRepository
        _syncManager = StateObject(wrappedValue: CloudSyncManager(
            persistenceController: persistenceController,
            settingsRepository: settingsRepository
        ))
    }
    
    var body: some View {
        Section {
            Toggle("iCloud Sync", isOn: $settingsViewModel.settings.isICloudSyncEnabled)
                .onChange(of: settingsViewModel.settings.isICloudSyncEnabled) { newValue in
                    Task {
                        if newValue {
                            try? await syncManager.enableSync()
                        } else {
                            try? await syncManager.disableSync()
                        }
                    }
                }
            
            if syncManager.isSyncAvailable {
                NavigationLink {
                    CloudSyncDetailView(syncManager: syncManager)
                } label: {
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        CloudSyncStatusView(syncManager: syncManager)
                    }
                }
            }
        } header: {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.accentColor)
                Text("iCloud")
            }
        } footer: {
            if !syncManager.isSyncAvailable {
                Text("Sign in to iCloud in Settings to enable sync")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CloudSyncDetailView: View {
    @ObservedObject var syncManager: CloudSyncManager
    @State private var lastSyncDate: Date?
    @State private var syncStatus: CloudSyncStatus?
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    CloudSyncStatusView(syncManager: syncManager)
                }
                
                HStack {
                    Text("Last Sync")
                    Spacer()
                    if let date = lastSyncDate {
                        Text(date.formattedRelative())
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Sync Information")
            }
            
            Section {
                Button("Force Sync Now") {
                    Task {
                        try? await syncManager.forceSync()
                        await loadSyncStatus()
                    }
                }
                .disabled(!syncManager.isSyncAvailable)
                
                Button("Reset iCloud Data", role: .destructive) {
                    // This would delete all iCloud data and re-sync from local
                    showResetAlert = true
                }
                .disabled(!syncManager.isSyncAvailable)
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("iCloud Sync")
        .task {
            await loadSyncStatus()
        }
        .alert("Reset iCloud Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await resetICloudData()
                }
            }
        } message: {
            Text("This will delete all iCloud data and re-sync from this device. Other devices will receive these changes.")
        }
    }
    
    @State private var showResetAlert = false
    
    private func loadSyncStatus() async {
        syncStatus = await syncManager.getSyncStatus()
        lastSyncDate = syncStatus?.lastSyncDate
    }
    
    private func resetICloudData() async {
        // Implementation would involve:
        // 1. Disabling CloudKit sync in Core Data
        // 2. Deleting all CloudKit records
        // 3. Re-enabling CloudKit sync
        // This is a destructive operation and should be used with caution
        
        // For now, just show a message
        Logger.shared.info("Reset iCloud data - Not implemented")
    }
}
```

## 7. Testing iCloud Sync

### 7.1 Test Setup

```swift
// CloudSyncManagerTests.swift
import XCTest
import CoreData
import CloudKit

final class CloudSyncManagerTests: XCTestCase {
    
    var syncManager: CloudSyncManager!
    var persistenceController: PersistenceController!
    var settingsRepository: MockSettingsRepository!
    
    override func setUp() {
        super.setUp()
        
        // Create test persistence controller
        persistenceController = PersistenceController.testController()
        
        // Create mock settings repository
        settingsRepository = MockSettingsRepository()
        settingsRepository.settings = AppSettings.default
        
        // Create sync manager
        syncManager = CloudSyncManager(
            persistenceController: persistenceController,
            settingsRepository: settingsRepository
        )
    }
    
    override func tearDown() {
        syncManager = nil
        persistenceController = nil
        settingsRepository = nil
        super.tearDown()
    }
    
    func testInitialStatus_WhenICloudNotAvailable() {
        // Mock iCloud not available
        let mockContainer = MockCKContainer()
        mockContainer.isAvailable = false
        
        // This test would need proper mocking of FileManager
        // For now, we'll skip it
    }
    
    func testEnableDisableSync() async {
        // Initially disabled
        settingsRepository.settings.isICloudSyncEnabled = false
        syncManager.updateStatus()
        
        XCTAssertEqual(syncManager.status, .disabled)
        
        // Enable sync
        try? await syncManager.enableSync()
        syncManager.updateStatus()
        
        // Should be available now (assuming iCloud is available in test environment)
        // This depends on the test environment
        
        // Disable sync
        try? await syncManager.disableSync()
        syncManager.updateStatus()
        
        XCTAssertEqual(syncManager.status, .disabled)
    }
}

// Mock Settings Repository
final class MockSettingsRepository: SettingsRepositoryProtocol {
    var settings: AppSettings = .default
    
    func getSettings() async throws -> AppSettings {
        settings
    }
    
    func saveSettings(_ settings: AppSettings) async throws {
        self.settings = settings
    }
}

// Mock CKContainer
final class MockCKContainer: CKContainer {
    var isAvailable: Bool = true
    
    override var publicCloudDatabase: CKDatabase {
        MockCKDatabase()
    }
    
    override var privateCloudDatabase: CKDatabase {
        MockCKDatabase()
    }
    
    override var sharedCloudDatabase: CKDatabase {
        MockCKDatabase()
    }
}

final class MockCKDatabase: CKDatabase {
    override func save(_ record: CKRecord) async throws -> CKRecord {
        record
    }
    
    override func fetchRecord(withID recordID: CKRecord.ID) async throws -> CKRecord? {
        nil
    }
    
    // Implement other required methods
}
```

## 8. Delivery Checklist

- [ ] CloudKit entitlements configured
- [ ] CloudSyncManager implemented
- [ ] CloudKitRecordManager implemented
- [ ] Core Data CloudKit integration configured
- [ ] Conflict resolution strategy implemented
- [ ] iCloud settings synchronization implemented
- [ ] UI components for iCloud status created
- [ ] Error handling for iCloud sync implemented
- [ ] Tests for iCloud sync written

---

**Duration**: 1-2 days
**Priority**: High
**Note**: iCloud sync testing requires proper test environment setup
**Next**: Proceed to [03-reminder-system.md](./03-reminder-system.md)
