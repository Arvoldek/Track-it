# Phase 3.1: Base Tracker Implementation

## Overview

This document defines the base tracker protocol and common functionality shared by all tracker types. The base tracker provides the foundation upon which all specific tracker types are built.

**Part of**: Phase 3 - Tracker Types
**Duration**: 1 day
**Priority**: Critical

## 1. Base Tracker Protocol

The `BaseTrackerProtocol` defines the common interface that all tracker types must implement. This ensures consistency across all tracker types while allowing for type-specific behavior.

### Protocol Definition

```swift
// BaseTrackerProtocol.swift
import Foundation
import SwiftUI

/// Defines the common interface for all tracker types
protocol BaseTrackerProtocol: Identifiable, Hashable, Codable {
    // MARK: - Identification
    var id: UUID { get }
    var type: TrackerType { get }
    
    // MARK: - Basic Information
    var name: String { get set }
    var iconName: String { get }
    var color: Color { get }
    var description: String { get }
    
    // MARK: - State Management
    var isCompleted: Bool { get set }
    var completionDate: Date? { get set }
    var lastCompletionCount: Int { get set }
    
    // MARK: - Reminder Configuration
    var reminderTime: Date? { get set }
    var reminderDays: [DayOfWeek] { get set }
    var reminderEnabled: Bool { get set }
    
    // MARK: - Completion Rules
    var completionFrequency: CompletionFrequency { get set }
    var targetCount: Int { get set }
    var autoCompleteDays: [DayOfWeek] { get set }
    
    // MARK: - History & Analytics
    var historyEnabled: Bool { get set }
    var successRate: Double { get }
    var currentStreak: Int { get }
    var longestStreak: Int { get }
    
    // MARK: - Creation & Modification
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    
    // MARK: - Actions
    /// Completes the tracker according to its type-specific logic
    mutating func complete()
    
    /// Resets the tracker to its initial state
    mutating func reset()
    
    /// Updates the tracker with new configuration
    mutating func update(with configuration: TrackerConfiguration)
    
    /// Calculates the display value for the tracker
    func displayValue() -> String
    
    /// Calculates the detail display value (more detailed)
    func detailDisplayValue() -> String
    
    /// Determines if the tracker should auto-complete today
    func shouldAutoComplete(today: Date) -> Bool
    
    /// Calculates the next completion date
    func nextCompletionDate(after date: Date) -> Date?
    
    /// Validates the tracker configuration
    func validate() throws
}
```

### Default Implementations

```swift
// BaseTrackerProtocol+Defaults.swift
extension BaseTrackerProtocol {
    var iconName: String {
        type.iconName
    }
    
    var color: Color {
        type.color
    }
    
    var description: String {
        type.description
    }
    
    var successRate: Double {
        // Calculate based on completion history
        // This will be implemented in each tracker type
        0.0
    }
    
    var currentStreak: Int {
        // Calculate current streak
        // This will be implemented in each tracker type
        0
    }
    
    var longestStreak: Int {
        // Track longest streak achieved
        // This will be implemented in each tracker type
        0
    }
    
    func displayValue() -> String {
        // Default implementation - override in tracker types
        isCompleted ? "Completed" : "Incomplete"
    }
    
    func detailDisplayValue() -> String {
        // Default implementation - override in tracker types
        isCompleted ? "Completed on " + (completionDate?.formatted() ?? "unknown") : "Not completed"
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func validate() throws {
        // Common validation for all tracker types
        if name.isEmpty {
            throw TrackerError.invalidName
        }
        
        if targetCount < 1 {
            throw TrackerError.invalidTargetCount
        }
        
        if let reminderTime = reminderTime, reminderTime > Date() {
            // Reminder time should be in the past for "time of day" reminders
            // This will be handled by the reminder system
        }
    }
}
```

## 2. Tracker Configuration

A configuration struct that allows for easy creation and updating of trackers.

```swift
// TrackerConfiguration.swift
import Foundation
import SwiftUI

/// Configuration for creating or updating a tracker
struct TrackerConfiguration: Codable {
    // Basic information
    var name: String
    var type: TrackerType
    
    // State (optional for updates)
    var isCompleted: Bool?
    
    // Reminder configuration
    var reminderTime: TimeOfDay?
    var reminderDays: [DayOfWeek]
    var reminderEnabled: Bool
    
    // Completion rules
    var completionFrequency: CompletionFrequency
    var targetCount: Int
    var autoCompleteDays: [DayOfWeek]
    
    // History
    var historyEnabled: Bool
    
    // Type-specific configuration
    var streakConfiguration: StreakConfiguration?
    var negativeStreakConfiguration: NegativeStreakConfiguration?
    var timeSinceConfiguration: TimeSinceConfiguration?
    var timeAheadConfiguration: TimeAheadConfiguration?
    var counterConfiguration: CounterConfiguration?
    
    // MARK: - Type-Specific Configurations
    
    struct StreakConfiguration: Codable {
        // Streak-specific settings
        var allowMultipleCompletionsPerDay: Bool
    }
    
    struct NegativeStreakConfiguration: Codable {
        // Negative streak-specific settings
        var resetOnIncomplete: Bool
    }
    
    struct TimeSinceConfiguration: Codable {
        // Time since-specific settings
        var referenceDate: Date
        var resetOnCompletion: Bool
    }
    
    struct TimeAheadConfiguration: Codable {
        // Time ahead-specific settings
        var targetDate: Date
        var timeUnit: TimeUnit
        var notifyWhenExpired: Bool
    }
    
    struct CounterConfiguration: Codable {
        // Counter-specific settings
        var initialValue: Int
        var threshold: Int
        var allowNegative: Bool
        var resetOnDateChange: Bool
    }
    
    // MARK: - Default Values
    
    init(type: TrackerType) {
        self.type = type
        self.name = type.displayName
        self.reminderTime = nil
        self.reminderDays = []
        self.reminderEnabled = false
        self.completionFrequency = .once
        self.targetCount = 1
        self.autoCompleteDays = []
        self.historyEnabled = true
        self.isCompleted = false
        
        // Set type-specific defaults
        switch type {
        case .streak:
            streakConfiguration = StreakConfiguration(allowMultipleCompletionsPerDay: false)
        case .negativeStreak:
            negativeStreakConfiguration = NegativeStreakConfiguration(resetOnIncomplete: true)
        case .timeSince:
            timeSinceConfiguration = TimeSinceConfiguration(
                referenceDate: Date(),
                resetOnCompletion: true
            )
        case .timeAhead:
            timeAheadConfiguration = TimeAheadConfiguration(
                targetDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                timeUnit: .days,
                notifyWhenExpired: true
            )
        case .counter:
            counterConfiguration = CounterConfiguration(
                initialValue: 0,
                threshold: 10,
                allowNegative: false,
                resetOnDateChange: true
            )
        }
    }
}

/// Represents a time of day (without date)
struct TimeOfDay: Codable, Equatable, Hashable {
    let hours: Int
    let minutes: Int
    
    var date: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hours
        components.minute = minutes
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }
    
    static func from(date: Date) -> TimeOfDay {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hours: components.hour ?? 0, minutes: components.minute ?? 0)
    }
}
```

## 3. Tracker Error Handling

```swift
// TrackerError.swift
import Foundation

enum TrackerError: Error, LocalizedError {
    case invalidName
    case invalidTargetCount
    case invalidReferenceDate
    case invalidTargetDate
    case invalidThreshold
    case cannotComplete
    case alreadyCompletedToday
    case streakWouldReset
    case noHistoryAvailable
    case dataCorruption
    case unknownTrackerType
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Tracker name cannot be empty"
        case .invalidTargetCount:
            return "Target count must be at least 1"
        case .invalidReferenceDate:
            return "Reference date must be in the past"
        case .invalidTargetDate:
            return "Target date must be in the future"
        case .invalidThreshold:
            return "Threshold must be greater than 0"
        case .cannotComplete:
            return "Cannot complete this tracker"
        case .alreadyCompletedToday:
            return "Already completed today"
        case .streakWouldReset:
            return "This action would reset your streak"
        case .noHistoryAvailable:
            return "No history available for this tracker"
        case .dataCorruption:
            return "Tracker data is corrupted"
        case .unknownTrackerType:
            return "Unknown tracker type"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Please provide a valid name"
        case .invalidTargetCount:
            return "Please enter a positive number"
        case .invalidReferenceDate:
            return "Please select a past date"
        case .invalidTargetDate:
            return "Please select a future date"
        case .invalidThreshold:
            return "Please enter a positive threshold"
        case .cannotComplete:
            return nil
        case .alreadyCompletedToday:
            return "You can only complete this once per day"
        case .streakWouldReset:
            return "Are you sure you want to continue?"
        case .noHistoryAvailable:
            return "Complete the tracker a few times to see history"
        case .dataCorruption:
            return "Try restarting the app"
        case .unknownTrackerType:
            return "Please update the app"
        }
    }
}
```

## 4. Tracker State Management

```swift
// TrackerState.swift
import Foundation

/// Represents the completion state of a tracker
struct TrackerState: Codable, Equatable {
    let isCompleted: Bool
    let completionCount: Int
    let lastCompletionDate: Date?
    let currentStreak: Int
    
    init(isCompleted: Bool = false, 
         completionCount: Int = 0, 
         lastCompletionDate: Date? = nil,
         currentStreak: Int = 0) {
        self.isCompleted = isCompleted
        self.completionCount = completionCount
        self.lastCompletionDate = lastCompletionDate
        self.currentStreak = currentStreak
    }
}

/// Manages state transitions for trackers
protocol TrackerStateManager {
    /// Updates state when tracker is completed
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState
    
    /// Updates state when tracker is reset
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState
    
    /// Updates state at start of new day
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState
}

/// Default state manager implementation
struct DefaultTrackerStateManager: TrackerStateManager {
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        let calendar = Calendar.current
        let isSameDay = calendar.isDate(date, inSameDayAs: tracker.completionDate ?? Date.distantPast)
        
        var newCount = tracker.lastCompletionCount
        var newStreak = tracker.currentStreak
        
        if !isSameDay {
            // New day, reset count
            newCount = 1
        } else {
            // Same day, increment count
            newCount += 1
        }
        
        // Check if we should increment streak
        // This is type-specific, will be overridden
        
        tracker.isCompleted = true
        tracker.completionDate = date
        tracker.lastCompletionCount = newCount
        
        return TrackerState(
            isCompleted: true,
            completionCount: newCount,
            lastCompletionDate: date,
            currentStreak: newStreak
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        tracker.isCompleted = false
        tracker.completionDate = nil
        tracker.lastCompletionCount = 0
        
        return TrackerState(
            isCompleted: false,
            completionCount: 0,
            lastCompletionDate: nil,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        let calendar = Calendar.current
        guard let lastDate = tracker.completionDate else {
            // No previous completion
            return TrackerState(
                isCompleted: tracker.shouldAutoComplete(today: newDate),
                completionCount: 0,
                lastCompletionDate: nil,
                currentStreak: 0
            )
        }
        
        let isConsecutive = calendar.isDate(newDate, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: lastDate) ?? Date.distantPast)
        
        var newStreak = 0
        if isConsecutive && tracker.isCompleted {
            newStreak = tracker.currentStreak + 1
        }
        
        // Reset completion count for new day
        let shouldComplete = tracker.shouldAutoComplete(today: newDate)
        
        tracker.isCompleted = shouldComplete
        if shouldComplete {
            tracker.completionDate = newDate
            tracker.lastCompletionCount = 1
        } else {
            tracker.completionDate = nil
            tracker.lastCompletionCount = 0
        }
        
        return TrackerState(
            isCompleted: shouldComplete,
            completionCount: shouldComplete ? 1 : 0,
            lastCompletionDate: shouldComplete ? newDate : nil,
            currentStreak: newStreak
        )
    }
}
```

## 5. Tracker Factory

```swift
// TrackerFactory.swift
import Foundation

/// Factory for creating tracker instances
protocol TrackerFactory {
    /// Creates a new tracker of the specified type
    func createTracker(type: TrackerType, configuration: TrackerConfiguration) -> any BaseTrackerProtocol
    
    /// Creates a tracker from Core Data entity
    func createTracker(from entity: TrackerEntity) -> any BaseTrackerProtocol
    
    /// Creates a tracker of a specific type
    func createStreakTracker(configuration: TrackerConfiguration) -> StreakTracker
    func createNegativeStreakTracker(configuration: TrackerConfiguration) -> NegativeStreakTracker
    func createTimeSinceTracker(configuration: TrackerConfiguration) -> TimeSinceTracker
    func createTimeAheadTracker(configuration: TrackerConfiguration) -> TimeAheadTracker
    func createCounterTracker(configuration: TrackerConfiguration) -> CounterTracker
}

/// Default implementation of TrackerFactory
struct DefaultTrackerFactory: TrackerFactory {
    func createTracker(type: TrackerType, configuration: TrackerConfiguration) -> any BaseTrackerProtocol {
        switch type {
        case .streak:
            return createStreakTracker(configuration: configuration)
        case .negativeStreak:
            return createNegativeStreakTracker(configuration: configuration)
        case .timeSince:
            return createTimeSinceTracker(configuration: configuration)
        case .timeAhead:
            return createTimeAheadTracker(configuration: configuration)
        case .counter:
            return createCounterTracker(configuration: configuration)
        }
    }
    
    func createTracker(from entity: TrackerEntity) -> any BaseTrackerProtocol {
        // This will be implemented after Core Data model is defined
        fatalError("Not implemented yet")
    }
    
    func createStreakTracker(configuration: TrackerConfiguration) -> StreakTracker {
        StreakTracker(configuration: configuration)
    }
    
    func createNegativeStreakTracker(configuration: TrackerConfiguration) -> NegativeStreakTracker {
        NegativeStreakTracker(configuration: configuration)
    }
    
    func createTimeSinceTracker(configuration: TrackerConfiguration) -> TimeSinceTracker {
        TimeSinceTracker(configuration: configuration)
    }
    
    func createTimeAheadTracker(configuration: TrackerConfiguration) -> TimeAheadTracker {
        TimeAheadTracker(configuration: configuration)
    }
    
    func createCounterTracker(configuration: TrackerConfiguration) -> CounterTracker {
        CounterTracker(configuration: configuration)
    }
}
```

## 6. Time Unit Enum

```swift
// TimeUnit.swift
import Foundation

enum TimeUnit: String, Codable, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours
    case days
    case weeks
    case months
    case years
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        case .years: return "Years"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .seconds: return "sec"
        case .minutes: return "min"
        case .hours: return "hr"
        case .days: return "day"
        case .weeks: return "wk"
        case .months: return "mo"
        case .years: return "yr"
        }
    }
    
    var seconds: Int {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours: return 3600
        case .days: return 86400
        case .weeks: return 604800
        case .months: return 2592000 // Approximate
        case .years: return 31536000 // Approximate
        }
    }
    
    static func appropriateUnit(forSeconds seconds: Int) -> TimeUnit {
        if seconds < 60 {
            return .seconds
        } else if seconds < 3600 {
            return .minutes
        } else if seconds < 86400 {
            return .hours
        } else if seconds < 604800 {
            return .days
        } else if seconds < 2592000 {
            return .weeks
        } else if seconds < 31536000 {
            return .months
        } else {
            return .years
        }
    }
}
```

## 7. Date Helper Extensions

```swift
// Date+TrackerExtensions.swift
import Foundation

extension Date {
    /// Returns true if the date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if the date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    /// Returns true if the date is in the future
    var isFuture: Bool {
        self > Date()
    }
    
    /// Returns the start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day
    var endOfDay: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the number of days since another date
    func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: self)
        return abs(components.day ?? 0)
    }
    
    /// Returns the time components between two dates
    func timeComponents(since date: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: date, to: self)
        return (
            days: abs(components.day ?? 0),
            hours: abs(components.hour ?? 0),
            minutes: abs(components.minute ?? 0),
            seconds: abs(components.second ?? 0)
        )
    }
    
    /// Returns a formatted string representing the time since the date
    func timeSinceString(using units: [TimeUnit] = [.years, .months, .weeks, .days, .hours, .minutes]) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute], from: self, to: Date())
        
        for unit in units {
            switch unit {
            case .years:
                if let years = components.year, years > 0 {
                    return "\(years) year" + (years == 1 ? "" : "s") + " ago"
                }
            case .months:
                if let months = components.month, months > 0 {
                    return "\(months) month" + (months == 1 ? "" : "s") + " ago"
                }
            case .weeks:
                if let weeks = components.weekOfYear, weeks > 0 {
                    return "\(weeks) week" + (weeks == 1 ? "" : "s") + " ago"
                }
            case .days:
                if let days = components.day, days > 0 {
                    return "\(days) day" + (days == 1 ? "" : "s") + " ago"
                }
            case .hours:
                if let hours = components.hour, hours > 0 {
                    return "\(hours) hour" + (hours == 1 ? "" : "s") + " ago"
                }
            case .minutes:
                if let minutes = components.minute, minutes > 0 {
                    return "\(minutes) minute" + (minutes == 1 ? "" : "s") + " ago"
                }
            case .seconds:
                if let seconds = components.second, seconds > 0 {
                    return "\(seconds) second" + (seconds == 1 ? "" : "s") + " ago"
                }
            }
        }
        
        return "Just now"
    }
    
    /// Returns a formatted string representing the time until the date
    func timeUntilString(using units: [TimeUnit] = [.years, .months, .weeks, .days, .hours, .minutes]) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute], from: Date(), to: self)
        
        for unit in units {
            switch unit {
            case .years:
                if let years = components.year, years > 0 {
                    return "In \(years) year" + (years == 1 ? "" : "s")
                }
            case .months:
                if let months = components.month, months > 0 {
                    return "In \(months) month" + (months == 1 ? "" : "s")
                }
            case .weeks:
                if let weeks = components.weekOfYear, weeks > 0 {
                    return "In \(weeks) week" + (weeks == 1 ? "" : "s")
                }
            case .days:
                if let days = components.day, days > 0 {
                    return "In \(days) day" + (days == 1 ? "" : "s")
                }
            case .hours:
                if let hours = components.hour, hours > 0 {
                    return "In \(hours) hour" + (hours == 1 ? "" : "s")
                }
            case .minutes:
                if let minutes = components.minute, minutes > 0 {
                    return "In \(minutes) minute" + (minutes == 1 ? "" : "s")
                }
            case .seconds:
                if let seconds = components.second, seconds > 0 {
                    return "In \(seconds) second" + (seconds == 1 ? "" : "s")
                }
            }
        }
        
        return "Now"
    }
}
```

## 8. Checklist

### Base Tracker Implementation
- [ ] `BaseTrackerProtocol` defined
- [ ] Default implementations for protocol methods
- [ ] `TrackerConfiguration` struct created
- [ ] `TimeOfDay` struct created
- [ ] `TrackerError` enum defined
- [ ] `TrackerState` struct created
- [ ] `TrackerStateManager` protocol defined
- [ ] `DefaultTrackerStateManager` implemented
- [ ] `TrackerFactory` protocol defined
- [ ] `DefaultTrackerFactory` implemented
- [ ] `TimeUnit` enum created
- [ ] `Date` extensions for tracker functionality

### Code Quality
- [ ] All code follows Swift API Design Guidelines
- [ ] Proper error handling implemented
- [ ] Documentation comments added
- [ ] Unit tests written
- [ ] Test coverage >= 90%

## 9. Success Criteria

- [ ] Base tracker protocol compiles without errors
- [ ] All default implementations work correctly
- [ ] Tracker configuration can be created for all types
- [ ] State management handles all transitions correctly
- [ ] Factory can create all tracker types
- [ ] Date extensions provide accurate calculations
- [ ] All unit tests pass

## 10. Next Steps

Proceed to implement specific tracker types:
- [02-streak-tracker.md](02-streak-tracker.md) - Streak Tracker
- [03-negative-streak-tracker.md](03-negative-streak-tracker.md) - Negative Streak Tracker
- [04-time-since-tracker.md](04-time-since-tracker.md) - Time Since Tracker
- [05-time-ahead-tracker.md](05-time-ahead-tracker.md) - Time Ahead Tracker
- [06-counter-tracker.md](06-counter-tracker.md) - Counter Tracker

---

**Phase**: 3 - Tracker Types  
**Section**: 3.1 - Base Tracker  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2  
**Last Updated**: [Date]  
**Version**: 1.0
