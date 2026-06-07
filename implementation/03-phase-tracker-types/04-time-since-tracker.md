# Phase 3.4: Time Since Tracker Implementation

## Overview

Time Since Tracker counts the time elapsed since a specific reference event. This is useful for tracking things like "time since last cigarette", "time since last workout", etc.

**Part of**: Phase 3 - Tracker Types
**Duration**: 1 day
**Priority**: Critical
**Tracker Type**: Elapsed time tracking

## 1. Specification

### Behavior
- **Initial State**: Incomplete (time is counting from reference date)
- **Time Calculation**: Continuously calculates time elapsed since reference date
- **Reset**: User resets the counter when they "relapse" (reference date updates to current time)
- **Display**: Shows elapsed time in appropriate units (years, months, weeks, days, hours, minutes, seconds)
- **Completion**: N/A - this tracker doesn't have a completion state in the traditional sense

### Use Cases
- Tracking time since quitting a habit
- Time since last medical appointment
- Time since last maintenance (car, home, etc.)
- Time since any significant event

### State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                 TIME SINCE TRACKER STATE                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Counting                                 │  │
│  │  ┌─────────────────────────────────────────────────────┐│  │
│  │  │  Display: "X time units since [event]"                 ││  │
│  │  │  Time increases continuously                           ││  │
│  │  └─────────────────────────────────────────────────────┘│  │
│  │                              │                              │  │
│  │              ┌───────────────▼───────────────┐            │  │
│  │              │      reset()                │            │  │
│  │              ▼                              │            │  │
│  │  ┌─────────────────────────────────────────────────────┐│  │
│  │  │  Reference date updated to now                       ││  │
│  │  │  Time display resets to "0 seconds"                   ││  │
│  │  └─────────────────────────────────────────────────────┘│  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
│  Note: This tracker is always "counting" - there's no       │
│  complete/incomplete state. The display just shows elapsed   │
│  time from the reference date.                              │
└─────────────────────────────────────────────────────────────┘
```

## 2. Implementation

### Domain Model

```swift
// TimeSinceTracker.swift
import Foundation
import SwiftUI

/// Tracks time elapsed since a reference event
struct TimeSinceTracker: BaseTrackerProtocol {
    // MARK: - Identification
    let id: UUID
    let type: TrackerType = .timeSince
    
    // MARK: - Basic Information
    var name: String
    var iconName: String { type.iconName }
    var color: Color { type.color }
    var description: String { type.description }
    
    // MARK: - State Management
    // For TimeSince, isCompleted doesn't apply in the same way
    // We'll use it to indicate if the timer is "active" (counting)
    var isCompleted: Bool
    var completionDate: Date?
    var lastCompletionCount: Int
    
    // MARK: - Reminder Configuration
    var reminderTime: Date?
    var reminderDays: [DayOfWeek]
    var reminderEnabled: Bool
    
    // MARK: - Completion Rules
    // These don't really apply to TimeSince, but we keep them for protocol conformance
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
    /// The reference date from which time is counted
    var referenceDate: Date
    
    /// Whether to reset the reference date when the tracker is "completed"
    var resetOnCompletion: Bool
    
    // MARK: - Initialization
    
    init(configuration: TrackerConfiguration) {
        self.id = UUID()
        self.name = configuration.name
        // TimeSince starts as "completed" meaning it's actively counting
        self.isCompleted = true
        self.completionDate = nil
        self.lastCompletionCount = 0
        self.reminderTime = configuration.reminderTime?.date
        self.reminderDays = configuration.reminderDays
        self.reminderEnabled = configuration.reminderEnabled
        // These don't really apply but we need defaults
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
        self.referenceDate = configuration.timeSinceConfiguration?.referenceDate ?? Date()
        self.resetOnCompletion = configuration.timeSinceConfiguration?.resetOnCompletion ?? true
    }
    
    init(id: UUID, name: String, isCompleted: Bool, completionDate: Date?,
         lastCompletionCount: Int, reminderTime: Date?, reminderDays: [DayOfWeek],
         reminderEnabled: Bool, completionFrequency: CompletionFrequency,
         targetCount: Int, autoCompleteDays: [DayOfWeek], historyEnabled: Bool,
         successRate: Double, currentStreak: Int, longestStreak: Int,
         createdAt: Date, updatedAt: Date, referenceDate: Date, resetOnCompletion: Bool) {
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
        self.referenceDate = referenceDate
        self.resetOnCompletion = resetOnCompletion
    }
    
    // MARK: - Actions
    
    mutating func complete() {
        // For TimeSince, "completing" means resetting the timer
        // This is like "relapsing" - we start counting from now
        referenceDate = Date()
        updatedAt = Date()
        
        if resetOnCompletion {
            // Record this as a "relapse" in history
            lastCompletionCount += 1
        }
    }
    
    mutating func reset() {
        // Reset to initial state - start counting from now
        referenceDate = Date()
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
        
        if let timeSinceConfig = configuration.timeSinceConfiguration {
            referenceDate = timeSinceConfig.referenceDate
            resetOnCompletion = timeSinceConfig.resetOnCompletion
        }
        
        updatedAt = Date()
    }
    
    func displayValue() -> String {
        let elapsed = Date().timeSince(referenceDate)
        let unit = TimeUnit.appropriateUnit(forSeconds: elapsed)
        let value = elapsed / unit.seconds
        
        return "\(value) \(unit.shortDisplayName)"
    }
    
    func detailDisplayValue() -> String {
        let elapsed = Date().timeSince(referenceDate)
        let components = Date().timeComponents(since: referenceDate)
        
        var parts: [String] = []
        
        if components.years > 0 {
            parts.append("\(components.years) \(components.years == 1 ? "year" : "years")")
        }
        if components.months > 0 {
            parts.append("\(components.months) \(components.months == 1 ? "month" : "months")")
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
        formatter.timeStyle = .short
        let dateString = referenceDate.formatted()
        
        return "\(timeString) since \(dateString)"
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func nextCompletionDate(after date: Date) -> Date? {
        // For TimeSince, there's no next completion
        // But we could return when the next time unit boundary occurs
        return nil
    }
    
    func validate() throws {
        if name.isEmpty {
            throw TrackerError.invalidName
        }
        if referenceDate > Date() {
            throw TrackerError.invalidReferenceDate
        }
    }
}

// MARK: - Time Calculation Extension
extension Date {
    func timeSince(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.second], from: date, to: self)
        return abs(components.second ?? 0)
    }
}

// MARK: - Protocol Conformance
extension TimeSinceTracker: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: TimeSinceTracker, rhs: TimeSinceTracker) -> Bool {
        lhs.id == rhs.id
    }
}

extension TimeSinceTracker: Codable {
    // Codable implementation
    // ...
}
```

### State Manager

```swift
// TimeSinceTrackerStateManager.swift
import Foundation

/// Manages state transitions for time since trackers
struct TimeSinceTrackerStateManager: TrackerStateManager {
    
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        guard var timeSinceTracker = tracker as? TimeSinceTracker else {
            fatalError("Expected TimeSinceTracker")
        }
        
        // For TimeSince, "completing" means resetting the timer
        timeSinceTracker.referenceDate = date
        timeSinceTracker.lastCompletionCount += 1
        timeSinceTracker.updatedAt = date
        
        tracker = timeSinceTracker
        
        return TrackerState(
            isCompleted: true,
            completionCount: timeSinceTracker.lastCompletionCount,
            lastCompletionDate: date,
            currentStreak: 0 // Not applicable for TimeSince
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        guard var timeSinceTracker = tracker as? TimeSinceTracker else {
            fatalError("Expected TimeSinceTracker")
        }
        
        timeSinceTracker.referenceDate = Date()
        timeSinceTracker.lastCompletionCount = 0
        timeSinceTracker.updatedAt = Date()
        
        tracker = timeSinceTracker
        
        return TrackerState(
            isCompleted: true,
            completionCount: 0,
            lastCompletionDate: nil,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        guard var timeSinceTracker = tracker as? TimeSinceTracker else {
            fatalError("Expected TimeSinceTracker")
        }
        
        // For TimeSince, new day doesn't really affect state
        // Just update the date if auto-complete is enabled
        if timeSinceTracker.shouldAutoComplete(today: newDate) {
            // Auto-complete doesn't really apply, but we could record it
            timeSinceTracker.lastCompletionCount += 1
        }
        
        timeSinceTracker.updatedAt = newDate
        tracker = timeSinceTracker
        
        return TrackerState(
            isCompleted: true,
            completionCount: timeSinceTracker.lastCompletionCount,
            lastCompletionDate: timeSinceTracker.completionDate,
            currentStreak: 0
        )
    }
}
```

### Use Cases

```swift
// ResetTimeSinceTrackerUseCase.swift - Resets the timer (relapse)
struct ResetTimeSinceTrackerUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    private let stateManager: TrackerStateManager
    
    init(trackerRepository: TrackerRepositoryProtocol,
         stateManager: TrackerStateManager = TimeSinceTrackerStateManager()) {
        self.trackerRepository = trackerRepository
        self.stateManager = stateManager
    }
    
    func execute(trackerId: UUID) async throws -> TimeSinceTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? TimeSinceTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // Reset the timer
        let _ = stateManager.handleCompletion(for: &tracker, on: Date())
        
        try await trackerRepository.updateTracker(tracker)
        
        if tracker.historyEnabled {
            // Record the reset (relapse) in history
            try await trackerRepository.recordRelapse(for: trackerId, on: Date())
        }
        
        return tracker
    }
}

// GetTimeSinceStatsUseCase.swift
struct GetTimeSinceStatsUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> TimeSinceStats {
        guard let tracker = try await trackerRepository.getTracker(by: trackerId) as? TimeSinceTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        let history = try await trackerRepository.getHistory(for: trackerId)
        
        return TimeSinceStats(
            elapsedTime: Date().timeSince(tracker.referenceDate),
            referenceDate: tracker.referenceDate,
            relapseCount: tracker.lastCompletionCount,
            lastRelapse: tracker.completionDate
        )
    }
}

struct TimeSinceStats: Codable {
    let elapsedTime: Int // in seconds
    let referenceDate: Date
    let relapseCount: Int
    let lastRelapse: Date?
    
    var displayTime: String {
        let unit = TimeUnit.appropriateUnit(forSeconds: elapsedTime)
        let value = Double(elapsedTime) / Double(unit.seconds)
        return String(format: "%.1f \(unit.shortDisplayName)", value)
    }
}
```

### Core Data Mapping

```swift
// CoreDataTrackerRepository+TimeSince.swift
extension CoreDataTrackerRepository {
    
    func saveTimeSinceTracker(_ tracker: TimeSinceTracker) throws {
        // Similar pattern to other tracker types
        // Store referenceDate and resetOnCompletion in typeConfiguration
        // ...
    }
    
    func loadTimeSinceTracker(from entity: TrackerEntity) -> TimeSinceTracker? {
        guard entity.type == TrackerType.timeSince.rawValue else { return nil }
        
        // Parse entity and create TimeSinceTracker
        // ...
    }
}
```

## 3. Tests

```swift
// TimeSinceTrackerTests.swift
import XCTest

final class TimeSinceTrackerTests: XCTestCase {
    
    var configuration: TrackerConfiguration!
    var tracker: TimeSinceTracker!
    
    override func setUp() {
        super.setUp()
        configuration = TrackerConfiguration(type: .timeSince)
        configuration.name = "Time since quit smoking"
        configuration.timeSinceConfiguration = TrackerConfiguration.TimeSinceConfiguration(
            referenceDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            resetOnCompletion: true
        )
        tracker = TimeSinceTracker(configuration: configuration)
    }
    
    func testInitialState() {
        XCTAssertTrue(tracker.isCompleted)
        XCTAssertEqual(tracker.currentStreak, 0)
    }
    
    func testDisplayValue() {
        // Should show elapsed time
        let display = tracker.displayValue()
        XCTAssertTrue(display.contains("day") || display.contains("hr") || display.contains("min"))
    }
    
    func testReset() {
        let originalRefDate = tracker.referenceDate
        
        tracker.complete()
        
        XCTAssertNotEqual(tracker.referenceDate, originalRefDate)
        XCTAssert(tracker.referenceDate <= Date())
    }
    
    func testValidationInvalidReferenceDate() {
        tracker.referenceDate = Date().addingTimeInterval(1000) // Future date
        
        XCTAssertThrowsError(try tracker.validate()) { error in
            XCTAssertEqual(error as? TrackerError, TrackerError.invalidReferenceDate)
        }
    }
}
```

## 4. Checklist

### Implementation
- [ ] `TimeSinceTracker` struct implemented
- [ ] All `BaseTrackerProtocol` methods implemented
- [ ] Time calculation logic correct
- [ ] Reset functionality works
- [ ] Display formatting correct

### Core Data Integration
- [ ] Mapping to/from Core Data entity
- [ ] Type-specific properties stored

### Use Cases
- [ ] `ResetTimeSinceTrackerUseCase` implemented
- [ ] `GetTimeSinceStatsUseCase` implemented

### Tests
- [ ] Unit tests for TimeSinceTracker
- [ ] Unit tests for state manager
- [ ] Test coverage >= 95%

## 5. Success Criteria

- [ ] Time since tracker works as specified
- [ ] Time calculation is accurate
- [ ] Reset updates reference date
- [ ] Display shows appropriate time units
- [ ] All unit tests pass
- [ ] Code compiles without errors

---

**Phase**: 3 - Tracker Types  
**Section**: 3.4 - Time Since Tracker  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2, 3.1 (Base Tracker)  
**Last Updated**: [Date]  
**Version**: 1.0
