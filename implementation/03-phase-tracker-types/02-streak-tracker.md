# Phase 3.2: Streak Tracker Implementation

## Overview

This document details the implementation of the **Streak Tracker** type, which tracks positive habits by maintaining daily streaks. The streak increases each day the user completes the habit.

**Part of**: Phase 3 - Tracker Types
**Duration**: 1 day
**Priority**: Critical
**Tracker Type**: Positive habit tracking

## 1. Streak Tracker Specification

### Behavior
- **Initial State**: Incomplete (user must complete it each day)
- **Completion**: User marks as complete to increment streak
- **Streak Logic**: Increments by 1 per day when the last required completion is done
- **Reset**: Streak resets to 0 when the tracker is not completed on a day
- **Multiple Completions**: Streak is incremented only once per day, even if multiple completions are required

### Use Cases
- Tracking daily habits (exercise, meditation, reading)
- Building consistent routines
- Motivation through visual streak counting
- Encouraging daily engagement

### State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    STREAK TRACKER STATE                         │
│                                                              │
│  ┌──────────┐    complete()    ┌──────────┐                  │
│  │          │ ───────────────► │          │                  │
│  │ Incomplete│                  │ Completed│                  │
│  │          │                  │          │                  │
│  └──────────┘ ◄───────────────┘          │                  │
│       ▲                                    │                  │
│       │ new day                           │                  │
│       │ (if not completed yesterday)      │                  │
│       └──────────────────────────────────┘                  │
│                                                              │
│  Streak Counter: Increments when transitioning from         │
│  Incomplete -> Completed on a new day                       │
│  Resets to 0 when staying Incomplete for a day               │
└─────────────────────────────────────────────────────────────┘
```

## 2. Data Model

### Domain Model

```swift
// StreakTracker.swift
import Foundation
import SwiftUI

/// Tracks positive habits with daily streaks
struct StreakTracker: BaseTrackerProtocol {
    // MARK: - Identification
    let id: UUID
    let type: TrackerType = .streak
    
    // MARK: - Basic Information
    var name: String
    var iconName: String { type.iconName }
    var color: Color { type.color }
    var description: String { type.description }
    
    // MARK: - State Management
    var isCompleted: Bool
    var completionDate: Date?
    var lastCompletionCount: Int
    
    // MARK: - Reminder Configuration
    var reminderTime: Date?
    var reminderDays: [DayOfWeek]
    var reminderEnabled: Bool
    
    // MARK: - Completion Rules
    var completionFrequency: CompletionFrequency
    var targetCount: Int
    var autoCompleteDays: [DayOfWeek]
    
    // MARK: - History & Analytics
    var historyEnabled: Bool
    var successRate: Double
    var currentStreak: Int
    var longestStreak: Int
    
    // MARK: - Creation & Modification
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - Type-Specific Properties
    var allowMultipleCompletionsPerDay: Bool
    
    // MARK: - Initialization
    
    init(configuration: TrackerConfiguration) {
        self.id = UUID()
        self.name = configuration.name
        self.isCompleted = configuration.isCompleted ?? false
        self.completionDate = nil
        self.lastCompletionCount = 0
        self.reminderTime = configuration.reminderTime?.date
        self.reminderDays = configuration.reminderDays
        self.reminderEnabled = configuration.reminderEnabled
        self.completionFrequency = configuration.completionFrequency
        self.targetCount = configuration.targetCount
        self.autoCompleteDays = configuration.autoCompleteDays
        self.historyEnabled = configuration.historyEnabled
        self.successRate = 0.0
        self.currentStreak = 0
        self.longestStreak = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Type-specific configuration
        self.allowMultipleCompletionsPerDay = configuration.streakConfiguration?.allowMultipleCompletionsPerDay ?? false
    }
    
    // For loading from persistence
    init(id: UUID, 
         name: String,
         isCompleted: Bool,
         completionDate: Date?,
         lastCompletionCount: Int,
         reminderTime: Date?,
         reminderDays: [DayOfWeek],
         reminderEnabled: Bool,
         completionFrequency: CompletionFrequency,
         targetCount: Int,
         autoCompleteDays: [DayOfWeek],
         historyEnabled: Bool,
         successRate: Double,
         currentStreak: Int,
         longestStreak: Int,
         createdAt: Date,
         updatedAt: Date,
         allowMultipleCompletionsPerDay: Bool) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.lastCompletionCount = lastCompletionCount
        self.reminderTime = reminderTime
        self.reminderDays = reminderDays
        self.reminderEnabled = reminderEnabled
        self.completionFrequency = completionFrequency
        self.targetCount = targetCount
        self.autoCompleteDays = autoCompleteDays
        self.historyEnabled = historyEnabled
        self.successRate = successRate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.allowMultipleCompletionsPerDay = allowMultipleCompletionsPerDay
    }
    
    // MARK: - Actions
    
    mutating func complete() {
        let today = Date()
        let calendar = Calendar.current
        
        // Check if we can complete
        if !allowMultipleCompletionsPerDay {
            // If we don't allow multiple completions, check if already completed today
            if let lastCompletion = completionDate {
                if calendar.isDate(today, inSameDayAs: lastCompletion) {
                    // Already completed today, cannot complete again
                    return
                }
            }
        }
        
        // Check if we've reached the target count for today
        if lastCompletionCount >= targetCount && !allowMultipleCompletionsPerDay {
            // Already reached target, cannot complete more today
            return
        }
        
        // Handle new day transition
        if let lastCompletion = completionDate {
            if !calendar.isDate(today, inSameDayAs: lastCompletion) {
                // New day - handle streak logic
                let daysSinceLast = calendar.dateComponents([.day], from: lastCompletion, to: today).day ?? 0
                
                if daysSinceLast == 1 {
                    // Consecutive day - increment streak
                    currentStreak += 1
                } else if daysSinceLast > 1 {
                    // Non-consecutive day - reset streak
                    currentStreak = 1
                } else {
                    // Same day - just increment count
                    lastCompletionCount += 1
                }
                
                // Reset completion count for new day
                lastCompletionCount = 1
            } else {
                // Same day - just increment count
                lastCompletionCount += 1
            }
        } else {
            // First completion ever
            currentStreak = 1
            lastCompletionCount = 1
        }
        
        // Update completion state
        isCompleted = lastCompletionCount >= targetCount
        completionDate = today
        updatedAt = today
        
        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }
    
    mutating func reset() {
        isCompleted = false
        completionDate = nil
        lastCompletionCount = 0
        currentStreak = 0
        updatedAt = Date()
    }
    
    mutating func update(with configuration: TrackerConfiguration) {
        name = configuration.name
        reminderTime = configuration.reminderTime?.date
        reminderDays = configuration.reminderDays
        reminderEnabled = configuration.reminderEnabled
        completionFrequency = configuration.completionFrequency
        targetCount = configuration.targetCount
        autoCompleteDays = configuration.autoCompleteDays
        historyEnabled = configuration.historyEnabled
        allowMultipleCompletionsPerDay = configuration.streakConfiguration?.allowMultipleCompletionsPerDay ?? allowMultipleCompletionsPerDay
        updatedAt = Date()
    }
    
    func displayValue() -> String {
        if isCompleted {
            return "Day \(currentStreak)"
        } else {
            return "Day \(currentStreak) - Tap to complete"
        }
    }
    
    func detailDisplayValue() -> String {
        if isCompleted {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateString = completionDate?.formatted() ?? "Unknown"
            return "Streak: \(currentStreak) days | Last completed: \(dateString)"
        } else {
            return "Streak: \(currentStreak) days | Not completed today"
        }
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        // Check if today is in auto-complete days
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func nextCompletionDate(after date: Date) -> Date? {
        // For streak trackers, next completion is tomorrow
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: date)
    }
    
    func validate() throws {
        if name.isEmpty {
            throw TrackerError.invalidName
        }
        
        if targetCount < 1 {
            throw TrackerError.invalidTargetCount
        }
    }
}

// MARK: - Conformance to Protocols

extension StreakTracker: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: StreakTracker, rhs: StreakTracker) -> Bool {
        lhs.id == rhs.id
    }
}

extension StreakTracker: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, isCompleted, completionDate, lastCompletionCount
        case reminderTime, reminderDays, reminderEnabled
        case completionFrequency, targetCount, autoCompleteDays
        case historyEnabled, successRate, currentStreak, longestStreak
        case createdAt, updatedAt, allowMultipleCompletionsPerDay
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(completionDate, forKey: .completionDate)
        try container.encode(lastCompletionCount, forKey: .lastCompletionCount)
        try container.encodeIfPresent(reminderTime, forKey: .reminderTime)
        try container.encode(reminderDays, forKey: .reminderDays)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(completionFrequency, forKey: .completionFrequency)
        try container.encode(targetCount, forKey: .targetCount)
        try container.encode(autoCompleteDays, forKey: .autoCompleteDays)
        try container.encode(historyEnabled, forKey: .historyEnabled)
        try container.encode(successRate, forKey: .successRate)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(longestStreak, forKey: .longestStreak)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(allowMultipleCompletionsPerDay, forKey: .allowMultipleCompletionsPerDay)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        let completionDate = try container.decodeIfPresent(Date.self, forKey: .completionDate)
        let lastCompletionCount = try container.decode(Int.self, forKey: .lastCompletionCount)
        let reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        let reminderDays = try container.decode([DayOfWeek].self, forKey: .reminderDays)
        let reminderEnabled = try container.decode(Bool.self, forKey: .reminderEnabled)
        let completionFrequency = try container.decode(CompletionFrequency.self, forKey: .completionFrequency)
        let targetCount = try container.decode(Int.self, forKey: .targetCount)
        let autoCompleteDays = try container.decode([DayOfWeek].self, forKey: .autoCompleteDays)
        let historyEnabled = try container.decode(Bool.self, forKey: .historyEnabled)
        let successRate = try container.decode(Double.self, forKey: .successRate)
        let currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        let longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let allowMultipleCompletionsPerDay = try container.decode(Bool.self, forKey: .allowMultipleCompletionsPerDay)
        
        self.init(id: id,
                  name: name,
                  isCompleted: isCompleted,
                  completionDate: completionDate,
                  lastCompletionCount: lastCompletionCount,
                  reminderTime: reminderTime,
                  reminderDays: reminderDays,
                  reminderEnabled: reminderEnabled,
                  completionFrequency: completionFrequency,
                  targetCount: targetCount,
                  autoCompleteDays: autoCompleteDays,
                  historyEnabled: historyEnabled,
                  successRate: successRate,
                  currentStreak: currentStreak,
                  longestStreak: longestStreak,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                  allowMultipleCompletionsPerDay: allowMultipleCompletionsPerDay)
    }
}
```

### Core Data Entity Extension

For mapping between domain model and Core Data:

```swift
// CoreDataTrackerRepository+Streak.swift
extension CoreDataTrackerRepository {
    
    func saveStreakTracker(_ tracker: StreakTracker) throws {
        let context = persistenceController.viewContext
        
        let entity: TrackerEntity
        if let existing = fetchTrackerEntity(by: tracker.id) {
            entity = existing
        } else {
            entity = TrackerEntity(context: context)
            entity.id = tracker.id
            entity.type = tracker.type.rawValue
            entity.createdAt = tracker.createdAt
        }
        
        // Common properties
        entity.name = tracker.name
        entity.isCompleted = tracker.isCompleted
        entity.completionDate = tracker.completionDate
        entity.lastCompletionCount = Int64(tracker.lastCompletionCount)
        entity.reminderTime = tracker.reminderTime
        entity.reminderDays = tracker.reminderDays.map { $0.rawValue }.joined(separator: ",")
        entity.reminderEnabled = tracker.reminderEnabled
        entity.completionFrequency = tracker.completionFrequency.rawValue
        entity.targetCount = Int64(tracker.targetCount)
        entity.autoCompleteDays = tracker.autoCompleteDays.map { $0.rawValue }.joined(separator: ",")
        entity.historyEnabled = tracker.historyEnabled
        entity.successRate = tracker.successRate
        entity.currentStreak = Int64(tracker.currentStreak)
        entity.longestStreak = Int64(tracker.longestStreak)
        entity.updatedAt = tracker.updatedAt
        
        // Type-specific properties (stored in userInfo as JSON)
        let typeConfig = StreakTrackerTypeConfig(
            allowMultipleCompletionsPerDay: tracker.allowMultipleCompletionsPerDay
        )
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(typeConfig) {
            entity.typeConfiguration = String(data: data, encoding: .utf8)
        }
        
        try context.save()
    }
    
    func loadStreakTracker(from entity: TrackerEntity) -> StreakTracker? {
        guard entity.type == TrackerType.streak.rawValue else { return nil }
        
        let id = entity.id ?? UUID()
        let name = entity.name ?? ""
        let isCompleted = entity.isCompleted
        let completionDate = entity.completionDate
        let lastCompletionCount = Int(entity.lastCompletionCount)
        
        // Parse reminder days
        let reminderDays: [DayOfWeek] = (entity.reminderDays ?? "")
            .components(separatedBy: ",")
            .compactMap { DayOfWeek(rawValue: Int($0) ?? 0) }
        
        // Parse auto complete days
        let autoCompleteDays: [DayOfWeek] = (entity.autoCompleteDays ?? "")
            .components(separatedBy: ",")
            .compactMap { DayOfWeek(rawValue: Int($0) ?? 0) }
        
        let reminderTime = entity.reminderTime
        let reminderEnabled = entity.reminderEnabled
        let completionFrequency = CompletionFrequency(rawValue: entity.completionFrequency ?? "once") ?? .once
        let targetCount = Int(entity.targetCount)
        let historyEnabled = entity.historyEnabled
        let successRate = entity.successRate
        let currentStreak = Int(entity.currentStreak)
        let longestStreak = Int(entity.longestStreak)
        let createdAt = entity.createdAt ?? Date()
        let updatedAt = entity.updatedAt ?? Date()
        
        // Parse type-specific configuration
        var allowMultipleCompletionsPerDay = false
        if let typeConfigString = entity.typeConfiguration,
           let data = typeConfigString.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let typeConfig = try? decoder.decode(StreakTrackerTypeConfig.self, from: data) {
                allowMultipleCompletionsPerDay = typeConfig.allowMultipleCompletionsPerDay
            }
        }
        
        return StreakTracker(
            id: id,
            name: name,
            isCompleted: isCompleted,
            completionDate: completionDate,
            lastCompletionCount: lastCompletionCount,
            reminderTime: reminderTime,
            reminderDays: reminderDays,
            reminderEnabled: reminderEnabled,
            completionFrequency: completionFrequency,
            targetCount: targetCount,
            autoCompleteDays: autoCompleteDays,
            historyEnabled: historyEnabled,
            successRate: successRate,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            createdAt: createdAt,
            updatedAt: updatedAt,
            allowMultipleCompletionsPerDay: allowMultipleCompletionsPerDay
        )
    }
    
    private struct StreakTrackerTypeConfig: Codable {
        let allowMultipleCompletionsPerDay: Bool
    }
}
```

## 3. Streak Calculation Logic

### Streak Manager

```swift
// StreakManager.swift
import Foundation

/// Manages streak calculations and logic
protocol StreakManager {
    /// Calculates the current streak for a tracker
    func calculateCurrentStreak(for tracker: StreakTracker, upTo date: Date) -> Int
    
    /// Calculates the longest streak for a tracker
    func calculateLongestStreak(for tracker: StreakTracker, history: [TrackerHistoryEntity]) -> Int
    
    /// Checks if the streak should be incremented today
    func shouldIncrementStreak(for tracker: StreakTracker, on date: Date) -> Bool
    
    /// Checks if the streak should be reset
    func shouldResetStreak(for tracker: StreakTracker, on date: Date) -> Bool
}

/// Default implementation of StreakManager
struct DefaultStreakManager: StreakManager {
    func calculateCurrentStreak(for tracker: StreakTracker, upTo date: Date) -> Int {
        let calendar = Calendar.current
        guard let lastCompletion = tracker.completionDate else {
            return 0
        }
        
        // Check if we completed today
        if calendar.isDate(date, inSameDayAs: lastCompletion) {
            // If completed today, check if it's consecutive
            let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            if tracker.lastCompletionCount >= tracker.targetCount {
                // Check if we completed yesterday
                // This would require checking history
                // For simplicity, we'll use the current streak stored in the tracker
                return tracker.currentStreak
            }
        }
        
        // Check days since last completion
        let daysSinceLast = calendar.dateComponents([.day], from: lastCompletion, to: date).day ?? 0
        
        if daysSinceLast == 0 {
            // Same day, return current streak
            return tracker.currentStreak
        } else if daysSinceLast == 1 {
            // Yesterday, check if we completed yesterday
            // If we did, increment streak; otherwise reset
            return tracker.currentStreak + (tracker.isCompleted ? 1 : 0)
        } else {
            // More than 1 day ago, streak is broken
            return 0
        }
    }
    
    func calculateLongestStreak(for tracker: StreakTracker, history: [TrackerHistoryEntity]) -> Int {
        // Calculate longest streak from history
        // This is a simplified version - actual implementation would analyze history
        
        var maxStreak = 0
        var currentStreak = 0
        
        let sortedHistory = history.sorted { $0.date < $1.date }
        var previousDate: Date? = nil
        
        for entry in sortedHistory {
            if entry.isCompleted {
                if let previous = previousDate {
                    let calendar = Calendar.current
                    let daysBetween = calendar.dateComponents([.day], from: previous, to: entry.date).day ?? 0
                    
                    if daysBetween == 1 {
                        // Consecutive day
                        currentStreak += 1
                    } else if daysBetween == 0 {
                        // Same day
                        continue
                    } else {
                        // Non-consecutive, reset
                        maxStreak = max(maxStreak, currentStreak)
                        currentStreak = 1
                    }
                } else {
                    // First completion
                    currentStreak = 1
                }
            } else {
                // Not completed, reset
                maxStreak = max(maxStreak, currentStreak)
                currentStreak = 0
            }
            
            previousDate = entry.date
        }
        
        maxStreak = max(maxStreak, currentStreak)
        return maxStreak
    }
    
    func shouldIncrementStreak(for tracker: StreakTracker, on date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Check if we're completing for the first time today
        if let lastCompletion = tracker.completionDate {
            if !calendar.isDate(date, inSameDayAs: lastCompletion) {
                // New day, check if yesterday was completed
                let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
                if calendar.isDate(lastCompletion, inSameDayAs: yesterday) {
                    // Yesterday was completed, increment streak
                    return true
                }
            }
        } else {
            // First completion ever, start streak
            return true
        }
        
        return false
    }
    
    func shouldResetStreak(for tracker: StreakTracker, on date: Date) -> Bool {
        let calendar = Calendar.current
        
        // Check if we're starting a new day without completing yesterday
        if let lastCompletion = tracker.completionDate {
            if !calendar.isDate(date, inSameDayAs: lastCompletion) {
                // New day, check if yesterday was NOT completed
                let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
                if !calendar.isDate(lastCompletion, inSameDayAs: yesterday) {
                    // Yesterday was not completed, reset streak
                    return true
                }
            }
        }
        
        return false
    }
}
```

## 4. State Manager for Streak Tracker

```swift
// StreakTrackerStateManager.swift
import Foundation

/// Manages state transitions specific to streak trackers
struct StreakTrackerStateManager: TrackerStateManager {
    
    private let streakManager: StreakManager
    
    init(streakManager: StreakManager = DefaultStreakManager()) {
        self.streakManager = streakManager
    }
    
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        guard var streakTracker = tracker as? StreakTracker else {
            fatalError("Expected StreakTracker")
        }
        
        let calendar = Calendar.current
        
        // Check if we can complete
        if !streakTracker.allowMultipleCompletionsPerDay {
            if streakTracker.lastCompletionCount >= streakTracker.targetCount {
                if let lastCompletion = streakTracker.completionDate,
                   calendar.isDate(date, inSameDayAs: lastCompletion) {
                    // Already reached target for today
                    return TrackerState(
                        isCompleted: streakTracker.isCompleted,
                        completionCount: streakTracker.lastCompletionCount,
                        lastCompletionDate: streakTracker.completionDate,
                        currentStreak: streakTracker.currentStreak
                    )
                }
            }
        }
        
        // Check for new day
        if let lastCompletion = streakTracker.completionDate {
            if !calendar.isDate(date, inSameDayAs: lastCompletion) {
                // New day - check streak logic
                if streakManager.shouldIncrementStreak(for: streakTracker, on: date) {
                    streakTracker.currentStreak += 1
                } else if streakManager.shouldResetStreak(for: streakTracker, on: date) {
                    streakTracker.currentStreak = 0
                }
                
                // Reset count for new day
                streakTracker.lastCompletionCount = 0
            }
        } else {
            // First completion ever
            streakTracker.currentStreak = max(streakTracker.currentStreak, 1)
        }
        
        // Increment completion count
        streakTracker.lastCompletionCount += 1
        
        // Update completion state
        streakTracker.isCompleted = streakTracker.lastCompletionCount >= streakTracker.targetCount
        streakTracker.completionDate = date
        streakTracker.updatedAt = date
        
        // Update longest streak
        if streakTracker.currentStreak > streakTracker.longestStreak {
            streakTracker.longestStreak = streakTracker.currentStreak
        }
        
        tracker = streakTracker
        
        return TrackerState(
            isCompleted: streakTracker.isCompleted,
            completionCount: streakTracker.lastCompletionCount,
            lastCompletionDate: streakTracker.completionDate,
            currentStreak: streakTracker.currentStreak
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        guard var streakTracker = tracker as? StreakTracker else {
            fatalError("Expected StreakTracker")
        }
        
        streakTracker.isCompleted = false
        streakTracker.completionDate = nil
        streakTracker.lastCompletionCount = 0
        streakTracker.currentStreak = 0
        streakTracker.updatedAt = Date()
        
        tracker = streakTracker
        
        return TrackerState(
            isCompleted: false,
            completionCount: 0,
            lastCompletionDate: nil,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        guard var streakTracker = tracker as? StreakTracker else {
            fatalError("Expected StreakTracker")
        }
        
        let calendar = Calendar.current
        
        // Check if we should auto-complete
        let shouldComplete = streakTracker.shouldAutoComplete(today: newDate)
        
        if shouldComplete {
            // Auto-complete logic
            if streakManager.shouldIncrementStreak(for: streakTracker, on: newDate) {
                streakTracker.currentStreak += 1
            }
            
            streakTracker.isCompleted = true
            streakTracker.completionDate = newDate
            streakTracker.lastCompletionCount = streakTracker.targetCount
        } else {
            // Not auto-completing, check if streak should reset
            if streakManager.shouldResetStreak(for: streakTracker, on: newDate) {
                streakTracker.currentStreak = 0
            }
            
            streakTracker.isCompleted = false
            streakTracker.completionDate = nil
            streakTracker.lastCompletionCount = 0
        }
        
        streakTracker.updatedAt = newDate
        tracker = streakTracker
        
        return TrackerState(
            isCompleted: streakTracker.isCompleted,
            completionCount: streakTracker.lastCompletionCount,
            lastCompletionDate: streakTracker.completionDate,
            currentStreak: streakTracker.currentStreak
        )
    }
}
```

## 5. Use Cases for Streak Tracker

```swift
// CompleteStreakTrackerUseCase.swift
import Foundation

/// Completes a streak tracker
struct CompleteStreakTrackerUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    private let stateManager: TrackerStateManager
    
    init(trackerRepository: TrackerRepositoryProtocol, 
         stateManager: TrackerStateManager = StreakTrackerStateManager()) {
        self.trackerRepository = trackerRepository
        self.stateManager = stateManager
    }
    
    func execute(trackerId: UUID) async throws -> StreakTracker {
        // Fetch tracker
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? StreakTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // Validate
        try tracker.validate()
        
        // Complete the tracker
        let _ = stateManager.handleCompletion(for: &tracker, on: Date())
        
        // Save changes
        try await trackerRepository.updateTracker(tracker)
        
        // Record history
        if tracker.historyEnabled {
            try await trackerRepository.recordCompletion(for: trackerId, on: Date())
        }
        
        return tracker
    }
}

// ResetStreakTrackerUseCase.swift
struct ResetStreakTrackerUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    private let stateManager: TrackerStateManager
    
    init(trackerRepository: TrackerRepositoryProtocol, 
         stateManager: TrackerStateManager = StreakTrackerStateManager()) {
        self.trackerRepository = trackerRepository
        self.stateManager = stateManager
    }
    
    func execute(trackerId: UUID) async throws -> StreakTracker {
        // Fetch tracker
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? StreakTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // Reset the tracker
        let _ = stateManager.handleReset(for: &tracker)
        
        // Save changes
        try await trackerRepository.updateTracker(tracker)
        
        // Record reset in history
        if tracker.historyEnabled {
            try await trackerRepository.recordReset(for: trackerId, on: Date())
        }
        
        return tracker
    }
}

// GetStreakStatsUseCase.swift
struct GetStreakStatsUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    private let streakManager: StreakManager
    
    init(trackerRepository: TrackerRepositoryProtocol,
         streakManager: StreakManager = DefaultStreakManager()) {
        self.trackerRepository = trackerRepository
        self.streakManager = streakManager
    }
    
    func execute(trackerId: UUID) async throws -> StreakStats {
        // Fetch tracker
        guard let tracker = try await trackerRepository.getTracker(by: trackerId) as? StreakTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // Fetch history
        let history = try await trackerRepository.getHistory(for: trackerId)
        
        // Calculate stats
        let currentStreak = streakManager.calculateCurrentStreak(for: tracker, upTo: Date())
        let longestStreak = streakManager.calculateLongestStreak(for: tracker, history: history)
        
        // Calculate success rate
        let successRate = calculateSuccessRate(tracker: tracker, history: history)
        
        return StreakStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            successRate: successRate,
            totalCompletions: history.filter { $0.isCompleted }.count,
            totalDays: history.count
        )
    }
    
    private func calculateSuccessRate(tracker: StreakTracker, history: [TrackerHistoryEntity]) -> Double {
        guard !history.isEmpty else { return 0.0 }
        
        let completedDays = history.filter { $0.isCompleted }.count
        return Double(completedDays) / Double(history.count)
    }
}

/// Statistics for streak tracker
struct StreakStats: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let successRate: Double
    let totalCompletions: Int
    let totalDays: Int
    
    var displaySuccessRate: String {
        String(format: "%.1f%%", successRate * 100)
    }
}
```

## 6. Tests

### Unit Tests

```swift
// StreakTrackerTests.swift
import XCTest

final class StreakTrackerTests: XCTestCase {
    
    var configuration: TrackerConfiguration!
    var tracker: StreakTracker!
    
    override func setUp() {
        super.setUp()
        configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test Streak"
        configuration.targetCount = 1
        tracker = StreakTracker(configuration: configuration)
    }
    
    override func tearDown() {
        configuration = nil
        tracker = nil
        super.tearDown()
    }
    
    // MARK: - Initialization
    
    func testInitialization() {
        XCTAssertEqual(tracker.type, .streak)
        XCTAssertEqual(tracker.name, "Test Streak")
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertNil(tracker.completionDate)
        XCTAssertEqual(tracker.lastCompletionCount, 0)
        XCTAssertEqual(tracker.currentStreak, 0)
        XCTAssertEqual(tracker.longestStreak, 0)
    }
    
    // MARK: - Completion
    
    func testSingleCompletion() {
        tracker.complete()
        
        XCTAssertTrue(tracker.isCompleted)
        XCTAssertNotNil(tracker.completionDate)
        XCTAssertEqual(tracker.lastCompletionCount, 1)
        XCTAssertEqual(tracker.currentStreak, 1)
        XCTAssertEqual(tracker.longestStreak, 1)
    }
    
    func testMultipleCompletionsSameDay() {
        configuration.allowMultipleCompletionsPerDay = true
        configuration.targetCount = 3
        tracker = StreakTracker(configuration: configuration)
        
        // First completion
        tracker.complete()
        XCTAssertFalse(tracker.isCompleted) // Not yet reached target
        XCTAssertEqual(tracker.lastCompletionCount, 1)
        
        // Second completion
        tracker.complete()
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertEqual(tracker.lastCompletionCount, 2)
        
        // Third completion
        tracker.complete()
        XCTAssertTrue(tracker.isCompleted) // Reached target
        XCTAssertEqual(tracker.lastCompletionCount, 3)
        XCTAssertEqual(tracker.currentStreak, 1)
    }
    
    func testConsecutiveDayCompletion() {
        // Simulate first day
        tracker.complete()
        XCTAssertEqual(tracker.currentStreak, 1)
        
        // Simulate next day (24 hours later)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        // We need to simulate a new day - this would normally be handled by the system
        // For testing, we'll manually adjust dates
        var trackerCopy = tracker
        trackerCopy.completionDate = Calendar.current.date(byAdding: .day, value: -1, to: tomorrow)
        trackerCopy.complete()
        
        XCTAssertEqual(trackerCopy.currentStreak, 2)
    }
    
    // MARK: - Reset
    
    func testReset() {
        tracker.complete()
        XCTAssertTrue(tracker.isCompleted)
        XCTAssertEqual(tracker.currentStreak, 1)
        
        tracker.reset()
        
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertNil(tracker.completionDate)
        XCTAssertEqual(tracker.lastCompletionCount, 0)
        XCTAssertEqual(tracker.currentStreak, 0)
    }
    
    // MARK: - Display Values
    
    func testDisplayValue() {
        XCTAssertEqual(tracker.displayValue(), "Day 0 - Tap to complete")
        
        tracker.complete()
        XCTAssertEqual(tracker.displayValue(), "Day 1")
    }
    
    // MARK: - Validation
    
    func testValidationValid() {
        XCTAssertNoThrow(try tracker.validate())
    }
    
    func testValidationEmptyName() {
        tracker.name = ""
        XCTAssertThrowsError(try tracker.validate()) { error in
            XCTAssertEqual(error as? TrackerError, TrackerError.invalidName)
        }
    }
    
    func testValidationInvalidTargetCount() {
        tracker.targetCount = 0
        XCTAssertThrowsError(try tracker.validate()) { error in
            XCTAssertEqual(error as? TrackerError, TrackerError.invalidTargetCount)
        }
    }
    
    // MARK: - Codable
    
    func testEncodingDecoding() {
        tracker.complete()
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(tracker)
        
        let decoder = JSONDecoder()
        let decodedTracker = try! decoder.decode(StreakTracker.self, from: data)
        
        XCTAssertEqual(decodedTracker.id, tracker.id)
        XCTAssertEqual(decodedTracker.name, tracker.name)
        XCTAssertEqual(decodedTracker.isCompleted, tracker.isCompleted)
        XCTAssertEqual(decodedTracker.currentStreak, tracker.currentStreak)
    }
}

// StreakManagerTests.swift
final class StreakManagerTests: XCTestCase {
    
    var streakManager: DefaultStreakManager!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        streakManager = DefaultStreakManager()
        calendar = Calendar.current
    }
    
    func testShouldIncrementStreakFirstCompletion() {
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test"
        let tracker = StreakTracker(configuration: configuration)
        
        XCTAssertTrue(streakManager.shouldIncrementStreak(for: tracker, on: Date()))
    }
    
    func testShouldIncrementStreakConsecutiveDay() {
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test"
        var tracker = StreakTracker(configuration: configuration)
        
        // Simulate completion yesterday
        tracker.completionDate = calendar.date(byAdding: .day, value: -1, to: Date())
        tracker.isCompleted = true
        
        XCTAssertTrue(streakManager.shouldIncrementStreak(for: tracker, on: Date()))
    }
    
    func testShouldNotIncrementStreakNonConsecutive() {
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test"
        var tracker = StreakTracker(configuration: configuration)
        
        // Simulate completion 2 days ago
        tracker.completionDate = calendar.date(byAdding: .day, value: -2, to: Date())
        tracker.isCompleted = true
        
        XCTAssertFalse(streakManager.shouldIncrementStreak(for: tracker, on: Date()))
    }
}

// StreakTrackerStateManagerTests.swift
final class StreakTrackerStateManagerTests: XCTestCase {
    
    var stateManager: StreakTrackerStateManager!
    
    override func setUp() {
        super.setUp()
        stateManager = StreakTrackerStateManager()
    }
    
    func testHandleCompletion() {
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test"
        var tracker = StreakTracker(configuration: configuration)
        
        let state = stateManager.handleCompletion(for: &tracker, on: Date())
        
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.completionCount, 1)
        XCTAssertEqual(state.currentStreak, 1)
    }
    
    func testHandleReset() {
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test"
        var tracker = StreakTracker(configuration: configuration)
        
        // Complete first
        stateManager.handleCompletion(for: &tracker, on: Date())
        
        // Then reset
        let state = stateManager.handleReset(for: &tracker)
        
        XCTAssertFalse(state.isCompleted)
        XCTAssertEqual(state.completionCount, 0)
        XCTAssertEqual(state.currentStreak, 0)
    }
}
```

## 7. Checklist

### Implementation
- [ ] `StreakTracker` struct implemented
- [ ] All `BaseTrackerProtocol` methods implemented
- [ ] Streak calculation logic correct
- [ ] State transitions work correctly
- [ ] Auto-completion works on specified days
- [ ] Multiple completion logic works

### Core Data Integration
- [ ] Mapping to/from Core Data entity
- [ ] Type-specific configuration stored
- [ ] All properties persisted correctly

### Use Cases
- [ ] `CompleteStreakTrackerUseCase` implemented
- [ ] `ResetStreakTrackerUseCase` implemented
- [ ] `GetStreakStatsUseCase` implemented

### Tests
- [ ] Unit tests for StreakTracker
- [ ] Unit tests for StreakManager
- [ ] Unit tests for StreakTrackerStateManager
- [ ] Test coverage >= 95%

## 8. Success Criteria

- [ ] Streak tracker works as specified
- [ ] Streak increments correctly for consecutive days
- [ ] Streak resets correctly when day is missed
- [ ] Multiple completions per day work when enabled
- [ ] Auto-completion works on specified days
- [ ] All unit tests pass
- [ ] Code compiles without errors or warnings

## 9. Next Steps

Proceed to implement the next tracker type:
- [03-negative-streak-tracker.md](03-negative-streak-tracker.md) - Negative Streak Tracker

---

**Phase**: 3 - Tracker Types  
**Section**: 3.2 - Streak Tracker  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2, 3.1 (Base Tracker)  
**Last Updated**: [Date]  
**Version**: 1.0
