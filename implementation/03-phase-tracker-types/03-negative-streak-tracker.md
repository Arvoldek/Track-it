# Phase 3.3: Negative Streak Tracker Implementation

## Overview

Negative Streak Tracker tracks avoidance habits (things you want to NOT do). Unlike regular streaks that start incomplete, negative streaks start **completed** and the streak increases each day you successfully avoid the habit.

**Part of**: Phase 3 - Tracker Types
**Duration**: 1 day
**Priority**: Critical
**Tracker Type**: Avoidance habit tracking

## 1. Specification

### Behavior
- **Initial State**: Completed (assumes user is successfully avoiding the habit)
- **Maintenance**: Streak increases each day the tracker remains completed
- **Breaking**: User marks as incomplete when they fail to avoid the habit
- **Streak Reset**: Streak resets to 0 when marked incomplete
- **Multiple Completions**: If set to have multiple "completions" (avoidances) per day, streak breaks only when the last one is marked incomplete

### Use Cases
- Tracking habits to avoid (smoking, drinking, nail biting)
- Quitting addictions
- Breaking bad habits
- Encouraging avoidance through visual streak counting

### State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              NEGATIVE STREAK TRACKER STATE                     │
│                                                              │
│  ┌──────────┐    mark incomplete    ┌──────────┐              │
│  │          │ ────────────────────► │          │              │
│  │ Completed │                       │ Incomplete│              │
│  │          │                       │          │              │
│  └──────────┘ ◄────────────────────┘          │              │
│       ▲                                          │              │
│       │ new day (if still avoiding)             │              │
│       │                                          │              │
│       └──────────────────────────────────────────┘              │
│                                                              │
│  Streak Counter: Increments each day tracker remains         │
│  Completed. Resets to 0 when marked Incomplete.             │
└─────────────────────────────────────────────────────────────┘
```

## 2. Implementation

### Domain Model

```swift
// NegativeStreakTracker.swift
import Foundation
import SwiftUI

/// Tracks avoidance habits with daily streaks
struct NegativeStreakTracker: BaseTrackerProtocol {
    // MARK: - Identification
    let id: UUID
    let type: TrackerType = .negativeStreak
    
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
    /// Determines if marking incomplete resets the streak immediately
    var resetOnIncomplete: Bool
    
    // MARK: - Initialization
    
    init(configuration: TrackerConfiguration) {
        self.id = UUID()
        self.name = configuration.name
        // Negative streak starts as COMPLETED (user is avoiding the habit)
        self.isCompleted = true
        self.completionDate = Date()
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
        self.resetOnIncomplete = configuration.negativeStreakConfiguration?.resetOnIncomplete ?? true
    }
    
    // For loading from persistence
    init(id: UUID, name: String, isCompleted: Bool, completionDate: Date?, 
         lastCompletionCount: Int, reminderTime: Date?, reminderDays: [DayOfWeek],
         reminderEnabled: Bool, completionFrequency: CompletionFrequency, 
         targetCount: Int, autoCompleteDays: [DayOfWeek], historyEnabled: Bool,
         successRate: Double, currentStreak: Int, longestStreak: Int,
         createdAt: Date, updatedAt: Date, resetOnIncomplete: Bool) {
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
        self.resetOnIncomplete = resetOnIncomplete
    }
    
    // MARK: - Actions
    
    mutating func complete() {
        // For negative streak, "completing" means the user is avoiding the habit
        // But we don't increment streak here - streak increments automatically each day
        // This method is called when user confirms they're avoiding the habit
        
        if !isCompleted {
            // Was incomplete, now completed - this means user is avoiding again
            isCompleted = true
            completionDate = Date()
            updatedAt = Date()
            
            // Check if we should increment streak
            // Streak increments when transitioning from incomplete to completed
            // OR automatically each day if already completed
        }
        // If already completed, do nothing - user is already avoiding
    }
    
    mutating func markIncomplete() {
        // User failed to avoid the habit
        if isCompleted {
            if resetOnIncomplete {
                // Reset streak immediately
                currentStreak = 0
            }
            isCompleted = false
            completionDate = Date() // Record when the failure happened
            lastCompletionCount = 0
            updatedAt = Date()
        }
    }
    
    mutating func reset() {
        // Reset to initial state (avoiding the habit)
        isCompleted = true
        completionDate = Date()
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
        resetOnIncomplete = configuration.negativeStreakConfiguration?.resetOnIncomplete ?? resetOnIncomplete
        updatedAt = Date()
    }
    
    func displayValue() -> String {
        if isCompleted {
            return "Day \(currentStreak)"
        } else {
            return "Day 0 - Failed"
        }
    }
    
    func detailDisplayValue() -> String {
        if isCompleted {
            let dateString = completionDate?.formatted() ?? "Unknown"
            return "Streak: \(currentStreak) days | Avoiding since \(dateString)"
        } else {
            let dateString = completionDate?.formatted() ?? "Unknown"
            return "Streak broken! | Failed at \(dateString)"
        }
    }
    
    func shouldAutoComplete(today: Date) -> Bool {
        // For negative streak, we auto-complete on specified days
        // This means the user is assumed to be avoiding the habit
        guard !autoCompleteDays.isEmpty else { return false }
        let calendar = Calendar.current
        let dayOfWeek = DayOfWeek.from(date: today)
        return autoCompleteDays.contains(dayOfWeek)
    }
    
    func nextCompletionDate(after date: Date) -> Date? {
        // Next check is tomorrow
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

// MARK: - Protocol Conformance
extension NegativeStreakTracker: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: NegativeStreakTracker, rhs: NegativeStreakTracker) -> Bool {
        lhs.id == rhs.id
    }
}

extension NegativeStreakTracker: Codable {
    // Implementation similar to StreakTracker
    // ... (Codable implementation)
}
```

### State Manager

```swift
// NegativeStreakTrackerStateManager.swift
import Foundation

/// Manages state transitions specific to negative streak trackers
struct NegativeStreakTrackerStateManager: TrackerStateManager {
    
    func handleCompletion(for tracker: inout some BaseTrackerProtocol, on date: Date) -> TrackerState {
        guard var negativeTracker = tracker as? NegativeStreakTracker else {
            fatalError("Expected NegativeStreakTracker")
        }
        
        let calendar = Calendar.current
        
        // For negative streak, "completing" means confirming avoidance
        // Check if we're transitioning from incomplete to completed
        if !negativeTracker.isCompleted {
            // Was incomplete (failed), now completed (avoiding again)
            negativeTracker.isCompleted = true
            negativeTracker.completionDate = date
            
            // Reset streak to 1 (starting new streak)
            negativeTracker.currentStreak = 1
            negativeTracker.lastCompletionCount = 1
        } else {
            // Already completed - check if new day
            if let lastCompletion = negativeTracker.completionDate {
                if !calendar.isDate(date, inSameDayAs: lastCompletion) {
                    // New day while avoiding - increment streak
                    negativeTracker.currentStreak += 1
                    negativeTracker.completionDate = date
                    negativeTracker.lastCompletionCount = 1
                }
            } else {
                // First time completing
                negativeTracker.currentStreak = 1
                negativeTracker.completionDate = date
                negativeTracker.lastCompletionCount = 1
            }
        }
        
        negativeTracker.updatedAt = date
        
        // Update longest streak
        if negativeTracker.currentStreak > negativeTracker.longestStreak {
            negativeTracker.longestStreak = negativeTracker.currentStreak
        }
        
        tracker = negativeTracker
        
        return TrackerState(
            isCompleted: negativeTracker.isCompleted,
            completionCount: negativeTracker.lastCompletionCount,
            lastCompletionDate: negativeTracker.completionDate,
            currentStreak: negativeTracker.currentStreak
        )
    }
    
    func handleReset(for tracker: inout some BaseTrackerProtocol) -> TrackerState {
        guard var negativeTracker = tracker as? NegativeStreakTracker else {
            fatalError("Expected NegativeStreakTracker")
        }
        
        negativeTracker.isCompleted = true // Starts completed
        negativeTracker.completionDate = Date()
        negativeTracker.lastCompletionCount = 0
        negativeTracker.currentStreak = 0
        negativeTracker.updatedAt = Date()
        
        tracker = negativeTracker
        
        return TrackerState(
            isCompleted: true,
            completionCount: 0,
            lastCompletionDate: negativeTracker.completionDate,
            currentStreak: 0
        )
    }
    
    func handleNewDay(for tracker: inout some BaseTrackerProtocol, newDate: Date) -> TrackerState {
        guard var negativeTracker = tracker as? NegativeStreakTracker else {
            fatalError("Expected NegativeStreakTracker")
        }
        
        let calendar = Calendar.current
        
        if negativeTracker.isCompleted {
            // Was avoiding yesterday, check if we should continue
            if let lastCompletion = negativeTracker.completionDate {
                let daysSinceLast = calendar.dateComponents([.day], from: lastCompletion, to: newDate).day ?? 0
                
                if daysSinceLast == 1 {
                    // Consecutive day of avoiding - increment streak
                    negativeTracker.currentStreak += 1
                } else if daysSinceLast > 1 {
                    // Gap in days - check auto-complete
                    if negativeTracker.shouldAutoComplete(today: newDate) {
                        negativeTracker.currentStreak += 1
                    } else {
                        // Not auto-completing and gap exists - reset
                        negativeTracker.currentStreak = 0
                    }
                }
            } else {
                // First day - start streak
                negativeTracker.currentStreak = 1
            }
            
            negativeTracker.completionDate = newDate
        } else {
            // Was not avoiding - check if we should auto-complete
            if negativeTracker.shouldAutoComplete(today: newDate) {
                negativeTracker.isCompleted = true
                negativeTracker.currentStreak += 1
                negativeTracker.completionDate = newDate
            } else {
                // Still not avoiding - streak remains broken
                negativeTracker.currentStreak = 0
            }
        }
        
        negativeTracker.updatedAt = newDate
        tracker = negativeTracker
        
        // Update longest streak
        if negativeTracker.currentStreak > negativeTracker.longestStreak {
            negativeTracker.longestStreak = negativeTracker.currentStreak
        }
        
        return TrackerState(
            isCompleted: negativeTracker.isCompleted,
            completionCount: negativeTracker.lastCompletionCount,
            lastCompletionDate: negativeTracker.completionDate,
            currentStreak: negativeTracker.currentStreak
        )
    }
}
```

### Use Cases

```swift
// ConfirmAvoidanceUseCase.swift - Confirms user is avoiding the habit
struct ConfirmAvoidanceUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    private let stateManager: TrackerStateManager
    
    init(trackerRepository: TrackerRepositoryProtocol,
         stateManager: TrackerStateManager = NegativeStreakTrackerStateManager()) {
        self.trackerRepository = trackerRepository
        self.stateManager = stateManager
    }
    
    func execute(trackerId: UUID) async throws -> NegativeStreakTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? NegativeStreakTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // User confirms they're avoiding the habit
        let _ = stateManager.handleCompletion(for: &tracker, on: Date())
        
        try await trackerRepository.updateTracker(tracker)
        
        if tracker.historyEnabled {
            try await trackerRepository.recordCompletion(for: trackerId, on: Date())
        }
        
        return tracker
    }
}

// ReportFailureUseCase.swift - User failed to avoid the habit
struct ReportFailureUseCase {
    private let trackerRepository: TrackerRepositoryProtocol
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
    }
    
    func execute(trackerId: UUID) async throws -> NegativeStreakTracker {
        guard var tracker = try await trackerRepository.getTracker(by: trackerId) as? NegativeStreakTracker else {
            throw TrackerError.unknownTrackerType
        }
        
        // User failed - mark as incomplete
        tracker.markIncomplete()
        
        try await trackerRepository.updateTracker(tracker)
        
        if tracker.historyEnabled {
            try await trackerRepository.recordFailure(for: trackerId, on: Date())
        }
        
        return tracker
    }
}
```

## 3. Core Data Mapping

```swift
// CoreDataTrackerRepository+NegativeStreak.swift
extension CoreDataTrackerRepository {
    
    func saveNegativeStreakTracker(_ tracker: NegativeStreakTracker) throws {
        // Similar to saveStreakTracker but with negative streak properties
        // Store resetOnIncomplete in typeConfiguration
        // ...
    }
    
    func loadNegativeStreakTracker(from entity: TrackerEntity) -> NegativeStreakTracker? {
        guard entity.type == TrackerType.negativeStreak.rawValue else { return nil }
        
        // Parse entity and create NegativeStreakTracker
        // ...
    }
}
```

## 4. Tests

```swift
// NegativeStreakTrackerTests.swift
import XCTest

final class NegativeStreakTrackerTests: XCTestCase {
    
    var configuration: TrackerConfiguration!
    var tracker: NegativeStreakTracker!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        configuration = TrackerConfiguration(type: .negativeStreak)
        configuration.name = "Quit Smoking"
        tracker = NegativeStreakTracker(configuration: configuration)
    }
    
    func testInitialStateIsCompleted() {
        // Negative streak starts completed
        XCTAssertTrue(tracker.isCompleted)
        XCTAssertEqual(tracker.currentStreak, 0)
    }
    
    func testMarkIncompleteResetsStreak() {
        // Simulate a few days of avoiding
        tracker.currentStreak = 5
        
        // User fails
        tracker.markIncomplete()
        
        XCTAssertFalse(tracker.isCompleted)
        XCTAssertEqual(tracker.currentStreak, 0) // Reset by default
    }
    
    func testConfirmAvoidanceIncrementsStreak() {
        // Start avoiding
        tracker.complete()
        XCTAssertEqual(tracker.currentStreak, 1)
        
        // Next day
        tracker.completionDate = calendar.date(byAdding: .day, value: -1, to: Date())
        tracker.complete()
        XCTAssertEqual(tracker.currentStreak, 2)
    }
    
    func testDisplayValue() {
        XCTAssertEqual(tracker.displayValue(), "Day 0")
        
        tracker.currentStreak = 5
        XCTAssertEqual(tracker.displayValue(), "Day 5")
        
        tracker.markIncomplete()
        XCTAssertEqual(tracker.displayValue(), "Day 0 - Failed")
    }
}
```

## 5. Checklist

### Implementation
- [ ] `NegativeStreakTracker` struct implemented
- [ ] All `BaseTrackerProtocol` methods implemented
- [ ] `markIncomplete()` method implemented
- [ ] Streak logic correct (increments when avoiding, resets when failing)
- [ ] Auto-completion works on specified days

### Core Data Integration
- [ ] Mapping to/from Core Data entity
- [ ] Type-specific configuration stored

### Use Cases
- [ ] `ConfirmAvoidanceUseCase` implemented
- [ ] `ReportFailureUseCase` implemented

### Tests
- [ ] Unit tests for NegativeStreakTracker
- [ ] Unit tests for state manager
- [ ] Test coverage >= 95%

## 6. Success Criteria

- [ ] Negative streak tracker works as specified
- [ ] Streak increments when user avoids the habit
- [ ] Streak resets when user fails
- [ ] Initial state is completed
- [ ] All unit tests pass
- [ ] Code compiles without errors

---

**Phase**: 3 - Tracker Types  
**Section**: 3.3 - Negative Streak Tracker  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2, 3.1 (Base Tracker)  
**Last Updated**: [Date]  
**Version**: 1.0
