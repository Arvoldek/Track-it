# Phase 1: Data Models

## Overview

This document defines all the data models for the Track It application, including Core Data entities, Swift domain models, and their relationships. The models are designed to support all tracker types and their associated functionality.

## 1. Domain Models (Swift Structs/Classes)

### 1.1 Tracker Type Enum

```swift
// TrackerType.swift
enum TrackerType: String, Codable, Identifiable {
    case streak = "Streak"
    case negativeStreak = "Negative Streak"
    case timeSince = "Time Since"
    case timeAhead = "Time Ahead"
    case counter = "Counter"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .streak: return "flame.fill"
        case .negativeStreak: return "moon.stars.fill"
        case .timeSince: return "clock.arrow.circlepath"
        case .timeAhead: return "alarm.fill"
        case .counter: return "number"
        }
    }
    
    var color: Color {
        switch self {
        case .streak: return .streak
        case .negativeStreak: return .negativeStreak
        case .timeSince: return .timeSince
        case .timeAhead: return .timeAhead
        case .counter: return .counter
        }
    }
    
    var description: String {
        switch self {
        case .streak: return "Track positive habits and build streaks"
        case .negativeStreak: return "Track habits you want to avoid"
        case .timeSince: return "Count time since a specific event"
        case .timeAhead: return "Count down to an upcoming event"
        case .counter: return "Simple counter for anything"
        }
    }
}
```

### 1.2 Completion Frequency Enum

```swift
// CompletionFrequency.swift
enum CompletionFrequency: String, Codable, CaseIterable, Identifiable {
    case once
    case timesPerDay
    case timesPerWeek
    case timesPerMonth
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .once: return "Once"
        case .timesPerDay: return "Times per day"
        case .timesPerWeek: return "Times per week"
        case .timesPerMonth: return "Times per month"
        }
    }
    
    var unit: String {
        switch self {
        case .once: return "time"
        case .timesPerDay: return "times/day"
        case .timesPerWeek: return "times/week"
        case .timesPerMonth: return "times/month"
        }
    }
}
```

### 1.3 Day of Week Enum

```swift
// DayOfWeek.swift
enum DayOfWeek: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var id: Int { rawValue }
    
    var displayName: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
    
    var shortDisplayName: String {
        Calendar.current.shortWeekdaySymbols[rawValue - 1]
    }
    
    static func fromDate(_ date: Date) -> DayOfWeek {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return DayOfWeek(rawValue: weekday) ?? .sunday
    }
}
```

### 1.4 Reminder Model

```swift
// Reminder.swift
struct Reminder: Codable, Identifiable, Hashable {
    let id: UUID
    var isEnabled: Bool
    var time: Date
    var daysOfWeek: Set<DayOfWeek>
    var repeatInterval: RepeatInterval
    var notificationId: String?
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        time: Date = Date(),
        daysOfWeek: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
        repeatInterval: RepeatInterval = .daily
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.repeatInterval = repeatInterval
    }
    
    func nextOccurrence(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        
        switch repeatInterval {
        case .once:
            return time > date ? time : nil
            
        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = calendar.component(.hour, from: time)
            components.minute = calendar.component(.minute, from: time)
            components.second = calendar.component(.second, from: time)
            
            if let next = calendar.date(from: components), next > date {
                return next
            }
            
            // Next day
            components.day! += 1
            return calendar.date(from: components)
            
        case .weekly:
            let currentWeekday = DayOfWeek.fromDate(date)
            
            // Check if we can use today
            if daysOfWeek.contains(currentWeekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = calendar.component(.hour, from: time)
                components.minute = calendar.component(.minute, from: time)
                components.second = calendar.component(.second, from: time)
                
                if let next = calendar.date(from: components), next > date {
                    return next
                }
            }
            
            // Find next day in the week
            let allDays = DayOfWeek.allCases.sorted { $0.rawValue < $1.rawValue }
            let currentIndex = allDays.firstIndex(of: currentWeekday) ?? 0
            
            for i in 0..<allDays.count {
                let index = (currentIndex + 1 + i) % allDays.count
                let nextDay = allDays[index]
                
                if daysOfWeek.contains(nextDay) {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    let daysToAdd = (nextDay.rawValue - currentWeekday.rawValue + 7) % 7
                    if daysToAdd > 0 {
                        components.day! += daysToAdd
                    }
                    components.hour = calendar.component(.hour, from: time)
                    components.minute = calendar.component(.minute, from: time)
                    components.second = calendar.component(.second, from: time)
                    
                    return calendar.date(from: components)
                }
            }
            
            return nil
        }
    }
}

enum RepeatInterval: String, Codable, CaseIterable, Identifiable {
    case once
    case daily
    case weekly
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}
```

### 1.5 Tracker History Model

```swift
// TrackerHistory.swift
struct TrackerHistory: Codable, Identifiable {
    let id: UUID
    let trackerId: UUID
    let date: Date
    let isCompleted: Bool
    var completionCount: Int
    var value: Int? // For counter trackers
    var notes: String?
    
    var dayOfWeek: DayOfWeek {
        DayOfWeek.fromDate(date)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
```

### 1.6 Base Tracker Model

```swift
// Tracker.swift
struct Tracker: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let type: TrackerType
    var isCompleted: Bool
    var completionCount: Int
    var targetCount: Int
    var completionFrequency: CompletionFrequency
    var autoCompleteDays: Set<DayOfWeek>
    var reminder: Reminder?
    var createdAt: Date
    var updatedAt: Date
    var lastCompletedAt: Date?
    var history: [TrackerHistory]
    
    // Computed properties
    var progress: Double {
        guard targetCount > 0 else { return 1.0 }
        return min(Double(completionCount) / Double(targetCount), 1.0)
    }
    
    var canComplete: Bool {
        switch type {
        case .streak:
            // Can complete once per day
            return !isCompleted || !Calendar.current.isDate(lastCompletedAt ?? Date.distantPast, inSameDayAs: Date())
        case .negativeStreak:
            // Always can "complete" (mark as incomplete to break streak)
            return true
        case .timeSince:
            // Can reset
            return true
        case .timeAhead:
            // Cannot complete (time-based)
            return false
        case .counter:
            // Can always increment
            return true
        }
    }
    
    var streak: Int {
        switch type {
        case .streak, .negativeStreak:
            // Calculate streak from history
            var streak = 0
            let calendar = Calendar.current
            let sortedHistory = history.sorted { $0.date > $1.date }
            
            for history in sortedHistory {
                let isToday = calendar.isDate(history.date, inSameDayAs: Date())
                
                if isToday {
                    if history.isCompleted {
                        streak += 1
                    }
                } else {
                    if history.isCompleted {
                        streak += 1
                    } else {
                        break
                    }
                }
            }
            return streak
            
        case .timeSince:
            // Days since last reset
            guard let lastCompletedAt else { return 0 }
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: lastCompletedAt, to: Date())
            return components.day ?? 0
            
        case .timeAhead:
            // Not applicable
            return 0
            
        case .counter:
            // Not applicable for streaks, but could show consecutive days with threshold met
            return 0
        }
    }
    
    // For counter trackers
    var currentValue: Int {
        history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) })?.value ?? 0
    }
    
    // For time since trackers
    var timeSinceValue: TimeInterval? {
        guard let lastCompletedAt else { return nil }
        return Date().timeIntervalSince(lastCompletedAt)
    }
    
    // For time ahead trackers
    var timeAheadValue: TimeInterval? {
        // Will be implemented in TimeAheadTracker
        return nil
    }
    
    // For threshold checking (counter)
    var isThresholdExceeded: Bool {
        guard type == .counter, let value = currentValue else { return false }
        return value > targetCount
    }
    
    // For auto-completion
    func shouldAutoComplete(on date: Date) -> Bool {
        let day = DayOfWeek.fromDate(date)
        return autoCompleteDays.contains(day)
    }
    
    // Create a completion for today
    mutating func complete() {
        let today = Date()
        let day = DayOfWeek.fromDate(today)
        
        // Check if we already have a completion for today
        if let todayHistory = history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // Update existing
            var updatedHistory = todayHistory
            updatedHistory.isCompleted = true
            updatedHistory.completionCount += 1
            
            if let index = history.firstIndex(where: { $0.id == todayHistory.id }) {
                history[index] = updatedHistory
            }
        } else {
            // Create new
            let newHistory = TrackerHistory(
                id: UUID(),
                trackerId: id,
                date: today,
                isCompleted: true,
                completionCount: 1
            )
            history.append(newHistory)
        }
        
        isCompleted = true
        completionCount += 1
        lastCompletedAt = today
        updatedAt = today
    }
    
    // Create an incompletion for today (for negative streaks)
    mutating func markIncomplete() {
        let today = Date()
        
        if let todayHistory = history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            var updatedHistory = todayHistory
            updatedHistory.isCompleted = false
            
            if let index = history.firstIndex(where: { $0.id == todayHistory.id }) {
                history[index] = updatedHistory
            }
        } else {
            let newHistory = TrackerHistory(
                id: UUID(),
                trackerId: id,
                date: today,
                isCompleted: false,
                completionCount: 0
            )
            history.append(newHistory)
        }
        
        isCompleted = false
        updatedAt = today
    }
    
    // For counter trackers
    mutating func incrementCounter(by value: Int = 1) {
        let today = Date()
        
        if let todayHistory = history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            var updatedHistory = todayHistory
            updatedHistory.value = (updatedHistory.value ?? 0) + value
            
            if let index = history.firstIndex(where: { $0.id == todayHistory.id }) {
                history[index] = updatedHistory
            }
        } else {
            let newHistory = TrackerHistory(
                id: UUID(),
                trackerId: id,
                date: today,
                isCompleted: true,
                completionCount: 1,
                value: value
            )
            history.append(newHistory)
        }
        
        completionCount += 1
        updatedAt = today
    }
    
    // For counter trackers
    mutating func decrementCounter(by value: Int = 1) {
        let today = Date()
        
        if let todayHistory = history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            var updatedHistory = todayHistory
            updatedHistory.value = max(0, (updatedHistory.value ?? 0) - value)
            
            if let index = history.firstIndex(where: { $0.id == todayHistory.id }) {
                history[index] = updatedHistory
            }
        }
        
        updatedAt = today
    }
    
    // For time since trackers
    mutating func resetTimeSince() {
        let now = Date()
        
        // Create history entry
        let newHistory = TrackerHistory(
            id: UUID(),
            trackerId: id,
            date: now,
            isCompleted: true,
            completionCount: 1
        )
        history.append(newHistory)
        
        isCompleted = true
        completionCount += 1
        lastCompletedAt = now
        updatedAt = now
    }
}
```

### 1.7 Tracker Type Specific Models

While the base `Tracker` model handles most functionality, we can create type-specific extensions:

```swift
// StreakTracker.swift
extension Tracker {
    static func createStreak(
        name: String,
        targetCount: Int = 1,
        completionFrequency: CompletionFrequency = .once,
        autoCompleteDays: Set<DayOfWeek> = [],
        reminder: Reminder? = nil
    ) -> Tracker {
        Tracker(
            id: UUID(),
            name: name,
            type: .streak,
            isCompleted: false,
            completionCount: 0,
            targetCount: targetCount,
            completionFrequency: completionFrequency,
            autoCompleteDays: autoCompleteDays,
            reminder: reminder,
            createdAt: Date(),
            updatedAt: Date(),
            lastCompletedAt: nil,
            history: []
        )
    }
}

// NegativeStreakTracker.swift
extension Tracker {
    static func createNegativeStreak(
        name: String,
        targetCount: Int = 1,
        completionFrequency: CompletionFrequency = .once,
        autoCompleteDays: Set<DayOfWeek> = [],
        reminder: Reminder? = nil
    ) -> Tracker {
        Tracker(
            id: UUID(),
            name: name,
            type: .negativeStreak,
            isCompleted: true, // Starts as completed
            completionCount: 0,
            targetCount: targetCount,
            completionFrequency: completionFrequency,
            autoCompleteDays: autoCompleteDays,
            reminder: reminder,
            createdAt: Date(),
            updatedAt: Date(),
            lastCompletedAt: Date(), // Start from today
            history: []
        )
    }
}

// TimeSinceTracker.swift
extension Tracker {
    static func createTimeSince(
        name: String,
        startDate: Date = Date(),
        reminder: Reminder? = nil
    ) -> Tracker {
        Tracker(
            id: UUID(),
            name: name,
            type: .timeSince,
            isCompleted: true,
            completionCount: 0,
            targetCount: 0,
            completionFrequency: .once,
            autoCompleteDays: [],
            reminder: reminder,
            createdAt: Date(),
            updatedAt: Date(),
            lastCompletedAt: startDate,
            history: [
                TrackerHistory(
                    id: UUID(),
                    trackerId: UUID(),
                    date: startDate,
                    isCompleted: true,
                    completionCount: 1
                )
            ]
        )
    }
    
    var timeSinceFormatted: String {
        guard let lastCompletedAt else { return "Never" }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute, .second],
            from: lastCompletedAt,
            to: Date()
        )
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 year" : "\(year) years"
        }
        if let month = components.month, month > 0 {
            return month == 1 ? "1 month" : "\(month) months"
        }
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1 week" : "\(week) weeks"
        }
        if let day = components.day, day > 0 {
            return day == 1 ? "1 day" : "\(day) days"
        }
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour" : "\(hour) hours"
        }
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute" : "\(minute) minutes"
        }
        return "Just now"
    }
}

// TimeAheadTracker.swift
extension Tracker {
    static func createTimeAhead(
        name: String,
        targetDate: Date,
        reminder: Reminder? = nil
    ) -> Tracker {
        Tracker(
            id: UUID(),
            name: name,
            type: .timeAhead,
            isCompleted: false,
            completionCount: 0,
            targetCount: 0,
            completionFrequency: .once,
            autoCompleteDays: [],
            reminder: reminder,
            createdAt: Date(),
            updatedAt: Date(),
            lastCompletedAt: nil,
            history: []
        )
    }
    
    // Store target date in history or as a computed property
    // For simplicity, we'll use the first history entry's date as target
    var targetDate: Date? {
        history.first?.date
    }
    
    var timeAheadFormatted: String {
        guard let targetDate else { return "No target" }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute, .second],
            from: Date(),
            to: targetDate
        )
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 year" : "\(year) years"
        }
        if let month = components.month, month > 0 {
            return month == 1 ? "1 month" : "\(month) months"
        }
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1 week" : "\(week) weeks"
        }
        if let day = components.day, day > 0 {
            return day == 1 ? "1 day" : "\(day) days"
        }
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour" : "\(hour) hours"
        }
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute" : "\(minute) minutes"
        }
        return "0 seconds"
    }
    
    var isTimeAheadExpired: Bool {
        targetDate ?? Date.distantFuture < Date()
    }
}

// CounterTracker.swift
extension Tracker {
    static func createCounter(
        name: String,
        threshold: Int = 0,
        reminder: Reminder? = nil
    ) -> Tracker {
        Tracker(
            id: UUID(),
            name: name,
            type: .counter,
            isCompleted: false,
            completionCount: 0,
            targetCount: threshold,
            completionFrequency: .timesPerDay,
            autoCompleteDays: [],
            reminder: reminder,
            createdAt: Date(),
            updatedAt: Date(),
            lastCompletedAt: nil,
            history: []
        )
    }
    
    var counterDisplayValue: Int {
        currentValue
    }
}
```

### 1.8 Settings Model

```swift
// AppSettings.swift
struct AppSettings: Codable {
    var weekStartDay: DayOfWeek
    var isICloudSyncEnabled: Bool
    var showCompletionAnimation: Bool
    var useHapticFeedback: Bool
    var theme: Theme
    var language: String? // nil = system default
    
    static let `default` = AppSettings(
        weekStartDay: .sunday,
        isICloudSyncEnabled: true,
        showCompletionAnimation: true,
        useHapticFeedback: true,
        theme: .system,
        language: nil
    )
}

enum Theme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
```

## 2. Core Data Models

### 2.1 Core Data Stack Configuration

```swift
// PersistenceController.swift
import CoreData
import CloudKit

final class PersistenceController {
    let container: NSPersistentContainer
    let context: NSManagedObjectContext
    
    init(containerName: String, cloudKitContainerOptions: CloudKitContainerOptions) {
        // Create the persistent container with CloudKit support
        container = NSPersistentContainer(name: containerName)
        
        // Configure CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        description.cloudKitContainerOptions = cloudKitContainerOptions
        
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        // Use the view context for the main thread
        context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        
        // Enable automatic migration
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func deleteAll() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TrackerEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try context.execute(deleteRequest)
        try save()
    }
}

struct CloudKitContainerOptions {
    let containerIdentifier: String
    
    init(containerIdentifier: String = "iCloud.com.arvoldek.TrackIt") {
        self.containerIdentifier = containerIdentifier
    }
}
```

### 2.2 Core Data Entity Definitions

#### TrackerEntity

| Attribute | Type | Optional | Indexed | Notes |
|-----------|------|----------|---------|-------|
| id | UUID | NO | YES | Unique identifier |
| name | String | NO | NO | Tracker name |
| type | String | NO | NO | TrackerType rawValue |
| isCompleted | Bool | NO | NO | Current completion state |
| completionCount | Int64 | NO | NO | Total completions |
| targetCount | Int64 | NO | NO | Target for completion |
| completionFrequency | String | NO | NO | CompletionFrequency rawValue |
| createdAt | Date | NO | NO | Creation timestamp |
| updatedAt | Date | NO | NO | Last update timestamp |
| lastCompletedAt | Date | YES | NO | Last completion timestamp |
| reminderId | UUID | YES | NO | Reference to ReminderEntity |
| settingsId | UUID | YES | NO | Reference to SettingsEntity |

#### TrackerHistoryEntity

| Attribute | Type | Optional | Indexed | Notes |
|-----------|------|----------|---------|-------|
| id | UUID | NO | YES | Unique identifier |
| trackerId | UUID | NO | YES | Reference to TrackerEntity |
| date | Date | NO | YES | Date of the history entry |
| isCompleted | Bool | NO | NO | Completion state for that day |
| completionCount | Int64 | NO | NO | Number of completions that day |
| value | Int64 | YES | NO | Counter value (for counter trackers) |
| notes | String | YES | NO | Optional notes |

#### ReminderEntity

| Attribute | Type | Optional | Indexed | Notes |
|-----------|------|----------|---------|-------|
| id | UUID | NO | YES | Unique identifier |
| isEnabled | Bool | NO | NO | Whether reminder is active |
| time | Date | NO | NO | Time of day for reminder |
| daysOfWeek | String | NO | NO | JSON-encoded Set<DayOfWeek> |
| repeatInterval | String | NO | NO | RepeatInterval rawValue |
| notificationId | String | YES | NO | System notification ID |

#### SettingsEntity

| Attribute | Type | Optional | Indexed | Notes |
|-----------|------|----------|---------|-------|
| id | UUID | NO | YES | Unique identifier (singleton) |
| weekStartDay | String | NO | NO | DayOfWeek rawValue |
| isICloudSyncEnabled | Bool | NO | NO | iCloud sync toggle |
| showCompletionAnimation | Bool | NO | NO | Animation preference |
| useHapticFeedback | Bool | NO | NO | Haptic feedback preference |
| theme | String | NO | NO | Theme rawValue |

### 2.3 Managed Object Subclasses

```swift
// TrackerEntity+CoreDataClass.swift
import CoreData
import Foundation

@objc(TrackerEntity)
public class TrackerEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completionCount: Int64
    @NSManaged public var targetCount: Int64
    @NSManaged public var completionFrequency: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var lastCompletedAt: Date?
    @NSManaged public var reminder: ReminderEntity?
    @NSManaged public var histories: Set<TrackerHistoryEntity>
    
    // Relationship to Settings (one-to-many, but we'll use UserDefaults for settings)
}

// TrackerEntity+CoreDataProperties.swift
extension TrackerEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrackerEntity> {
        NSFetchRequest<TrackerEntity>(entityName: "TrackerEntity")
    }
    
    @NSManaged public var historiesSorted: [TrackerHistoryEntity] {
        histories.sorted { $0.date > $1.date }
    }
    
    func toDomain() -> Tracker {
        Tracker(
            id: id,
            name: name,
            type: TrackerType(rawValue: type) ?? .streak,
            isCompleted: isCompleted,
            completionCount: Int(completionCount),
            targetCount: Int(targetCount),
            completionFrequency: CompletionFrequency(rawValue: completionFrequency) ?? .once,
            autoCompleteDays: [], // Will be populated from reminder
            reminder: reminder?.toDomain(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastCompletedAt: lastCompletedAt,
            history: histories.map { $0.toDomain() }
        )
    }
    
    static func fromDomain(_ tracker: Tracker, context: NSManagedObjectContext) -> TrackerEntity {
        let entity = TrackerEntity(context: context)
        entity.id = tracker.id
        entity.name = tracker.name
        entity.type = tracker.type.rawValue
        entity.isCompleted = tracker.isCompleted
        entity.completionCount = Int64(tracker.completionCount)
        entity.targetCount = Int64(tracker.targetCount)
        entity.completionFrequency = tracker.completionFrequency.rawValue
        entity.createdAt = tracker.createdAt
        entity.updatedAt = tracker.updatedAt
        entity.lastCompletedAt = tracker.lastCompletedAt
        
        if let reminder = tracker.reminder {
            entity.reminder = ReminderEntity.fromDomain(reminder, context: context)
        }
        
        for history in tracker.history {
            let historyEntity = TrackerHistoryEntity.fromDomain(history, context: context)
            historyEntity.tracker = entity
        }
        
        return entity
    }
}

// ReminderEntity+CoreDataClass.swift
@objc(ReminderEntity)
public class ReminderEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var isEnabled: Bool
    @NSManaged public var time: Date
    @NSManaged public var daysOfWeek: String
    @NSManaged public var repeatInterval: String
    @NSManaged public var notificationId: String?
    @NSManaged public var tracker: TrackerEntity?
    
    func toDomain() -> Reminder {
        let days: Set<DayOfWeek> = (try? JSONDecoder().decode(Set<DayOfWeek>.self, from: daysOfWeek.data(using: .utf8)!)) ?? []
        
        return Reminder(
            id: id,
            isEnabled: isEnabled,
            time: time,
            daysOfWeek: days,
            repeatInterval: RepeatInterval(rawValue: repeatInterval) ?? .daily,
            notificationId: notificationId
        )
    }
    
    static func fromDomain(_ reminder: Reminder, context: NSManagedObjectContext) -> ReminderEntity {
        let entity = ReminderEntity(context: context)
        entity.id = reminder.id
        entity.isEnabled = reminder.isEnabled
        entity.time = reminder.time
        
        if let data = try? JSONEncoder().encode(reminder.daysOfWeek) {
            entity.daysOfWeek = String(data: data, encoding: .utf8) ?? ""
        }
        
        entity.repeatInterval = reminder.repeatInterval.rawValue
        entity.notificationId = reminder.notificationId
        
        return entity
    }
}

// TrackerHistoryEntity+CoreDataClass.swift
@objc(TrackerHistoryEntity)
public class TrackerHistoryEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var trackerId: UUID
    @NSManaged public var date: Date
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completionCount: Int64
    @NSManaged public var value: Int64
    @NSManaged public var notes: String?
    @NSManaged public var tracker: TrackerEntity?
    
    func toDomain() -> TrackerHistory {
        TrackerHistory(
            id: id,
            trackerId: trackerId,
            date: date,
            isCompleted: isCompleted,
            completionCount: Int(completionCount),
            value: value > 0 ? Int(value) : nil,
            notes: notes
        )
    }
    
    static func fromDomain(_ history: TrackerHistory, context: NSManagedObjectContext) -> TrackerHistoryEntity {
        let entity = TrackerHistoryEntity(context: context)
        entity.id = history.id
        entity.trackerId = history.trackerId
        entity.date = history.date
        entity.isCompleted = history.isCompleted
        entity.completionCount = Int64(history.completionCount)
        entity.value = Int64(history.value ?? 0)
        entity.notes = history.notes
        
        return entity
    }
}

// SettingsEntity+CoreDataClass.swift
@objc(SettingsEntity)
public class SettingsEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var weekStartDay: String
    @NSManaged public var isICloudSyncEnabled: Bool
    @NSManaged public var showCompletionAnimation: Bool
    @NSManaged public var useHapticFeedback: Bool
    @NSManaged public var theme: String
    
    func toDomain() -> AppSettings {
        AppSettings(
            weekStartDay: DayOfWeek(rawValue: Int(weekStartDay) ?? 1) ?? .sunday,
            isICloudSyncEnabled: isICloudSyncEnabled,
            showCompletionAnimation: showCompletionAnimation,
            useHapticFeedback: useHapticFeedback,
            theme: Theme(rawValue: theme) ?? .system,
            language: nil
        )
    }
    
    static func fromDomain(_ settings: AppSettings, context: NSManagedObjectContext) -> SettingsEntity {
        let entity = SettingsEntity(context: context)
        entity.id = UUID()
        entity.weekStartDay = String(settings.weekStartDay.rawValue)
        entity.isICloudSyncEnabled = settings.isICloudSyncEnabled
        entity.showCompletionAnimation = settings.showCompletionAnimation
        entity.useHapticFeedback = settings.useHapticFeedback
        entity.theme = settings.theme.rawValue
        
        return entity
    }
}
```

### 2.4 Core Data Model Versioning

Create the `.xcdatamodeld` file with:
- **Entity: TrackerEntity**
- **Entity: TrackerHistoryEntity**
- **Entity: ReminderEntity**
- **Entity: SettingsEntity**

Configure:
- Relationships with appropriate delete rules (Cascade for histories)
- Indexes on frequently queried fields (id, type, date, trackerId)
- Constraints on unique fields

## 3. Model Mapping

### 3.1 Repository Pattern Implementation

```swift
// TrackerRepositoryProtocol.swift
protocol TrackerRepositoryProtocol {
    func getAllTrackers() async throws -> [Tracker]
    func getTracker(byId id: UUID) async throws -> Tracker?
    func getTrackers(byType type: TrackerType) async throws -> [Tracker]
    func createTracker(_ tracker: Tracker) async throws
    func updateTracker(_ tracker: Tracker) async throws
    func deleteTracker(_ tracker: Tracker) async throws
    func hasTrackers() -> Bool
    func getTrackerHistory(trackerId: UUID, limit: Int?) async throws -> [TrackerHistory]
    func getTrackerHistory(forDate date: Date) async throws -> [TrackerHistory]
    func getCompletionStats(trackerId: UUID) async throws -> CompletionStats
    func resetAllTrackers() async throws
    func deleteAllTrackers() async throws
}

// CoreDataTrackerRepository.swift
final class CoreDataTrackerRepository: TrackerRepositoryProtocol {
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.context = persistenceController.context
    }
    
    func getAllTrackers() async throws -> [Tracker] {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrackerEntity.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \TrackerEntity.createdAt, ascending: false)
        ]
        
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }
    
    func getTracker(byId id: UUID) async throws -> Tracker? {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        return entities.first?.toDomain()
    }
    
    func getTrackers(byType type: TrackerType) async throws -> [Tracker] {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrackerEntity.updatedAt, ascending: false)
        ]
        
        let entities = try context.fetch(request)
        return entities.map { $0.toDomain() }
    }
    
    func createTracker(_ tracker: Tracker) async throws {
        _ = TrackerEntity.fromDomain(tracker, context: context)
        try persistenceController.save()
    }
    
    func updateTracker(_ tracker: Tracker) async throws {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)
        request.fetchLimit = 1
        
        guard let entity = try context.fetch(request).first else {
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
                existingReminder.notificationId = reminder.notificationId
            } else {
                entity.reminder = ReminderEntity.fromDomain(reminder, context: context)
            }
        } else {
            context.delete(entity.reminder!)
            entity.reminder = nil
        }
        
        // Update histories
        let existingHistoryIds = entity.histories.map { $0.id }
        let newHistoryIds = tracker.history.map { $0.id }
        
        // Remove deleted histories
        for historyEntity in entity.histories {
            if !newHistoryIds.contains(historyEntity.id) {
                context.delete(historyEntity)
            }
        }
        
        // Update or create histories
        for history in tracker.history {
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
        
        try persistenceController.save()
    }
    
    func deleteTracker(_ tracker: Tracker) async throws {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tracker.id as CVarArg)
        request.fetchLimit = 1
        
        guard let entity = try context.fetch(request).first else {
            throw TrackerError.trackerNotFound
        }
        
        context.delete(entity)
        try persistenceController.save()
    }
    
    func hasTrackers() -> Bool {
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
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
        
        // Calculate streak
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
        
        return stats
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
    }
    
    func deleteAllTrackers() async throws {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TrackerEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        try context.execute(deleteRequest)
        try persistenceController.save()
    }
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

enum TrackerError: Error {
    case trackerNotFound
    case invalidTrackerType
    case persistenceError(Error)
}
```

## 4. Delivery Checklist

- [ ] All domain models defined (Tracker, Reminder, History, Settings)
- [ ] Core Data model created (.xcdatamodeld)
- [ ] ManagedObject subclasses created
- [ ] Model mapping functions implemented
- [ ] Repository protocol defined
- [ ] CoreDataTrackerRepository implemented
- [ ] All tracker type extensions created
- [ ] Model tests written

---

**Duration**: 2 days
**Priority**: Critical
**Next**: Proceed to [04-base-classes.md](./04-base-classes.md)
