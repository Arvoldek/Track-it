# Phase 3.5: Time Ahead Tracker Implementation

## Overview

Time Ahead Tracker counts down to a future target date. This is useful for tracking things like "days until vacation", "weeks until birthday", etc.

**Part of**: Phase 3 - Tracker Types
**Duration**: 0.5-1 day
**Priority**: Critical
**Tracker Type**: Countdown tracking

## 1. Specification

### Behavior
- **Initial State**: Incomplete (until target date is reached)
- **Time Calculation**: Continuously calculates time remaining until target date
- **Completion**: Automatically marks as completed when target date is reached
- **Display**: Shows time remaining in appropriate units (years, months, weeks, days, hours, minutes)
- **Target Date**: User-specified future date/time
- **Expiration**: Can trigger notifications or actions when target is reached

### Use Cases
- Countdown to events (birthdays, anniversaries, holidays)
- Countdown to deadlines
- Countdown to trips or vacations
- Countdown to any future event

## 2. Implementation

### Domain Model

```swift
// TimeAheadTracker.swift
import Foundation
import SwiftUI

/// Tracks time remaining until a target date
struct TimeAheadTracker: BaseTrackerProtocol {
    // MARK: - Identification
    let id: UUID
    let type: TrackerType = .timeAhead
    
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
    /// The target date we're counting down to
    var targetDate: Date
    
    /// Preferred time unit for display
    var timeUnit: TimeUnit
    
    /// Whether to notify when target is reached
    var notifyWhenExpired: Bool
    
    // MARK: - Initialization
    
    init(configuration: TrackerConfiguration) {
        self.id = UUID()
        self.name = configuration.name
        self.isCompleted = false // Starts incomplete
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
        self.targetDate = configuration.timeAheadConfiguration?.targetDate ?? 
            Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        self.timeUnit = configuration.timeAheadConfiguration?.timeUnit ?? .days
        self.notifyWhenExpired = configuration.timeAheadConfiguration?.notifyWhenExpired ?? true
    }
    
    init(id: UUID, name: String, isCompleted: Bool, completionDate: Date?,
         lastCompletionCount: Int, reminderTime: Date?, reminderDays: [DayOfWeek],
         reminderEnabled: Bool, completionFrequency: CompletionFrequency,
         targetCount: Int, autoCompleteDays: [DayOfWeek], historyEnabled: Bool,
         successRate: Double, currentStreak: Int, longestStreak: Int,
         createdAt: Date, updatedAt: Date, targetDate: Date, timeUnit: TimeUnit,
         notifyWhenExpired: Bool) {
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
        self.targetDate = targetDate
        self.timeUnit = timeUnit
        self.notifyWhenExpired = notifyWhenExpired
    }
    
    // MARK: - Actions
    
    mutating func complete() {
        // For TimeAhead, completing means manually marking as complete
        // This could be used if user wants to "check off" the countdown early
        if !isCompleted && Date() >= targetDate {
            isCompleted = true
            completionDate = Date()
            updatedAt = Date()
        }
    }
    
    mutating func reset() {
        // Reset the countdown with a new target date
        isCompleted = false
        completionDate = nil
        lastCompletionCount = 0
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
        
        if let timeAheadConfig = configuration.timeAheadConfiguration {
            targetDate = timeAheadConfig.targetDate
            timeUnit = timeAheadConfig.timeUnit
            notifyWhenExpired = timeAheadConfig.notifyWhenExpired
        }
        
        updatedAt = Date()
    }
    
    mutating func updateTargetDate(_ newDate: Date) {
        guard newDate > Date() else {
            return
        }
        targetDate = newDate
        updatedAt = Date()
    }
    
    func displayValue() -> String {
        let remaining = timeRemaining()
        
        if remaining <= 0 {
            return "Expired!"
        }
        
        let unit = timeUnit
        let value = Double(remaining) / Double(unit.seconds)
        
        return String(format: "%.1f \(unit.shortDisplayName)", value)
    }
    
    func detailDisplayValue() -> String {
        let remaining = timeRemaining()
        
        if remaining <= 0 {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Expired on \(targetDate.formatted())"
        }
        
        let components = timeComponentsRemaining()
        var parts: [String] = []
        
        if components.years > 0 {
            parts.append("\(components.years) \(components.years == 1 ? "year" : "years")")
        }
        if components.months > 0 {
            parts.append("\(components.months) \(components.months == 1 ? "month" : "months")")
        }
        if components.weeks > 0 && parts.count < 2 {
            parts.append("\(components.weeks) \(components.weeks == 1 ? "week" : "weeks")")
        }
        if components.days > 0 && parts.count < 2 {
            parts.append("\(components.days) \(components.days == 1 ? "day" : "days")")
        }
        if components.hours > 0 && parts.count < 2 {
            parts.append("\(components.hours) \(components.hours == 1 ? "hour" : "hours")")
        }
        if components.minutes > 0 && parts.count < 2 {
            parts.append("\(components.minutes) \(components.minutes == 1 ? "minute" : "minutes")")
        }
        
        let timeString = parts.isEmpty ? "0 seconds" : parts.joined(separator: ", ")
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = targetDate.formatted()
        
        return "\(timeString) until \(dateString)"
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        // Auto-complete if target date has been reached
        if today >= targetDate {
            return true
        }
        
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func nextCompletionDate(after date: Date) -> Date? {
        return targetDate
    }
    
    func validate() throws {
        if name.isEmpty {
            throw TrackerError.invalidName
        }
        if targetDate <= Date() {
            throw TrackerError.invalidTargetDate
        }
    }
    
    // MARK: - Private Helpers
    
    private func timeRemaining() -> Int {
        let components = Calendar.current.dateComponents([.second], from: Date(), to: targetDate)
        return components.second ?? 0
    }
    
    private func timeComponentsRemaining() -> (years: Int, months: Int, weeks: Int, days: Int, hours: Int, minutes: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute], from: Date(), to: targetDate)
        
        return (
            years: components.year ?? 0,
            months: components.month ?? 0,
            weeks: components.weekOfYear ?? 0,
            days: components.day ?? 0,
            hours: components.hour ?? 0,
            minutes: components.minute ?? 0
        )
    }
}

// MARK: - Protocol Conformance
extension TimeAheadTracker: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: TimeAheadTracker, rhs: TimeAheadTracker) -> Bool {
        lhs.id == rhs.id
    }
}

extension TimeAheadTracker: Codable {
    // Codable implementation
    // ...
}
```

### State Manager

```swift
// TimeAheadTrackerStateManager.swift
import Foundation

/// Manages state transitions for time ahead trackers
struct TimeAheadTrackerStateManager: TrackerStateManager {
    
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        guard var timeAheadTracker = tracker as? TimeAheadTracker else {
            fatalError("Expected TimeAheadTracker")
        }
        
        // Check if target date has been reached
        if date >= timeAheadTracker.targetDate {
            timeAheadTracker.isCompleted = true
            timeAheadTracker.completionDate = date
            timeAheadTracker.lastCompletionCount += 1
        } else {
            // Target not reached yet, but user manually completed
            timeAheadTracker.isCompleted = true
            timeAheadTracker.completionDate = date
            timeAheadTracker.lastCompletionCount += 1
        }
        
        timeAheadTracker.updatedAt = date
        tracker = timeAheadTracker
        
        return TrackerState(
            isCompleted: timeAheadTracker.isCompleted,
            completionCount: timeAheadTracker.lastCompletionCount,
            lastCompletionDate: timeAheadTracker.completionDate,
            currentStreak: 0
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        guard var timeAheadTracker = tracker as? TimeAheadTracker else {
            fatalError("Expected TimeAheadTracker")
        }
        
        timeAheadTracker.isCompleted = false
        timeAheadTracker.completionDate = nil
        timeAheadTracker.lastCompletionCount = 0
        timeAheadTracker.updatedAt = Date()
        
        tracker = timeAheadTracker
        
        return TrackerState(
            isCompleted: false,
            completionCount: 0,
            lastCompletionDate: nil,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        guard var timeAheadTracker = tracker as? TimeAheadTracker else {
            fatalError("Expected TimeAheadTracker")
        }
        
        // Check if target date has been reached
        if newDate >= timeAheadTracker.targetDate {
            timeAheadTracker.isCompleted = true
            timeAheadTracker.completionDate = newDate
            timeAheadTracker.lastCompletionCount += 1
        }
        
        timeAheadTracker.updatedAt = newDate
        tracker = timeAheadTracker
        
        return TrackerState(
            isCompleted: timeAheadTracker.isCompleted,
            completionCount: timeAheadTracker.lastCompletionCount,
            lastCompletionDate: timeAheadTracker.completionDate,
            currentStreak: 0
        )
    }
}
```

### Use Cases

```swift
// UpdateTargetDateUseCase.swift
struct UpdateTargetDateUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID, newDate: Date) async throws -> TimeAheadTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? TimeAheadTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        guard newDate > Date() else {
            throw TrackerError.invalidTargetDate
        }
        
        tracker.updateTargetDate(newDate)
        
        try await trackerRepository.updateTracker(tracker)
        
        return tracker
    }
}

// GetTimeAheadStatsUseCase.swift
struct GetTimeAheadStatsUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> TimeAheadStats {
        guard let tracker = try await trackerRepository.getTracker(by: trackerId) as? TimeAheadTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        let remaining = tracker.timeRemaining()
        
        return TimeAheadStats(
            timeRemaining: remaining,
            targetDate: tracker.targetDate,
            isExpired: remaining <= 0,
            preferredUnit: tracker.timeUnit
        )
    }
}

struct TimeAheadStats: Codable {
    let timeRemaining: Int // in seconds
    let targetDate: Date
    let isExpired: Bool
    let preferredUnit: TimeUnit
    
    var displayTime: String {
        if isExpired {
            return "Expired!"
        }
        let unit = preferredUnit
        let value = Double(timeRemaining) / Double(unit.seconds)
        return String(format: "%.1f \(unit.shortDisplayName)", value)
    }
}
```

## 3. Core Data Mapping

```swift
// CoreDataTrackerRepository+TimeAhead.swift
extension CoreDataTrackerRepository {
    func saveTimeAheadTracker(_ tracker: TimeAheadTracker) throws {
        // Store targetDate, timeUnit, notifyWhenExpired in typeConfiguration
        // ...
    }
    
    func loadTimeAheadTracker(from entity: TrackerEntity) -> TimeAheadTracker? {
        guard entity.type == TrackerType.timeAhead.rawValue else { return nil }
        // ...
    }
}
```

## 4. Tests

```swift
// TimeAheadTrackerTests.swift
import XCTest

final class TimeAheadTrackerTests: XCTestCase {
    var configuration: TrackerConfiguration!
    var tracker: TimeAheadTracker!
    
    override func setUp() {
        super.setUp()
        configuration = TrackerConfiguration(type: .timeAhead)
        configuration.name = "Vacation Countdown"
        configuration.timeAheadConfiguration = TrackerConfiguration.TimeAheadConfiguration(
            targetDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            timeUnit: .days,
            notifyWhenExpired: true
        )
        tracker = TimeAheadTracker(configuration: configuration)
    }
    
    func testInitialState() {
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertEqual(tracker.currentStreak, 0)
    }
    
    func testDisplayValue() {
        let display = tracker.displayValue()
        XCTAssertTrue(display.contains("day") || display.contains("wk"))
    }
    
    func testExpire() {
        // Set target date to past
        tracker.targetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        let display = tracker.displayValue()
        XCTAssertEqual(display, "Expired!")
    }
    
    func testUpdateTargetDate() {
        let newDate = Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date()
        tracker.updateTargetDate(newDate)
        
        XCTAssertEqual(tracker.targetDate, newDate)
    }
}
```

## 5. Checklist

- [ ] `TimeAheadTracker` struct implemented
- [ ] All `BaseTrackerProtocol` methods implemented
- [ ] Time calculation logic correct
- [ ] Auto-completion when target reached
- [ ] Display formatting correct
- [ ] Core Data mapping implemented
- [ ] Use cases implemented
- [ ] Unit tests written
- [ ] Test coverage >= 95%

---

**Phase**: 3 - Tracker Types  
**Section**: 3.5 - Time Ahead Tracker  
**Duration**: 0.5-1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2, 3.1 (Base Tracker)  
**Last Updated**: [Date]  
**Version**: 1.0
