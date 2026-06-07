# Phase 3.6: Counter Tracker Implementation

## Overview

Counter Tracker is a simple increment/decrement counter that tracks values over time. It can have a threshold, and the day is marked incomplete if the counter exceeds the threshold.

**Part of**: Phase 3 - Tracker Types
**Duration**: 1 day
**Priority**: Critical
**Tracker Type**: Numerical counting

## 1. Specification

### Behavior
- **Initial State**: Depends on current value vs threshold
- **Counting**: User increments or decrements the counter value
- **Threshold**: Day is marked incomplete if counter exceeds threshold
- **History**: Counts are retained for each specific date
- **Reset**: Counter resets to initial value at start of new day (if configured)

### Use Cases
- Counting drinks during a night out
- Tracking daily water intake
- Counting steps, pushups, or any activity
- Tracking expenses
- Any simple numerical counting

### State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  COUNTER TRACKER STATE                          │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 Counter State                              │  │
│  │                                                              │  │
│  │  Current Value: N                                          │  │
│  │  Threshold: M                                              │  │
│  │                                                              │  │
│  │  If N <= M: isCompleted = true                             │  │
│  │  If N > M:  isCompleted = false                            │  │
│  │                                                              │  │
│  │  Actions:                                                  │  │
│  │    increment() -> N += 1                                   │  │
│  │    decrement() -> N -= 1 (if allowNegative)                 │  │
│  │    reset() -> N = initialValue                             │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
│  On new day:                                                 │
│    If resetOnDateChange: N = initialValue                    │
│    Otherwise: N continues from previous day                   │
│    isCompleted = (N <= M)                                     │
└─────────────────────────────────────────────────────────────┘
```

## 2. Implementation

### Domain Model

```swift
// CounterTracker.swift
import Foundation
import SwiftUI

/// Simple counter that tracks numerical values
struct CounterTracker: BaseTrackerProtocol {
    // MARK: - Identification
    let id: UUID
    let type: TrackerType = .counter
    
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
    /// Current counter value
    private(set) var currentValue: Int
    
    /// Initial value for the counter
    var initialValue: Int
    
    /// Threshold - if currentValue > threshold, day is incomplete
    var threshold: Int
    
    /// Whether to allow negative values
    var allowNegative: Bool
    
    /// Whether to reset to initialValue at start of new day
    var resetOnDateChange: Bool
    
    /// Tracks count per date for history
    var dailyCounts: [Date: Int]
    
    // MARK: - Initialization
    
    init(configuration: TrackerConfiguration) {
        self.id = UUID()
        self.name = configuration.name
        // Counter starts completed (assuming value <= threshold)
        self.isCompleted = true
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
        let counterConfig = configuration.counterConfiguration ?? 
            TrackerConfiguration.CounterConfiguration(
                initialValue: 0,
                threshold: 10,
                allowNegative: false,
                resetOnDateChange: true
            )
        
        self.initialValue = counterConfig.initialValue
        self.currentValue = counterConfig.initialValue
        self.threshold = counterConfig.threshold
        self.allowNegative = counterConfig.allowNegative
        self.resetOnDateChange = counterConfig.resetOnDateChange
        self.dailyCounts = [:]
        
        // Set initial completion state
        self.isCompleted = currentValue <= threshold
    }
    
    init(id: UUID, name: String, isCompleted: Bool, completionDate: Date?,
         lastCompletionCount: Int, reminderTime: Date?, reminderDays: [DayOfWeek],
         reminderEnabled: Bool, completionFrequency: CompletionFrequency,
         targetCount: Int, autoCompleteDays: [DayOfWeek], historyEnabled: Bool,
         successRate: Double, currentStreak: Int, longestStreak: Int,
         createdAt: Date, updatedAt: Date, currentValue: Int, initialValue: Int,
         threshold: Int, allowNegative: Bool, resetOnDateChange: Bool, dailyCounts: [Date: Int]) {
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
        self.currentValue = currentValue
        self.initialValue = initialValue
        self.threshold = threshold
        self.allowNegative = allowNegative
        self.resetOnDateChange = resetOnDateChange
        self.dailyCounts = dailyCounts
    }
    
    // MARK: - Actions
    
    mutating func increment() {
        currentValue += 1
        updateCompletionState()
        recordCurrentValue()
        updatedAt = Date()
    }
    
    mutating func decrement() {
        guard allowNegative || currentValue > 0 else { return }
        currentValue -= 1
        updateCompletionState()
        recordCurrentValue()
        updatedAt = Date()
    }
    
    mutating func complete() {
        // For counter, completing doesn't change the count
        // It just marks the day as complete
        isCompleted = true
        completionDate = Date()
        updatedAt = Date()
    }
    
    mutating func reset() {
        currentValue = initialValue
        updateCompletionState()
        completionDate = nil
        lastCompletionCount = 0
        dailyCounts.removeAll()
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
        
        if let counterConfig = configuration.counterConfiguration {
            initialValue = counterConfig.initialValue
            threshold = counterConfig.threshold
            allowNegative = counterConfig.allowNegative
            resetOnDateChange = counterConfig.resetOnDateChange
        }
        
        updateCompletionState()
        updatedAt = Date()
    }
    
    mutating func handleNewDay(_ date: Date) {
        if resetOnDateChange {
            // Save yesterday's count
            recordCurrentValue()
            
            // Reset to initial value
            currentValue = initialValue
        }
        
        // Update completion state for new day
        updateCompletionState()
        updatedAt = date
    }
    
    // MARK: - Private Methods
    
    private mutating func updateCompletionState() {
        isCompleted = currentValue <= threshold
        if isCompleted {
            completionDate = Date()
        } else {
            completionDate = nil
        }
    }
    
    private mutating func recordCurrentValue() {
        let today = Calendar.current.startOfDay(for: Date())
        dailyCounts[today] = currentValue
    }
    
    // MARK: - Display
    
    func displayValue() -> String {
        if currentValue <= threshold {
            return "\(currentValue) / \(threshold)"
        } else {
            return "\(currentValue) / \(threshold) - Over limit!"
        }
    }
    
    func detailDisplayValue() -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let todayCount = dailyCounts[today] ?? currentValue
        
        return "Today: \(todayCount) / \(threshold)"
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func nextCompletionDate(after date: Date) -> Date? {
        return nil // No specific next completion
    }
    
    func validate() throws {
        if name.isEmpty {
            throw TrackerError.invalidName
        }
        if threshold < 0 {
            throw TrackerError.invalidThreshold
        }
    }
}

// MARK: - Protocol Conformance
extension CounterTracker: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: CounterTracker, rhs: CounterTracker) -> Bool {
        lhs.id == rhs.id
    }
}

extension CounterTracker: Codable {
    // Codable implementation including dailyCounts
    // ...
}
```

### State Manager

```swift
// CounterTrackerStateManager.swift
import Foundation

/// Manages state transitions for counter trackers
struct CounterTrackerStateManager: TrackerStateManager {
    
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        guard var counterTracker = tracker as? CounterTracker else {
            fatalError("Expected CounterTracker")
        }
        
        // For counter, completing just marks as complete
        counterTracker.isCompleted = true
        counterTracker.completionDate = date
        counterTracker.lastCompletionCount += 1
        counterTracker.updatedAt = date
        
        tracker = counterTracker
        
        return TrackerState(
            isCompleted: true,
            completionCount: counterTracker.lastCompletionCount,
            lastCompletionDate: date,
            currentStreak: 0
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        guard var counterTracker = tracker as? CounterTracker else {
            fatalError("Expected CounterTracker")
        }
        
        counterTracker.reset()
        
        tracker = counterTracker
        
        return TrackerState(
            isCompleted: counterTracker.isCompleted,
            completionCount: 0,
            lastCompletionDate: nil,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        guard var counterTracker = tracker as? CounterTracker else {
            fatalError("Expected CounterTracker")
        }
        
        // Handle new day
        counterTracker.handleNewDay(newDate)
        
        // Check auto-complete
        if counterTracker.shouldAutoComplete(today: newDate) {
            counterTracker.isCompleted = true
            counterTracker.completionDate = newDate
        }
        
        tracker = counterTracker
        
        return TrackerState(
            isCompleted: counterTracker.isCompleted,
            completionCount: counterTracker.lastCompletionCount,
            lastCompletionDate: counterTracker.completionDate,
            currentStreak: 0
        )
    }
}
```

### Use Cases

```swift
// IncrementCounterUseCase.swift
struct IncrementCounterUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> CounterTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? CounterTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        tracker.increment()
        
        try await trackerRepository.updateTracker(tracker)
        
        if tracker.historyEnabled {
            try await trackerRepository.recordCounterValue(trackerId, value: tracker.currentValue, on: Date())
        }
        
        return tracker
    }
}

// DecrementCounterUseCase.swift
struct DecrementCounterUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> CounterTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? CounterTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        tracker.decrement()
        
        try await trackerRepository.updateTracker(tracker)
        
        if tracker.historyEnabled {
            try await trackerRepository.recordCounterValue(trackerId, value: tracker.currentValue, on: Date())
        }
        
        return tracker
    }
}

// GetCounterStatsUseCase.swift
struct GetCounterStatsUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> CounterStats {
        guard let tracker = try await trackerRepository.getTracker(by: trackerId) as? CounterTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        let history = try await trackerRepository.getHistory(for: trackerId)
        
        // Calculate stats from history
        let dailyValues = history.compactMap { entry -> (date: Date, value: Int)? in
            // Parse value from entry.userInfo or similar
            return (entry.date, 0) // Placeholder
        }
        
        let total = dailyValues.reduce(0) { $0 + $1.value }
        let average = dailyValues.isEmpty ? 0 : Double(total) / Double(dailyValues.count)
        let maxValue = dailyValues.max(by: { $0.value < $1.value })?.value ?? 0
        
        return CounterStats(
            currentValue: tracker.currentValue,
            threshold: tracker.threshold,
            totalCount: total,
            averageCount: average,
            maxCount: maxValue,
            daysTracked: dailyValues.count
        )
    }
}

struct CounterStats: Codable {
    let currentValue: Int
    let threshold: Int
    let totalCount: Int
    let averageCount: Double
    let maxCount: Int
    let daysTracked: Int
    
    var isOverThreshold: Bool {
        currentValue > threshold
    }
    
    var displayAverage: String {
        String(format: "%.1f", averageCount)
    }
}
```

## 3. Core Data Mapping

```swift
// CoreDataTrackerRepository+Counter.swift
extension CoreDataTrackerRepository {
    func saveCounterTracker(_ tracker: CounterTracker) throws {
        // Store currentValue, initialValue, threshold, allowNegative, resetOnDateChange
        // Store dailyCounts as JSON in a separate field or related entity
        // ...
    }
    
    func loadCounterTracker(from entity: TrackerEntity) -> CounterTracker? {
        guard entity.type == TrackerType.counter.rawValue else { return nil }
        // ...
    }
}
```

## 4. Tests

```swift
// CounterTrackerTests.swift
import XCTest

final class CounterTrackerTests: XCTestCase {
    var configuration: TrackerConfiguration!
    var tracker: CounterTracker!
    
    override func setUp() {
        super.setUp()
        configuration = TrackerConfiguration(type: .counter)
        configuration.name = "Drink Counter"
        configuration.counterConfiguration = TrackerConfiguration.CounterConfiguration(
            initialValue: 0,
            threshold: 10,
            allowNegative: false,
            resetOnDateChange: true
        )
        tracker = CounterTracker(configuration: configuration)
    }
    
    func testInitialState() {
        XCTAssertEqual(tracker.currentValue, 0)
        XCTAssertTrue(tracker.isCompleted)
    }
    
    func testIncrement() {
        tracker.increment()
        XCTAssertEqual(tracker.currentValue, 1)
        XCTAssertTrue(tracker.isCompleted) // Still under threshold
    }
    
    func testIncrementOverThreshold() {
        tracker.threshold = 2
        
        tracker.increment() // 1
        tracker.increment() // 2
        XCTAssertTrue(tracker.isCompleted) // At threshold
        
        tracker.increment() // 3
        XCTAssertFalse(tracker.isCompleted) // Over threshold
    }
    
    func testDecrement() {
        tracker.currentValue = 5
        tracker.decrement()
        XCTAssertEqual(tracker.currentValue, 4)
    }
    
    func testDecrementBelowZero() {
        tracker.allowNegative = false
        tracker.currentValue = 0
        tracker.decrement()
        XCTAssertEqual(tracker.currentValue, 0) // Can't go negative
    }
    
    func testReset() {
        tracker.currentValue = 5
        tracker.increment() // 6
        
        tracker.reset()
        
        XCTAssertEqual(tracker.currentValue, 0)
        XCTAssertTrue(tracker.isCompleted)
    }
    
    func testDisplayValue() {
        XCTAssertEqual(tracker.displayValue(), "0 / 10")
        
        tracker.increment()
        XCTAssertEqual(tracker.displayValue(), "1 / 10")
        
        tracker.threshold = 0
        tracker.currentValue = 1
        XCTAssertEqual(tracker.displayValue(), "1 / 0 - Over limit!")
    }
}
```

## 5. Checklist

- [ ] `CounterTracker` struct implemented
- [ ] All `BaseTrackerProtocol` methods implemented
- [ ] Increment/decrement logic correct
- [ ] Threshold checking works
- [ ] Daily reset logic works
- [ ] History tracking implemented
- [ ] Core Data mapping implemented
- [ ] Use cases implemented
- [ ] Unit tests written
- [ ] Test coverage >= 95%

---

**Phase**: 3 - Tracker Types  
**Section**: 3.6 - Counter Tracker  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2, 3.1 (Base Tracker)  
**Last Updated**: [Date]  
**Version**: 1.0
