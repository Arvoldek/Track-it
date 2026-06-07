# Phase 3: Tracker Types - Comprehensive Implementation

## Overview

This phase focuses on implementing all five tracker types with their specific business logic, state management, and history tracking. Each tracker type has unique behaviors and calculation logic that must be carefully implemented to meet the application requirements.

**Duration**: 4-5 days
**Dependencies**: Phase 1 (Foundation) and Phase 2 (Core Infrastructure) must be complete
**Priority**: Critical - Core functionality of the application

## Architecture

### Tracker Type Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    TRACKER SYSTEM                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  TrackerType (Enum)                                       │  │
│  │  - streak                                                │  │
│  │  - negativeStreak                                        │  │
│  │  - timeSince                                             │  │
│  │  - timeAhead                                             │  │
│  │  - counter                                               │  │
│  └─────────────────────────────────────────────────────────┘  │
│                              │                                │
│              ┌───────────────┴───────────────┐                │
│              │                               │                │
│   ┌──────────▼──────────┐        ┌──────────▼──────────┐      │
│   │   BaseTrackerProtocol │        │  TrackerEntity       │      │
│   │   (Common Interface)  │        │  (Core Data)         │      │
│   └──────────┬──────────┘        └──────────┬──────────┘      │
│              │                               │                │
│   ┌──────────▼──────────┐    ┌──────────────▼──────────────┐  │
│   │   Tracker (Struct)    │    │   TrackerHistoryEntity        │  │
│   │   (Domain Model)      │    │   (Core Data)                 │  │
│   └──────────┬──────────┘    └──────────────┬──────────────┘  │
│              │                               │                │
│   ┌──────────▼──────────────────────────────────────────┐   │
│   │           TRACKER TYPE EXTENSIONS                        │   │
│   │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │   │
│   │  │ Streak       │ │ Negative     │ │ Time Since   │   │   │
│   │  │ Tracker      │ │ Streak       │ │ Tracker      │   │   │
│   │  └──────────────┘ └──────────────┘ └──────────────┘   │   │
│   │  ┌──────────────┐ ┌──────────────┐                   │   │
│   │  │ Time Ahead   │ │ Counter      │                   │   │
│   │  │ Tracker      │ │ Tracker      │                   │   │
│   │  └──────────────┘ └──────────────┘                   │   │
│   └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

1. **TrackerType Enum**: Defines the five tracker types
2. **BaseTrackerProtocol**: Common interface for all tracker types
3. **Tracker Extensions**: Type-specific implementations
4. **Completion Logic**: Handles state transitions
5. **History Tracking**: Records completion history
6. **State Management**: Tracks current state (complete/incomplete)

## Common Tracker Features

All tracker types share these common features, implemented through the `BaseTrackerProtocol`:

### State Management
- `isCompleted: Bool` - Current completion state
- `completionDate: Date?` - When the tracker was last completed
- `lastCompletionCount: Int` - Number of completions for current period

### Reminder Configuration
- `reminderTime: Date?` - Time of day for reminder
- `reminderDays: [DayOfWeek]` - Days of week for reminder
- `reminderEnabled: Bool` - Whether reminder is active

### Completion Rules
- `completionFrequency: CompletionFrequency` - How often to complete (once, times/day, times/week, times/month)
- `targetCount: Int` - Target number of completions per period
- `autoCompleteDays: [DayOfWeek]` - Days to auto-complete

### History & Analytics
- `historyEnabled: Bool` - Whether to track history
- `successRate: Double` - Calculated success rate (0.0 to 1.0)
- `currentStreak: Int` - Current streak count
- `longestStreak: Int` - Longest streak achieved

## Tracker Type-Specific Implementation

Each tracker type has unique behavior that requires custom implementation:

### 1. Streak Tracker
- **Initial State**: Incomplete
- **Completion**: User marks as complete to increment streak
- **Streak Logic**: Increments by 1 per day when all completions done
- **Reset**: Streak resets to 0 when incomplete

### 2. Negative Streak Tracker
- **Initial State**: Complete (assumes user is avoiding the habit)
- **Completion**: User leaves it complete to increment streak
- **Streak Logic**: Increments by 1 per day when user doesn't mark as incomplete
- **Reset**: Streak resets to 0 when marked incomplete

### 3. Time Since Tracker
- **Initial State**: Incomplete
- **Completion**: N/A (always counting)
- **Time Logic**: Calculates time elapsed since reference date
- **Reset**: Reference date updates when user "relapses"

### 4. Time Ahead Tracker
- **Initial State**: Incomplete (until target reached)
- **Completion**: Automatically completes when target date reached
- **Time Logic**: Calculates time remaining until target date
- **Target**: Specific future date/time

### 5. Counter Tracker
- **Initial State**: Depends on threshold
- **Completion**: User increments/decrements counter
- **Threshold Logic**: Marks day incomplete if counter exceeds threshold
- **History**: Tracks count per date

## Implementation Order

Recommended order for implementing tracker types:

1. **Base Tracker Protocol** - Common interface and functionality
2. **Streak Tracker** - Simplest tracker type
3. **Negative Streak Tracker** - Similar to Streak but inverted logic
4. **Time Since Tracker** - Time calculation logic
5. **Time Ahead Tracker** - Countdown logic
6. **Counter Tracker** - Most complex with threshold logic

## Success Criteria

### Functional Requirements
- [ ] All 5 tracker types implemented
- [ ] Each tracker type behaves according to specifications
- [ ] State transitions work correctly
- [ ] History is properly recorded for all types
- [ ] Completion logic respects frequency settings
- [ ] Reminders work for all tracker types
- [ ] Auto-completion works on specified days

### Code Quality
- [ ] Clean, well-documented code
- [ ] Follows Swift API Design Guidelines
- [ ] Proper error handling
- [ ] No code duplication between tracker types
- [ ] Comprehensive unit tests
- [ ] 100% test coverage for business logic

### Performance
- [ ] Time calculations are efficient
- [ ] State updates are O(1) operations
- [ ] History queries are optimized
- [ ] No memory leaks

## Files to Create

### Domain Models (Domain Layer)
- `TrackerType+Extensions.swift` - Type-specific behavior
- `StreakTracker.swift` - Streak tracking logic
- `NegativeStreakTracker.swift` - Negative streak tracking logic
- `TimeSinceTracker.swift` - Time since tracking logic
- `TimeAheadTracker.swift` - Time ahead tracking logic
- `CounterTracker.swift` - Counter tracking logic

### Use Cases (Domain Layer)
- `CompleteTrackerUseCase.swift`
- `ResetTrackerUseCase.swift`
- `UpdateTrackerUseCase.swift`
- `CalculateStreakUseCase.swift`
- `CalculateTimeUseCase.swift`
- `CalculateCounterUseCase.swift`

### Repository Extensions (Data Layer)
- `CoreDataTrackerRepository+Streak.swift`
- `CoreDataTrackerRepository+NegativeStreak.swift`
- `CoreDataTrackerRepository+TimeSince.swift`
- `CoreDataTrackerRepository+TimeAhead.swift`
- `CoreDataTrackerRepository+Counter.swift`

### Tests
- `StreakTrackerTests.swift`
- `NegativeStreakTrackerTests.swift`
- `TimeSinceTrackerTests.swift`
- `TimeAheadTrackerTests.swift`
- `CounterTrackerTests.swift`

## Next Steps

Proceed to implement tracker types in the following order:

1. **01-base-tracker.md** - Base protocol and common functionality
2. **02-streak-tracker.md** - Streak tracker implementation
3. **03-negative-streak-tracker.md** - Negative streak tracker implementation
4. **04-time-since-tracker.md** - Time since tracker implementation
5. **05-time-ahead-tracker.md** - Time ahead tracker implementation
6. **06-counter-tracker.md** - Counter tracker implementation

---

**Phase**: 3 - Tracker Types  
**Duration**: 4-5 days  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1, Phase 2  
**Last Updated**: [Date]  
**Version**: 1.0
