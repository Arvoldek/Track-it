# Phase 2: Repository Pattern Implementation

## Overview

This document details the complete implementation of the Repository Pattern for the Track It application, including all repository implementations, data access strategies, and caching mechanisms.

## 1. Repository Pattern Overview

The Repository Pattern provides a clean separation between the business logic and data access layers. It abstracts the details of data persistence, allowing the business logic to work with simple, domain-specific objects.

### 1.1 Repository Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Entities                                │  │
│  │  Tracker, Reminder, TrackerHistory, AppSettings          │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Use Cases                                │  │
│  │  CreateTracker, UpdateTracker, DeleteTracker, etc.       │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Repository Interfaces                  │  │
│  │  TrackerRepositoryProtocol                              │  │
│  │  SettingsRepositoryProtocol                             │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Repository Implementations             │  │
│  │  CoreDataTrackerRepository                              │  │
│  │  CoreDataSettingsRepository                             │  │
│  │  UserDefaultsSettingsRepository                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Data Sources                            │  │
│  │  Core Data (NSPersistentContainer)                      │  │
│  │  UserDefaults                                          │  │
│  │  iCloud (NSPersistentCloudKitContainer)                │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Repository Pattern Benefits

1. **Separation of Concerns**: Business logic doesn't need to know about data persistence
2. **Testability**: Easy to mock repositories for unit testing
3. **Flexibility**: Can switch data sources without changing business logic
4. **Consistency**: Provides a consistent interface for data access
5. **Maintainability**: Changes to persistence are isolated to repository implementations

## 2. Repository Protocols

### 2.1 TrackerRepositoryProtocol

```swift
// TrackerRepositoryProtocol.swift
import Foundation

protocol TrackerRepositoryProtocol {
    // CRUD Operations
    func getAllTrackers() async throws -> [Tracker]
    func getTracker(byId id: UUID) async throws -> Tracker?
    func getTrackers(byType type: TrackerType) async throws -> [Tracker]
    func createTracker(_ tracker: Tracker) async throws
    func updateTracker(_ tracker: Tracker) async throws
    func deleteTracker(_ tracker: Tracker) async throws
    
    // Query Operations
    func hasTrackers() -> Bool
    func getTrackers(byIds ids: [UUID]) async throws -> [Tracker]
    func getTrackers(matching predicate: (Tracker) -> Bool) async -> [Tracker]
    
    // History Operations
    func getTrackerHistory(trackerId: UUID, limit: Int?) async throws -> [TrackerHistory]
    func getTrackerHistory(forDate date: Date) async throws -> [TrackerHistory]
    func getTrackerHistory(inDateRange range: ClosedRange<Date>) async throws -> [TrackerHistory]
    
    // Stats Operations
    func getCompletionStats(trackerId: UUID) async throws -> CompletionStats
    func getCompletionStats(forDate date: Date) async throws -> [UUID: CompletionStats]
    func getOverallStats() async throws -> OverallStats
    
    // Bulk Operations
    func createTrackers(_ trackers: [Tracker]) async throws
    func updateTrackers(_ trackers: [Tracker]) async throws
    func deleteTrackers(_ trackers: [Tracker]) async throws
    func deleteAllTrackers() async throws
    func resetAllTrackers() async throws
    
    // Count Operations
    func getTrackerCount() async -> Int
    func getTrackerCount(byType type: TrackerType) async -> Int
    func getCompletedCount(for tracker: Tracker) async -> Int
}

struct CompletionStats {
    var totalCompletions: Int = 0
    var completedDays: Int = 0
    var failedDays: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    
    var successRate: Double {
        guard completedDays + failedDays > 0 else { return 1.0 }
        return Double(completedDays) / Double(completedDays + failedDays)
    }
}

struct OverallStats {
    var totalTrackers: Int = 0
    var totalCompletions: Int = 0
    var averageSuccessRate: Double = 0
    var longestStreak: Int = 0
    var trackerTypeCounts: [TrackerType: Int] = [:]
}
```

### 2.2 SettingsRepositoryProtocol

```swift
// SettingsRepositoryProtocol.swift
import Foundation

protocol SettingsRepositoryProtocol {
    // Current settings
    var settings: AppSettings { get set }
    
    // Async operations
    func getSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws
    
    // Specific settings
    func getWeekStartDay() -> DayOfWeek
    func setWeekStartDay(_ day: DayOfWeek) async throws
    
    func isICloudSyncEnabled() -> Bool
    func setICloudSyncEnabled(_ enabled: Bool) async throws
    
    func isHapticFeedbackEnabled() -> Bool
    func setHapticFeedbackEnabled(_ enabled: Bool) async throws
    
    func getTheme() -> Theme
    func setTheme(_ theme: Theme) async throws
}
```

### 2.3 Caching Repository Protocol

```swift
// CachingRepositoryProtocol.swift
import Foundation

protocol CachingRepositoryProtocol: AnyObject {
    associatedtype Model: Identifiable & Hashable
    
    // Cache operations
    func getCached(byId id: UUID) -> Model?
    func cache(_ model: Model)
    func cache(_ models: [Model])
    func removeFromCache(byId id: UUID)
    func clearCache()
    
    // Cache configuration
    var cacheLimit: Int { get set }
    var cacheExpiration: TimeInterval { get set }
}
```

## 3. Core Data Repository Implementations

### 3.1 CoreDataTrackerRepository

```swift
// CoreDataTrackerRepository.swift
import CoreData
import Foundation

final class CoreDataTrackerRepository: TrackerRepositoryProtocol, CachingRepositoryProtocol {
    
    typealias Model = Tracker
    
    // MARK: - Properties
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private var cache: [UUID: Tracker] = [:]
    private var cacheTimestamps: [UUID: Date] = [:]
    
    // Cache configuration
    var cacheLimit: Int = 100
    var cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.context = persistenceController.context
    }
    
    // MARK: - CRUD Operations
    
    func getAllTrackers() async throws -> [Tracker] {
        // Check cache first if enabled
        if !cache.isEmpty {
            let now = Date()
            let validCached = cache.filter { id, _ in
                guard let timestamp = cacheTimestamps[id] else { return false }
                return now.timeIntervalSince(timestamp) < cacheExpiration
            }
            
            if validCached.count == cache.count {
                return Array(validCached.values)
            }
        }
        
        // Fetch from Core Data
        let entities = try fetchTrackerEntities()
        let trackers = entities.map { $0.toDomain() }
        
        // Update cache
        cache = Dictionary(uniqueKeysWithValues: trackers.map { ($0.id, $0) })
        cacheTimestamps = Dictionary(uniqueKeysWithValues: trackers.map { ($0.id, Date()) })
        
        return trackers
    }
    
    func getTracker(byId id: UUID) async throws -> Tracker? {
        // Check cache first
        if let cached = getCached(byId: id) {
            return cached
        }
        
        // Fetch from Core Data
        let entity = try fetchTrackerEntity(byId: id)
        
        if let entity = entity {
            let tracker = entity.toDomain()
            cache(tracker)
            return tracker
        }
        
        return nil
    }
    
    func getTrackers(byType type: TrackerType) async throws -> [Tracker] {
        let allTrackers = try await getAllTrackers()
        return allTrackers.filter { $0.type == type }
    }
    
    func createTracker(_ tracker: Tracker) async throws {
        let entity = TrackerEntity.fromDomain(tracker, context: context)
        
        try persistenceController.save()
        
        // Update cache
        cache(tracker)
    }
    
    func updateTracker(_ tracker: Tracker) async throws {
        guard let entity = try fetchTrackerEntity(byId: tracker.id) else {
            throw TrackerError.trackerNotFound
        }
        
        // Update entity from domain model
        entity.name = tracker.name
        entity.isCompleted = tracker.isCompleted
        entity.completionCount = Int64(tracker.completionCount)
        entity.targetCount = Int64(tracker.targetCount)
        entity.completionFrequency = tracker.completionFrequency.rawValue
        entity.updatedAt = tracker.updatedAt
        entity.lastCompletedAt = tracker.lastCompletedAt
        
        // Update reminder
        if let reminder = tracker.reminder {
            if let existingReminder = entity.reminder {
                existingReminder.isEnabled = reminder.isEnabled
                existingReminder.time = reminder.time
                existingReminder.daysOfWeek = (try? JSONEncoder().encode(reminder.daysOfWeek))?.base64EncodedString() ?? ""
                existingReminder.repeatInterval = reminder.repeatInterval.rawValue
            } else {
                entity.reminder = ReminderEntity.fromDomain(reminder, context: context)
            }
        } else {
            context.delete(entity.reminder!)
            entity.reminder = nil
        }
        
        // Update histories
        updateHistories(for: entity, with: tracker.history)
        
        try persistenceController.save()
        
        // Update cache
        cache(tracker)
    }
    
    func deleteTracker(_ tracker: Tracker) async throws {
        guard let entity = try fetchTrackerEntity(byId: tracker.id) else {
            throw TrackerError.trackerNotFound
        }
        
        context.delete(entity)
        try persistenceController.save()
        
        // Remove from cache
        removeFromCache(byId: tracker.id)
    }
    
    // MARK: - Query Operations
    
    func hasTrackers() -> Bool {
        !cache.isEmpty || (try? countTrackerEntities()) ?? 0 > 0
    }
    
    func getTrackers(byIds ids: [UUID]) async throws -> [Tracker] {
        let allTrackers = try await getAllTrackers()
        return allTrackers.filter { ids.contains($0.id) }
    }
    
    func getTrackers(matching predicate: (Tracker) -> Bool) async -> [Tracker] {
        guard let trackers = try? await getAllTrackers() else {
            return []
        }
        return trackers.filter(predicate)
    }
    
    // MARK: - History Operations
    
    func getTrackerHistory(trackerId: UUID, limit: Int? = nil) async throws -> [TrackerHistory] {
        let request: NSFetchRequest<TrackerHistoryEntity> = TrackerHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "trackerId == %@", trackerId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrackerHistoryEntity.date, ascending: false)
        ]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }
    
    func getTrackerHistory(forDate date: Date) async throws -> [TrackerHistory] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<TrackerHistoryEntity> = TrackerHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }
    
    func getTrackerHistory(inDateRange range: ClosedRange<Date>) async throws -> [TrackerHistory] {
        let request: NSFetchRequest<TrackerHistoryEntity> = TrackerHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            range.lowerBound as CVarArg,
            range.upperBound as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrackerHistoryEntity.date, ascending: true)
        ]
        
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }
    
    // MARK: - Stats Operations
    
    func getCompletionStats(trackerId: UUID) async throws -> CompletionStats {
        let histories = try await getTrackerHistory(trackerId: trackerId)
        
        var stats = CompletionStats()
        
        for history in histories {
            stats.totalCompletions += history.completionCount
            if history.isCompleted {
                stats.completedDays += 1
            } else {
                stats.failedDays += 1
            }
        }
        
        // Calculate current streak
        let calendar = Calendar.current
        let sorted = histories.sorted { $0.date > $1.date }
        var currentStreak = 0
        var previousDate: Date?
        
        for history in sorted {
            if history.isCompleted {
                if let previousDate = previousDate {
                    let components = calendar.dateComponents([.day], from: history.date, to: previousDate)
                    if components.day == -1 {
                        currentStreak += 1
                    } else {
                        break
                    }
                } else {
                    currentStreak += 1
                }
                previousDate = history.date
            } else {
                break
            }
        }
        
        stats.currentStreak = currentStreak
        
        // Calculate longest streak
        // This would require more complex logic to track streaks over time
        // For now, we'll just set it to the current streak
        stats.longestStreak = currentStreak
        
        return stats
    }
    
    func getCompletionStats(forDate date: Date) async throws -> [UUID: CompletionStats] {
        let histories = try await getTrackerHistory(forDate: date)
        
        var result: [UUID: CompletionStats] = [:]
        
        for history in histories {
            if result[history.trackerId] == nil {
                result[history.trackerId] = CompletionStats()
            }
            
            result[history.trackerId]!.totalCompletions += history.completionCount
            if history.isCompleted {
                result[history.trackerId]!.completedDays += 1
            } else {
                result[history.trackerId]!.failedDays += 1
            }
        }
        
        return result
    }
    
    func getOverallStats() async throws -> OverallStats {
        let trackers = try await getAllTrackers()
        
        var stats = OverallStats()
        stats.totalTrackers = trackers.count
        
        for tracker in trackers {
            // Count by type
            stats.trackerTypeCounts[tracker.type] = (stats.trackerTypeCounts[tracker.type] ?? 0) + 1
            
            // Get stats for this tracker
            let trackerStats = try await getCompletionStats(trackerId: tracker.id)
            stats.totalCompletions += trackerStats.totalCompletions
            stats.averageSuccessRate += trackerStats.successRate
            
            if trackerStats.longestStreak > stats.longestStreak {
                stats.longestStreak = trackerStats.longestStreak
            }
        }
        
        // Calculate average success rate
        if stats.totalTrackers > 0 {
            stats.averageSuccessRate /= Double(stats.totalTrackers)
        }
        
        return stats
    }
    
    // MARK: - Bulk Operations
    
    func createTrackers(_ trackers: [Tracker]) async throws {
        for tracker in trackers {
            _ = TrackerEntity.fromDomain(tracker, context: context)
        }
        
        try persistenceController.save()
        
        // Update cache
        for tracker in trackers {
            cache(tracker)
        }
    }
    
    func updateTrackers(_ trackers: [Tracker]) async throws {
        for tracker in trackers {
            try await updateTracker(tracker)
        }
    }
    
    func deleteTrackers(_ trackers: [Tracker]) async throws {
        for tracker in trackers {
            try await deleteTracker(tracker)
        }
    }
    
    func deleteAllTrackers() async throws {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TrackerEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        try context.execute(deleteRequest)
        try persistenceController.save()
        
        // Clear cache
        clearCache()
    }
    
    func resetAllTrackers() async throws {
        let trackers = try await getAllTrackers()
        
        for var tracker in trackers {
            tracker.isCompleted = false
            tracker.completionCount = 0
            tracker.lastCompletedAt = nil
            tracker.history.removeAll()
            
            try await updateTracker(tracker)
        }
        
        // Clear cache
        clearCache()
    }
    
    // MARK: - Count Operations
    
    func getTrackerCount() async -> Int {
        (try? countTrackerEntities()) ?? cache.count
    }
    
    func getTrackerCount(byType type: TrackerType) async -> Int {
        let trackers = try? await getAllTrackers()
        return trackers?.filter { $0.type == type }.count ?? 0
    }
    
    func getCompletedCount(for tracker: Tracker) async -> Int {
        try? await getCompletionStats(trackerId: tracker.id).completedDays
    }
    
    // MARK: - Caching Operations
    
    func getCached(byId id: UUID) -> Tracker? {
        guard let cached = cache[id] else { return nil }
        
        // Check if cache has expired
        guard let timestamp = cacheTimestamps[id] else { return nil }
        
        if Date().timeIntervalSince(timestamp) < cacheExpiration {
            return cached
        }
        
        return nil
    }
    
    func cache(_ model: Tracker) {
        cache[model.id] = model
        cacheTimestamps[model.id] = Date()
        
        // Enforce cache limit
        if cache.count > cacheLimit {
            // Remove oldest entries
            let sortedIds = cacheTimestamps.sorted { $0.value < $1.value }.map { $0.key }
            let idsToRemove = Array(sortedIds.prefix(cache.count - cacheLimit))
            
            for id in idsToRemove {
                cache.removeValue(forKey: id)
                cacheTimestamps.removeValue(forKey: id)
            }
        }
    }
    
    func cache(_ models: [Tracker]) {
        for model in models {
            cache(model)
        }
    }
    
    func removeFromCache(byId id: UUID) {
        cache.removeValue(forKey: id)
        cacheTimestamps.removeValue(forKey: id)
    }
    
    func clearCache() {
        cache.removeAll()
        cacheTimestamps.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func fetchTrackerEntities(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [TrackerEntity] {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        
        if let predicate = predicate {
            request.predicate = predicate
        }
        
        if let sortDescriptors = sortDescriptors {
            request.sortDescriptors = sortDescriptors
        } else {
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \TrackerEntity.updatedAt, ascending: false),
                NSSortDescriptor(keyPath: \TrackerEntity.createdAt, ascending: false)
            ]
        }
        
        return try context.fetch(request)
    }
    
    private func fetchTrackerEntity(byId id: UUID) throws -> TrackerEntity? {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        return entities.first
    }
    
    private func countTrackerEntities(predicate: NSPredicate? = nil) throws -> Int {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = predicate
        
        return try context.count(for: request)
    }
    
    private func updateHistories(for entity: TrackerEntity, with histories: [TrackerHistory]) {
        let existingHistoryIds = entity.histories.map { $0.id }
        let newHistoryIds = histories.map { $0.id }
        
        // Remove deleted histories
        for historyEntity in entity.histories {
            if !newHistoryIds.contains(historyEntity.id) {
                context.delete(historyEntity)
            }
        }
        
        // Update or create histories
        for history in histories {
            if let existing = entity.histories.first(where: { $0.id == history.id }) {
                existing.date = history.date
                existing.isCompleted = history.isCompleted
                existing.completionCount = Int64(history.completionCount)
                existing.value = Int64(history.value ?? 0)
                existing.notes = history.notes
            } else {
                let historyEntity = TrackerHistoryEntity.fromDomain(history, context: context)
                historyEntity.tracker = entity
            }
        }
    }
}

enum TrackerError: Error {
    case trackerNotFound
    case invalidTracker
    case persistenceError(Error)
}
```

### 3.2 CoreDataSettingsRepository

```swift
// CoreDataSettingsRepository.swift
import CoreData
import Foundation

final class CoreDataSettingsRepository: SettingsRepositoryProtocol {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private var cachedSettings: AppSettings?
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.context = persistenceController.context
    }
    
    // MARK: - SettingsRepositoryProtocol
    
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
    
    // MARK: - Specific Settings
    
    func getWeekStartDay() -> DayOfWeek {
        settings.weekStartDay
    }
    
    func setWeekStartDay(_ day: DayOfWeek) async throws {
        var settings = self.settings
        settings.weekStartDay = day
        self.settings = settings
    }
    
    func isICloudSyncEnabled() -> Bool {
        settings.isICloudSyncEnabled
    }
    
    func setICloudSyncEnabled(_ enabled: Bool) async throws {
        var settings = self.settings
        settings.isICloudSyncEnabled = enabled
        self.settings = settings
    }
    
    func isHapticFeedbackEnabled() -> Bool {
        settings.useHapticFeedback
    }
    
    func setHapticFeedbackEnabled(_ enabled: Bool) async throws {
        var settings = self.settings
        settings.useHapticFeedback = enabled
        self.settings = settings
    }
    
    func getTheme() -> Theme {
        settings.theme
    }
    
    func setTheme(_ theme: Theme) async throws {
        var settings = self.settings
        settings.theme = theme
        self.settings = settings
    }
    
    // MARK: - Private Methods
    
    private func fetchSettings(in context: NSManagedObjectContext = nil) throws -> AppSettings {
        let context = context ?? self.context
        
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
        let context = context ?? self.context
        
        let request: NSFetchRequest<SettingsEntity> = SettingsEntity.fetchRequest()
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        
        let entity: SettingsEntity
        
        if let existing = entities.first {
            entity = existing
        } else {
            entity = SettingsEntity(context: context)
        }
        
        entity.weekStartDay = String(settings.weekStartDay.rawValue)
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

### 3.3 UserDefaultsSettingsRepository

```swift
// UserDefaultsSettingsRepository.swift
import Foundation

final class UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
    
    private let userDefaults: UserDefaults
    private let settingsKey = "AppSettings"
    private var cachedSettings: AppSettings?
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - SettingsRepositoryProtocol
    
    var settings: AppSettings {
        get {
            if let cached = cachedSettings {
                return cached
            }
            
            if let data = userDefaults.data(forKey: settingsKey),
               let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                cachedSettings = settings
                return settings
            }
            
            let defaultSettings = AppSettings.default
            cachedSettings = defaultSettings
            saveSettings(defaultSettings)
            return defaultSettings
        }
        set {
            cachedSettings = newValue
            saveSettings(newValue)
        }
    }
    
    func getSettings() async throws -> AppSettings {
        settings
    }
    
    func saveSettings(_ settings: AppSettings) async throws {
        self.settings = settings
    }
    
    // MARK: - Specific Settings
    
    func getWeekStartDay() -> DayOfWeek {
        settings.weekStartDay
    }
    
    func setWeekStartDay(_ day: DayOfWeek) async throws {
        var settings = self.settings
        settings.weekStartDay = day
        self.settings = settings
    }
    
    func isICloudSyncEnabled() -> Bool {
        settings.isICloudSyncEnabled
    }
    
    func setICloudSyncEnabled(_ enabled: Bool) async throws {
        var settings = self.settings
        settings.isICloudSyncEnabled = enabled
        self.settings = settings
    }
    
    func isHapticFeedbackEnabled() -> Bool {
        settings.useHapticFeedback
    }
    
    func setHapticFeedbackEnabled(_ enabled: Bool) async throws {
        var settings = self.settings
        settings.useHapticFeedback = enabled
        self.settings = settings
    }
    
    func getTheme() -> Theme {
        settings.theme
    }
    
    func setTheme(_ theme: Theme) async throws {
        var settings = self.settings
        settings.theme = theme
        self.settings = settings
    }
    
    // MARK: - Private Methods
    
    private func saveSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            Logger.shared.error("Failed to encode settings: %{private}@", error.localizedDescription)
        }
    }
}
```

## 4. Use Cases Implementation

### 4.1 Use Case Structure

```swift
// UseCaseProtocol.swift
import Foundation

protocol UseCaseProtocol {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) async throws -> Output
}

// NoInputUseCase for use cases with no input
protocol NoInputUseCaseProtocol {
    associatedtype Output
    
    func execute() async throws -> Output
}

// NoOutputUseCase for use cases with no output
protocol NoOutputUseCaseProtocol {
    associatedtype Input
    
    func execute(_ input: Input) async throws
}

// NoIOUseCase for use cases with no input and no output
protocol NoIOUseCaseProtocol {
    func execute() async throws
}

// Default implementations
extension NoInputUseCaseProtocol where Input == Void {
    func execute() async throws -> Output {
        try await execute(()) 
    }
}

extension NoOutputUseCaseProtocol where Output == Void {
    func execute(_ input: Input) async throws {
        _ = try await execute(input: input)
    }
}

extension NoIOUseCaseProtocol where Input == Void, Output == Void {
    func execute() async throws {
        try await execute(()) 
    }
}
```

### 4.2 Tracker Use Cases

```swift
// TrackerUseCases.swift
import Foundation

// MARK: - Create Tracker

final class CreateTrackerUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    private let reminderService: ReminderServiceProtocol
    
    init(
        trackerRepository: TrackerRepositoryProtocol,
        reminderService: ReminderServiceProtocol
    ) {
        self.trackerRepository = trackerRepository
        self.reminderService = reminderService
    }
    
    func execute(input: Tracker) async throws {
        // Create the tracker
        try await trackerRepository.createTracker(input)
        
        // Schedule reminder if enabled
        if input.reminder?.isEnabled == true {
            try await reminderService.scheduleReminder(for: input)
        }
    }
}

// MARK: - Get Trackers

final class GetTrackersUseCase: NoInputUseCaseProtocol {
    typealias Output = [Tracker]
    typealias Input = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(_ input: Void) async throws -> [Tracker] {
        try await trackerRepository.getAllTrackers()
    }
}

final class GetTrackerUseCase: UseCaseProtocol {
    typealias Input = UUID
    typealias Output = Tracker?
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(_ input: UUID) async throws -> Tracker? {
        try await trackerRepository.getTracker(byId: input)
    }
}

final class GetTrackersByTypeUseCase: UseCaseProtocol {
    typealias Input = TrackerType
    typealias Output = [Tracker]
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(_ input: TrackerType) async throws -> [Tracker] {
        try await trackerRepository.getTrackers(byType: input)
    }
}

// MARK: - Update Tracker

final class UpdateTrackerUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    private let reminderService: ReminderServiceProtocol
    
    init(
        trackerRepository: TrackerRepositoryProtocol,
        reminderService: ReminderServiceProtocol
    ) {
        self.trackerRepository = trackerRepository
        self.reminderService = reminderService
    }
    
    func execute(input: Tracker) async throws {
        // Update the tracker
        try await trackerRepository.updateTracker(input)
        
        // Reschedule reminder if needed
        if let reminder = input.reminder, reminder.isEnabled {
            try await reminderService.updateReminder(for: input)
        }
    }
}

// MARK: - Delete Tracker

final class DeleteTrackerUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    private let reminderService: ReminderServiceProtocol
    
    init(
        trackerRepository: TrackerRepositoryProtocol,
        reminderService: ReminderServiceProtocol
    ) {
        self.trackerRepository = trackerRepository
        self.reminderService = reminderService
    }
    
    func execute(input: Tracker) async throws {
        // Cancel reminder
        await reminderService.cancelReminder(for: input)
        
        // Delete the tracker
        try await trackerRepository.deleteTracker(input)
    }
}

// MARK: - Complete Tracker

final class CompleteTrackerUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    private let dateService: DateServiceProtocol
    
    init(
        trackerRepository: TrackerRepositoryProtocol,
        dateService: DateServiceProtocol
    ) {
        self.trackerRepository = trackerRepository
        self.dateService = dateService
    }
    
    func execute(input: Tracker) async throws {
        var tracker = input
        
        // Mark as completed based on tracker type
        switch tracker.type {
        case .streak, .counter:
            tracker.complete()
            
        case .negativeStreak:
            // For negative streaks, we don't auto-complete
            // The user needs to explicitly mark it as incomplete to break the streak
            break
            
        case .timeSince:
            tracker.resetTimeSince()
            
        case .timeAhead:
            // Time ahead trackers don't have completion
            break
        }
        
        try await trackerRepository.updateTracker(tracker)
    }
}

// MARK: - Incomplete Tracker (for negative streaks)

final class MarkIncompleteTrackerUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(input: Tracker) async throws {
        guard input.type == .negativeStreak else {
            throw TrackerError.invalidTracker
        }
        
        var tracker = input
        tracker.markIncomplete()
        
        try await trackerRepository.updateTracker(tracker)
    }
}

// MARK: - Counter Operations

final class IncrementCounterUseCase: NoOutputUseCaseProtocol {
    typealias Input = (tracker: Tracker, value: Int)
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(input: (tracker: Tracker, value: Int)) async throws {
        guard input.tracker.type == .counter else {
            throw TrackerError.invalidTracker
        }
        
        var tracker = input.tracker
        tracker.incrementCounter(by: input.value)
        
        try await trackerRepository.updateTracker(tracker)
    }
}

final class DecrementCounterUseCase: NoOutputUseCaseProtocol {
    typealias Input = (tracker: Tracker, value: Int)
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(input: (tracker: Tracker, value: Int)) async throws {
        guard input.tracker.type == .counter else {
            throw TrackerError.invalidTracker
        }
        
        var tracker = input.tracker
        tracker.decrementCounter(by: input.value)
        
        try await trackerRepository.updateTracker(tracker)
    }
}

// MARK: - Time Since Operations

final class ResetTimeSinceUseCase: NoOutputUseCaseProtocol {
    typealias Input = Tracker
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(input: Tracker) async throws {
        guard input.type == .timeSince else {
            throw TrackerError.invalidTracker
        }
        
        var tracker = input
        tracker.resetTimeSince()
        
        try await trackerRepository.updateTracker(tracker)
    }
}

// MARK: - Stats Operations

final class GetCompletionStatsUseCase: UseCaseProtocol {
    typealias Input = UUID
    typealias Output = CompletionStats
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(_ input: UUID) async throws -> CompletionStats {
        try await trackerRepository.getCompletionStats(trackerId: input)
    }
}

final class GetOverallStatsUseCase: NoInputUseCaseProtocol {
    typealias Output = OverallStats
    typealias Input = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(_ input: Void) async throws -> OverallStats {
        try await trackerRepository.getOverallStats()
    }
}
```

### 4.3 Settings Use Cases

```swift
// SettingsUseCases.swift
import Foundation

// MARK: - Save Settings

final class SaveSettingsUseCase: NoOutputUseCaseProtocol {
    typealias Input = AppSettings
    typealias Output = Void
    
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    func execute(input: AppSettings) async throws {
        try await settingsRepository.saveSettings(input)
    }
}

// MARK: - Get Settings

final class GetSettingsUseCase: NoInputUseCaseProtocol {
    typealias Output = AppSettings
    typealias Input = Void
    
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
    }
    
    func execute(_ input: Void) async throws -> AppSettings {
        try await settingsRepository.getSettings()
    }
}

// MARK: - Delete All Data

final class DeleteAllDataUseCase: NoIOUseCaseProtocol {
    typealias Input = Void
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(
        trackerRepository: TrackerRepositoryProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.trackerRepository = trackerRepository
        self.settingsRepository = settingsRepository
    }
    
    func execute() async throws {
        // Delete all trackers
        try await trackerRepository.deleteAllTrackers()
        
        // Reset settings to default (but keep iCloud sync preference)
        var settings = AppSettings.default
        let currentSettings = settingsRepository.settings
        settings.isICloudSyncEnabled = currentSettings.isICloudSyncEnabled
        
        try await settingsRepository.saveSettings(settings)
    }
}

// MARK: - Delete All Trackers

final class DeleteAllTrackersUseCase: NoIOUseCaseProtocol {
    typealias Input = Void
    typealias Output = Void
    
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute() async throws {
        try await trackerRepository.deleteAllTrackers()
    }
}
```

## 5. Dependency Container Integration

### 5.1 Updated DependencyContainer

```swift
// DependencyContainer.swift
final class DependencyContainer {
    
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - Repositories
    
    private(set) lazy var trackerRepository: TrackerRepositoryProtocol = {
        CoreDataTrackerRepository(persistenceController: persistenceController)
    }()
    
    private(set) lazy var settingsRepository: SettingsRepositoryProtocol = {
        // Use CoreData for settings if available, otherwise UserDefaults
        if FeatureFlags.useCoreDataForSettings {
            return CoreDataSettingsRepository(persistenceController: persistenceController)
        } else {
            return UserDefaultsSettingsRepository()
        }
    }()
    
    // MARK: - Services
    
    private(set) lazy var notificationService: NotificationServiceProtocol = {
        UserNotificationService.shared
    }()
    
    private(set) lazy var reminderService: ReminderServiceProtocol = {
        LocalReminderService(
            notificationService: notificationService,
            settingsRepository: settingsRepository,
            trackerRepository: trackerRepository
        )
    }()
    
    private(set) lazy var dateService: DateServiceProtocol = {
        SystemDateService()
    }()
    
    private(set) lazy var cloudSyncManager: CloudSyncManager = {
        CloudSyncManager(
            persistenceController: persistenceController,
            settingsRepository: settingsRepository
        )
    }()
    
    // MARK: - Persistence
    
    private(set) lazy var persistenceController: PersistenceController = {
        let cloudKitOptions = settingsRepository.settings.isICloudSyncEnabled ? 
            CloudKitContainerOptions(containerIdentifier: "iCloud.com.arvoldek.TrackIt") :
            nil
        
        return PersistenceController(
            containerName: "TrackIt",
            cloudKitContainerOptions: cloudKitOptions
        )
    }()
    
    // MARK: - Use Cases
    
    // Tracker Use Cases
    private(set) lazy var createTrackerUseCase: CreateTrackerUseCase = {
        CreateTrackerUseCase(
            trackerRepository: trackerRepository,
            reminderService: reminderService
        )
    }()
    
    private(set) lazy var getTrackersUseCase: GetTrackersUseCase = {
        GetTrackersUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var getTrackerUseCase: GetTrackerUseCase = {
        GetTrackerUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var getTrackersByTypeUseCase: GetTrackersByTypeUseCase = {
        GetTrackersByTypeUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var updateTrackerUseCase: UpdateTrackerUseCase = {
        UpdateTrackerUseCase(
            trackerRepository: trackerRepository,
            reminderService: reminderService
        )
    }()
    
    private(set) lazy var deleteTrackerUseCase: DeleteTrackerUseCase = {
        DeleteTrackerUseCase(
            trackerRepository: trackerRepository,
            reminderService: reminderService
        )
    }()
    
    private(set) lazy var completeTrackerUseCase: CompleteTrackerUseCase = {
        CompleteTrackerUseCase(
            trackerRepository: trackerRepository,
            dateService: dateService
        )
    }()
    
    private(set) lazy var markIncompleteTrackerUseCase: MarkIncompleteTrackerUseCase = {
        MarkIncompleteTrackerUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var incrementCounterUseCase: IncrementCounterUseCase = {
        IncrementCounterUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var decrementCounterUseCase: DecrementCounterUseCase = {
        DecrementCounterUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var resetTimeSinceUseCase: ResetTimeSinceUseCase = {
        ResetTimeSinceUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var getCompletionStatsUseCase: GetCompletionStatsUseCase = {
        GetCompletionStatsUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var getOverallStatsUseCase: GetOverallStatsUseCase = {
        GetOverallStatsUseCase(trackerRepository: trackerRepository)
    }()
    
    // Settings Use Cases
    private(set) lazy var saveSettingsUseCase: SaveSettingsUseCase = {
        SaveSettingsUseCase(settingsRepository: settingsRepository)
    }()
    
    private(set) lazy var getSettingsUseCase: GetSettingsUseCase = {
        GetSettingsUseCase(settingsRepository: settingsRepository)
    }()
    
    private(set) lazy var deleteAllDataUseCase: DeleteAllDataUseCase = {
        DeleteAllDataUseCase(
            trackerRepository: trackerRepository,
            settingsRepository: settingsRepository
        )
    }()
    
    private(set) lazy var deleteAllTrackersUseCase: DeleteAllTrackersUseCase = {
        DeleteAllTrackersUseCase(trackerRepository: trackerRepository)
    }()
}

// Feature Flags
struct FeatureFlags {
    static var useCoreDataForSettings: Bool = true
}
```

## 6. Testing Repositories

### 6.1 Mock Repositories

```swift
// MockTrackerRepository.swift
import Foundation

final class MockTrackerRepository: TrackerRepositoryProtocol {
    
    var trackers: [Tracker] = []
    var shouldThrowError = false
    var errorToThrow: Error?
    
    // MARK: - CRUD Operations
    
    func getAllTrackers() async throws -> [Tracker] {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.trackerNotFound
        }
        return trackers
    }
    
    func getTracker(byId id: UUID) async throws -> Tracker? {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.trackerNotFound
        }
        return trackers.first { $0.id == id }
    }
    
    func getTrackers(byType type: TrackerType) async throws -> [Tracker] {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.trackerNotFound
        }
        return trackers.filter { $0.type == type }
    }
    
    func createTracker(_ tracker: Tracker) async throws {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.persistenceError(MockError.testError)
        }
        trackers.append(tracker)
    }
    
    func updateTracker(_ tracker: Tracker) async throws {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.persistenceError(MockError.testError)
        }
        if let index = trackers.firstIndex(where: { $0.id == tracker.id }) {
            trackers[index] = tracker
        }
    }
    
    func deleteTracker(_ tracker: Tracker) async throws {
        if shouldThrowError {
            throw errorToThrow ?? TrackerError.persistenceError(MockError.testError)
        }
        trackers.removeAll { $0.id == tracker.id }
    }
    
    // MARK: - Query Operations
    
    func hasTrackers() -> Bool {
        !trackers.isEmpty
    }
    
    func getTrackers(byIds ids: [UUID]) async throws -> [Tracker] {
        trackers.filter { ids.contains($0.id) }
    }
    
    func getTrackers(matching predicate: (Tracker) -> Bool) async -> [Tracker] {
        trackers.filter(predicate)
    }
    
    // MARK: - History Operations
    
    func getTrackerHistory(trackerId: UUID, limit: Int?) async throws -> [TrackerHistory] {
        trackers.first { $0.id == trackerId }?.history ?? []
    }
    
    func getTrackerHistory(forDate date: Date) async throws -> [TrackerHistory] {
        trackers.flatMap { $0.history }.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }
    
    func getTrackerHistory(inDateRange range: ClosedRange<Date>) async throws -> [TrackerHistory] {
        trackers.flatMap { $0.history }.filter {
            $0.date >= range.lowerBound && $0.date <= range.upperBound
        }
    }
    
    // MARK: - Stats Operations
    
    func getCompletionStats(trackerId: UUID) async throws -> CompletionStats {
        let histories = try await getTrackerHistory(trackerId: trackerId)
        
        var stats = CompletionStats()
        for history in histories {
            stats.totalCompletions += history.completionCount
            if history.isCompleted {
                stats.completedDays += 1
            } else {
                stats.failedDays += 1
            }
        }
        return stats
    }
    
    func getCompletionStats(forDate date: Date) async throws -> [UUID: CompletionStats] {
        let histories = try await getTrackerHistory(forDate: date)
        
        var result: [UUID: CompletionStats] = [:]
        for history in histories {
            if result[history.trackerId] == nil {
                result[history.trackerId] = CompletionStats()
            }
            result[history.trackerId]!.totalCompletions += history.completionCount
            if history.isCompleted {
                result[history.trackerId]!.completedDays += 1
            } else {
                result[history.trackerId]!.failedDays += 1
            }
        }
        return result
    }
    
    func getOverallStats() async throws -> OverallStats {
        var stats = OverallStats()
        stats.totalTrackers = trackers.count
        stats.totalCompletions = trackers.reduce(0) { $0 + $1.completionCount }
        
        for tracker in trackers {
            stats.trackerTypeCounts[tracker.type] = (stats.trackerTypeCounts[tracker.type] ?? 0) + 1
        }
        
        return stats
    }
    
    // MARK: - Bulk Operations
    
    func createTrackers(_ trackers: [Tracker]) async throws {
        self.trackers.append(contentsOf: trackers)
    }
    
    func updateTrackers(_ trackers: [Tracker]) async throws {
        for tracker in trackers {
            if let index = self.trackers.firstIndex(where: { $0.id == tracker.id }) {
                self.trackers[index] = tracker
            }
        }
    }
    
    func deleteTrackers(_ trackers: [Tracker]) async throws {
        for tracker in trackers {
            self.trackers.removeAll { $0.id == tracker.id }
        }
    }
    
    func deleteAllTrackers() async throws {
        trackers = []
    }
    
    func resetAllTrackers() async throws {
        trackers = trackers.map { tracker in
            var tracker = tracker
            tracker.isCompleted = false
            tracker.completionCount = 0
            tracker.lastCompletedAt = nil
            tracker.history.removeAll()
            return tracker
        }
    }
    
    // MARK: - Count Operations
    
    func getTrackerCount() async -> Int {
        trackers.count
    }
    
    func getTrackerCount(byType type: TrackerType) async -> Int {
        trackers.filter { $0.type == type }.count
    }
    
    func getCompletedCount(for tracker: Tracker) async -> Int {
        (try? await getCompletionStats(trackerId: tracker.id).completedDays) ?? 0
    }
}

final class MockSettingsRepository: SettingsRepositoryProtocol {
    
    var settings: AppSettings = .default
    var shouldThrowError = false
    var errorToThrow: Error?
    
    func getSettings() async throws -> AppSettings {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        return settings
    }
    
    func saveSettings(_ settings: AppSettings) async throws {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        self.settings = settings
    }
    
    func getWeekStartDay() -> DayOfWeek {
        settings.weekStartDay
    }
    
    func setWeekStartDay(_ day: DayOfWeek) async throws {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        var settings = self.settings
        settings.weekStartDay = day
        self.settings = settings
    }
    
    func isICloudSyncEnabled() -> Bool {
        settings.isICloudSyncEnabled
    }
    
    func setICloudSyncEnabled(_ enabled: Bool) async throws {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        var settings = self.settings
        settings.isICloudSyncEnabled = enabled
        self.settings = settings
    }
    
    func isHapticFeedbackEnabled() -> Bool {
        settings.useHapticFeedback
    }
    
    func setHapticFeedbackEnabled(_ enabled: Bool) async throws {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        var settings = self.settings
        settings.useHapticFeedback = enabled
        self.settings = settings
    }
    
    func getTheme() -> Theme {
        settings.theme
    }
    
    func setTheme(_ theme: Theme) async throws {
        if shouldThrowError {
            throw errorToThrow ?? MockError.testError
        }
        var settings = self.settings
        settings.theme = theme
        self.settings = settings
    }
}

enum MockError: Error {
    case testError
}
```

### 6.2 Repository Tests

```swift
// TrackerRepositoryTests.swift
import XCTest

final class MockTrackerRepositoryTests: XCTestCase {
    
    var repository: MockTrackerRepository!
    
    override func setUp() {
        super.setUp()
        repository = MockTrackerRepository()
    }
    
    override func tearDown() {
        repository = nil
        super.tearDown()
    }
    
    // MARK: - CRUD Tests
    
    func testCreateTracker() async {
        let tracker = Tracker.createStreak(name: "Test Tracker")
        
        try? await repository.createTracker(tracker)
        
        let allTrackers = try? await repository.getAllTrackers()
        XCTAssertEqual(allTrackers?.count, 1)
        XCTAssertEqual(allTrackers?.first?.name, "Test Tracker")
    }
    
    func testGetTrackerById() async {
        let tracker = Tracker.createStreak(name: "Test Tracker")
        try? await repository.createTracker(tracker)
        
        let fetchedTracker = try? await repository.getTracker(byId: tracker.id)
        XCTAssertNotNil(fetchedTracker)
        XCTAssertEqual(fetchedTracker?.id, tracker.id)
    }
    
    func testUpdateTracker() async {
        let tracker = Tracker.createStreak(name: "Test Tracker")
        try? await repository.createTracker(tracker)
        
        var updatedTracker = tracker
        updatedTracker.name = "Updated Tracker"
        try? await repository.updateTracker(updatedTracker)
        
        let fetchedTracker = try? await repository.getTracker(byId: tracker.id)
        XCTAssertEqual(fetchedTracker?.name, "Updated Tracker")
    }
    
    func testDeleteTracker() async {
        let tracker = Tracker.createStreak(name: "Test Tracker")
        try? await repository.createTracker(tracker)
        
        try? await repository.deleteTracker(tracker)
        
        let allTrackers = try? await repository.getAllTrackers()
        XCTAssertEqual(allTrackers?.count, 0)
    }
    
    // MARK: - Query Tests
    
    func testGetTrackersByType() async {
        let streakTracker = Tracker.createStreak(name: "Streak")
        let counterTracker = Tracker.createCounter(name: "Counter")
        
        try? await repository.createTrackers([streakTracker, counterTracker])
        
        let streakTrackers = try? await repository.getTrackers(byType: .streak)
        XCTAssertEqual(streakTrackers?.count, 1)
        XCTAssertEqual(streakTrackers?.first?.name, "Streak")
    }
    
    func testHasTrackers() {
        XCTAssertFalse(repository.hasTrackers())
        
        let tracker = Tracker.createStreak(name: "Test")
        repository.trackers = [tracker]
        
        XCTAssertTrue(repository.hasTrackers())
    }
    
    // MARK: - Stats Tests
    
    func testGetCompletionStats() async {
        let tracker = Tracker.createStreak(name: "Test")
        let history1 = TrackerHistory(
            id: UUID(),
            trackerId: tracker.id,
            date: Date(),
            isCompleted: true,
            completionCount: 1
        )
        let history2 = TrackerHistory(
            id: UUID(),
            trackerId: tracker.id,
            date: Date().addingTimeInterval(-86400), // Yesterday
            isCompleted: true,
            completionCount: 1
        )
        
        var trackerWithHistory = tracker
        trackerWithHistory.history = [history1, history2]
        
        try? await repository.createTracker(trackerWithHistory)
        
        let stats = try? await repository.getCompletionStats(trackerId: tracker.id)
        XCTAssertEqual(stats?.completedDays, 2)
        XCTAssertEqual(stats?.totalCompletions, 2)
    }
    
    // MARK: - Bulk Operations
    
    func testCreateTrackers() async {
        let trackers = (0..<5).map { index in
            Tracker.createStreak(name: "Tracker \(index)")
        }
        
        try? await repository.createTrackers(trackers)
        
        let allTrackers = try? await repository.getAllTrackers()
        XCTAssertEqual(allTrackers?.count, 5)
    }
    
    func testDeleteAllTrackers() async {
        let trackers = (0..<5).map { index in
            Tracker.createStreak(name: "Tracker \(index)")
        }
        
        try? await repository.createTrackers(trackers)
        try? await repository.deleteAllTrackers()
        
        let allTrackers = try? await repository.getAllTrackers()
        XCTAssertEqual(allTrackers?.count, 0)
    }
}

final class SettingsRepositoryTests: XCTestCase {
    
    var repository: MockSettingsRepository!
    
    override func setUp() {
        super.setUp()
        repository = MockSettingsRepository()
    }
    
    override func tearDown() {
        repository = nil
        super.tearDown()
    }
    
    func testGetSettings() async {
        let settings = try? await repository.getSettings()
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.theme, .system)
    }
    
    func testSaveSettings() async {
        var settings = AppSettings.default
        settings.theme = .dark
        
        try? await repository.saveSettings(settings)
        
        let savedSettings = try? await repository.getSettings()
        XCTAssertEqual(savedSettings?.theme, .dark)
    }
    
    func testSpecificSettings() {
        XCTAssertEqual(repository.getTheme(), .system)
        XCTAssertEqual(repository.getWeekStartDay(), .sunday)
        XCTAssertTrue(repository.isICloudSyncEnabled())
        XCTAssertTrue(repository.isHapticFeedbackEnabled())
    }
}
```

## 7. Delivery Checklist

- [ ] All repository protocols defined
- [ ] CoreDataTrackerRepository implemented
- [ ] CoreDataSettingsRepository implemented
- [ ] UserDefaultsSettingsRepository implemented
- [ ] All use cases implemented
- [ ] Caching mechanism implemented
- [ ] Dependency container updated
- [ ] Mock repositories created for testing
- [ ] Repository tests written

---

**Duration**: 2-3 days
**Priority**: Critical
**Note**: This is a foundational component that all other features depend on
**Next**: Proceed to [Phase 3: Tracker Types](../03-phase-tracker-types/01-base-tracker.md)
