# Phase 6.1: Unit Tests Implementation

## Overview

Comprehensive unit testing strategy for all layers of the application.

**Part of**: Phase 6 - Testing
**Duration**: 1 day
**Priority**: Critical

## 1. Testing Strategy

### Coverage Targets
- **Overall**: 80%+
- **Domain Layer**: 90%+
- **Data Layer**: 85%+
- **Presentation Layer**: 75%+

### Test Types
- Unit tests for business logic
- Integration tests for component interactions
- Mock-based tests for external dependencies

## 2. Test Structure

```
Tests/
├── UnitTests/
│   ├── DomainTests/
│   │   ├── ModelsTests/
│   │   ├── UseCasesTests/
│   │   └── EntitiesTests/
│   ├── DataTests/
│   │   ├── RepositoriesTests/
│   │   ├── CoreDataTests/
│   │   └── ServicesTests/
│   └── PresentationTests/
│       ├── ViewModelsTests/
│       └── ViewsTests/
└── TestUtilities/
    ├── Mocks/
    ├── TestData/
    └── Helpers/
```

## 3. Domain Layer Tests

### Model Tests

```swift
// TrackerConfigurationTests.swift
import XCTest

final class TrackerConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = TrackerConfiguration(type: .streak)
        
        XCTAssertEqual(config.name, "Streak")
        XCTAssertEqual(config.type, .streak)
        XCTAssertFalse(config.reminderEnabled)
        XCTAssertEqual(config.completionFrequency, .once)
        XCTAssertEqual(config.targetCount, 1)
    }
    
    func testStreakConfiguration() {
        let config = TrackerConfiguration(type: .streak)
        
        XCTAssertNotNil(config.streakConfiguration)
        XCTAssertFalse(config.streakConfiguration!.allowMultipleCompletionsPerDay)
    }
    
    func testTimeSinceConfiguration() {
        let config = TrackerConfiguration(type: .timeSince)
        
        XCTAssertNotNil(config.timeSinceConfiguration)
    }
}
```

### Use Case Tests

```swift
// CompleteStreakTrackerUseCaseTests.swift
import XCTest

final class CompleteStreakTrackerUseCaseTests: XCTestCase {
    private var useCase: CompleteStreakTrackerUseCase!
    private var mockRepository: MockTrackerRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockTrackerRepository()
        useCase = CompleteStreakTrackerUseCase(
            trackerRepository: mockRepository,
            stateManager: StreakTrackerStateManager()
        )
    }
    
    func testCompleteTrackerSuccess() async {
        // Arrange
        let trackerId = UUID()
        let tracker = StreakTracker(configuration: TrackerConfiguration(type: .streak))
        mockRepository.trackers[trackerId] = tracker
        
        // Act
        let result = try? await useCase.execute(trackerId: trackerId)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isCompleted)
        XCTAssertEqual(result!.currentStreak, 1)
        XCTAssertEqual(mockRepository.updateCallCount, 1)
    }
    
    func testCompleteTrackerNotFound() async {
        // Arrange
        let trackerId = UUID()
        
        // Act & Assert
        XCTAssertThrowsError(try await useCase.execute(trackerId: trackerId)) { error in
            XCTAssertEqual(error as? TrackerError, TrackerError.unknownTrackerType)
        }
    }
}

// Mock Repository
final class MockTrackerRepository: TrackerRepositoryProtocol {
    var trackers: [UUID: any BaseTrackerProtocol] = [:]
    var updateCallCount = 0
    
    func getTracker(by id: UUID) async throws -> any BaseTrackerProtocol {
        guard let tracker = trackers[id] else {
            throw TrackerError.unknownTrackerType
        }
        return tracker
    }
    
    func updateTracker(_ tracker: any BaseTrackerProtocol) async throws {
        trackers[tracker.id] = tracker
        updateCallCount += 1
    }
    
    // Implement other required methods...
}
```

## 4. Data Layer Tests

### Repository Tests

```swift
// CoreDataTrackerRepositoryTests.swift
import XCTest
import CoreData

final class CoreDataTrackerRepositoryTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var repository: CoreDataTrackerRepository!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory store for testing
        let container = NSPersistentContainer(name: "TrackIt")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        persistenceController = PersistenceController(container: container)
        repository = CoreDataTrackerRepository(persistenceController: persistenceController)
    }
    
    func testCreateTracker() async throws {
        // Arrange
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Test Tracker"
        let tracker = StreakTracker(configuration: configuration)
        
        // Act
        try await repository.createTracker(tracker)
        
        // Assert
        let fetched = try await repository.getTracker(by: tracker.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched.name, "Test Tracker")
    }
    
    func testDeleteTracker() async throws {
        // Arrange
        let configuration = TrackerConfiguration(type: .streak)
        let tracker = StreakTracker(configuration: configuration)
        try await repository.createTracker(tracker)
        
        // Act
        try await repository.deleteTracker(tracker.id)
        
        // Assert
        XCTAssertThrowsError(try await repository.getTracker(by: tracker.id))
    }
}
```

### Core Data Tests

```swift
// TrackerEntityTests.swift
import XCTest
import CoreData

final class TrackerEntityTests: XCTestCase {
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        let container = NSPersistentContainer(name: "TrackIt")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
        context = container.viewContext
    }
    
    func testCreateEntity() {
        let entity = TrackerEntity(context: context)
        entity.id = UUID()
        entity.name = "Test"
        entity.type = TrackerType.streak.rawValue
        entity.isCompleted = true
        
        XCTAssertNoThrow(try context.save())
    }
    
    func testFetchRequest() {
        // Create test entities
        for i in 0..<5 {
            let entity = TrackerEntity(context: context)
            entity.id = UUID()
            entity.name = "Tracker \(i)"
            entity.type = TrackerType.streak.rawValue
        }
        
        try! context.save()
        
        // Test fetch
        let request: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", TrackerType.streak.rawValue)
        
        let results = try! context.fetch(request)
        XCTAssertEqual(results.count, 5)
    }
}
```

## 5. Presentation Layer Tests

### ViewModel Tests

```swift
// HomeViewModelTests.swift
import XCTest
import Combine

final class HomeViewModelTests: XCTestCase {
    private var viewModel: HomeViewModel!
    private var mockRepository: MockTrackerRepository!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        mockRepository = MockTrackerRepository()
        viewModel = HomeViewModel(trackerRepository: mockRepository)
    }
    
    func testFetchTrackers() {
        // Arrange
        let streakTracker = StreakTracker(configuration: TrackerConfiguration(type: .streak))
        let counterTracker = CounterTracker(configuration: TrackerConfiguration(type: .counter))
        mockRepository.trackers = [streakTracker, counterTracker]
        
        // Act
        viewModel.fetchTrackers()
        
        // Assert
        XCTAssertEqual(viewModel.trackersByType[.streak]?.count, 1)
        XCTAssertEqual(viewModel.trackersByType[.counter]?.count, 1)
        XCTAssertTrue(viewModel.hasTrackers)
    }
    
    func testHasTrackersEmpty() {
        // Arrange
        mockRepository.trackers = []
        
        // Act
        viewModel.fetchTrackers()
        
        // Assert
        XCTAssertFalse(viewModel.hasTrackers)
    }
}
```

### View Tests (Snapshot Testing)

```swift
// TrackerCardTests.swift
import XCTest
import SnapshotTesting

final class TrackerCardTests: XCTestCase {
    func testTrackerCardSnapshot() {
        // Arrange
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Meditation"
        let tracker = StreakTracker(configuration: configuration)
        tracker.currentStreak = 5
        tracker.isCompleted = true
        
        // Act
        let view = TrackerCard(tracker: tracker)
            .frame(width: 300)
            .padding()
        
        // Assert
        assertSnapshot(matching: view, as: .image)
    }
    
    func testTrackerCardDarkMode() {
        // Arrange
        let configuration = TrackerConfiguration(type: .streak)
        configuration.name = "Meditation"
        let tracker = StreakTracker(configuration: configuration)
        
        // Act
        let view = TrackerCard(tracker: tracker)
            .frame(width: 300)
            .padding()
            .colorScheme(.dark)
        
        // Assert
        assertSnapshot(matching: view, as: .image)
    }
}
```

## 6. Test Utilities

### Mock Generators

```swift
// MockTrackerGenerator.swift
import Foundation

struct MockTrackerGenerator {
    static func createStreakTracker(
        name: String = "Test Streak",
        currentStreak: Int = 0,
        isCompleted: Bool = false
    ) -> StreakTracker {
        var configuration = TrackerConfiguration(type: .streak)
        configuration.name = name
        var tracker = StreakTracker(configuration: configuration)
        tracker.currentStreak = currentStreak
        tracker.isCompleted = isCompleted
        return tracker
    }
    
    static func createCounterTracker(
        name: String = "Test Counter",
        currentValue: Int = 0,
        threshold: Int = 10
    ) -> CounterTracker {
        var configuration = TrackerConfiguration(type: .counter)
        configuration.name = name
        var tracker = CounterTracker(configuration: configuration)
        tracker.currentValue = currentValue
        tracker.threshold = threshold
        return tracker
    }
    
    // Other tracker types...
}
```

### Test Data

```swift
// TestData.swift
import Foundation

struct TestData {
    static let sampleTrackerId = UUID()
    static let sampleTrackerName = "Sample Tracker"
    static let sampleTrackerDescription = "This is a sample tracker"
    
    static let sampleDate = Calendar.current.date(from: DateComponents(
        year: 2024,
        month: 1,
        day: 1
    ))!
    
    static let sampleHistory: [TrackerHistoryEntity] = {
        var history: [TrackerHistoryEntity] = []
        for i in 0..<30 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            history.append(TrackerHistoryEntity(
                date: date,
                isCompleted: i % 2 == 0 // Every other day completed
            ))
        }
        return history
    }()
}
```

## 7. CI Integration

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode_15.app/Contents/Developer
    
    - name: Run Tests
      run: xcodebuild test \
        -workspace Track\ it.xcworkspace \
        -scheme Track\ it \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -enableCodeCoverage YES
    
    - name: Upload Code Coverage
      uses: actions/upload-artifact@v3
      with:
        name: code-coverage
        path: /Users/arvoldek/Library/Developer/Xcode/DerivedData/*/Logs/Test/
```

## 8. Checklist

### Test Coverage
- [ ] Domain models: 90%+
- [ ] Use cases: 90%+
- [ ] Repositories: 85%+
- [ ] Services: 85%+
- [ ] ViewModels: 80%+
- [ ] Views: 75%+

### Test Types
- [ ] Unit tests for all business logic
- [ ] Integration tests for components
- [ ] Mock-based tests for dependencies
- [ ] Snapshot tests for UI components

### CI/CD
- [ ] Tests run on CI
- [ ] Code coverage reporting
- [ ] Test results visible
- [ ] Build status notifications

### Maintenance
- [ ] Tests updated with code changes
- [ ] Failing tests fixed immediately
- [ ] New features have tests
- [ ] Test refactoring with code refactoring

---

**Phase**: 6 - Testing  
**Section**: 6.1 - Unit Tests  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1-5  
**Last Updated**: [Date]  
**Version**: 1.0
