# Phase 6.2: UI Tests Implementation

## Overview

Comprehensive UI testing strategy for the Track It application using XCUITest.

**Part of**: Phase 6 - Testing
**Duration**: 1 day
**Priority**: Critical

## 1. Testing Strategy

### Coverage Targets
- All critical user flows: 100%
- All screens: Tested
- All interactive elements: Tested

### Test Types
- UI tests for user journeys
- Accessibility tests
- Localization tests
- Performance tests

## 2. Test Structure

```
Track itUITests/
├── Flows/
│   ├── OnboardingFlowTests.swift
│   ├── TrackerCreationFlowTests.swift
│   ├── TrackerCompletionFlowTests.swift
│   ├── CalendarFlowTests.swift
│   └── SettingsFlowTests.swift
├── Screens/
│   ├── HomeScreenTests.swift
│   ├── TrackerDetailScreenTests.swift
│   ├── CalendarScreenTests.swift
│   ├── GraphsScreenTests.swift
│   └── SettingsScreenTests.swift
├── Components/
│   ├── TrackerCardTests.swift
│   ├── ButtonTests.swift
│   └── FormTests.swift
└── Utilities/
    ├── TestHelpers.swift
    ├── MockData.swift
    └── Extensions.swift
```

## 3. User Flow Tests

### Onboarding Flow

```swift
// OnboardingFlowTests.swift
import XCTest

final class OnboardingFlowTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testFirstLaunchShowsEmptyState() {
        // When: App launches for first time
        // Then: EmptyStateView is shown
        XCTAssertTrue(app.otherElements["EmptyStateView"].exists)
        XCTAssertTrue(app.staticTexts["Create Your First Tracker"].exists)
    }
    
    func testCreateFirstTrackerFlow() {
        // When: User taps Create Tracker button
        app.buttons["Create Tracker"].tap()
        
        // Then: TrackerTypeSelectionView is shown
        XCTAssertTrue(app.otherElements["TrackerTypeSelectionView"].exists)
        
        // When: User selects Streak
        app.cells["Streak"].tap()
        
        // Then: TrackerCreationView is shown
        XCTAssertTrue(app.otherElements["TrackerCreationView"].exists)
        
        // When: User enters name and taps Create
        app.textFields["Tracker name"].tap()
        app.typeText("Meditation")
        app.buttons["Create"].tap()
        
        // Then: Tracker is created and shown in list
        XCTAssertTrue(app.cells["Meditation"].exists)
    }
}
```

### Tracker Creation Flow

```swift
// TrackerCreationFlowTests.swift
import XCTest

final class TrackerCreationFlowTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Create first tracker to get past onboarding
        createTestTracker()
    }
    
    func testCreateStreakTracker() {
        // When: User taps add button
        app.buttons["add Tracker"].tap()
        
        // And: Selects Streak type
        app.cells["Streak"].tap()
        
        // And: Enters name
        app.textFields["Tracker name"].tap()
        app.typeText("Exercise")
        
        // And: Toggles multiple completions
        app.switches["Allow multiple completions per day"].tap()
        
        // And: Sets reminder
        app.switches["Enable reminder"].tap()
        // Set time...
        
        // And: Taps Create
        app.buttons["Create"].tap()
        
        // Then: Tracker appears in list
        XCTAssertTrue(app.cells["Exercise"].exists)
    }
    
    func testCreateCounterTrackerWithThreshold() {
        // When: User creates counter tracker
        app.buttons["add Tracker"].tap()
        app.cells["Counter"].tap()
        
        // And: Sets name and threshold
        app.textFields["Tracker name"].tap()
        app.typeText("Drinks")
        
        // Set threshold to 5
        app.steppers.firstMatch.tap()
        app.steppers.firstMatch.tap()
        app.steppers.firstMatch.tap()
        app.steppers.firstMatch.tap()
        app.steppers.firstMatch.tap()
        
        // And: Taps Create
        app.buttons["Create"].tap()
        
        // Then: Counter appears in list
        XCTAssertTrue(app.cells["Drinks"].exists)
    }
    
    private func createTestTracker() {
        app.buttons["Create Tracker"].tap()
        app.cells["Streak"].tap()
        app.buttons["Create"].tap()
    }
}
```

### Tracker Completion Flow

```swift
// TrackerCompletionFlowTests.swift
import XCTest

final class TrackerCompletionFlowTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Create test tracker
        createTestStreakTracker()
    }
    
    func testCompleteStreakTracker() {
        // When: User taps on streak tracker
        app.cells["Meditation"].tap()
        
        // Then: Tracker detail view is shown
        XCTAssertTrue(app.otherElements["TrackerDetailView"].exists)
        
        // When: User taps Complete button
        app.buttons["Mark as Complete"].tap()
        
        // Then: Tracker shows as completed
        XCTAssertTrue(app.staticTexts["Completed"].exists)
        XCTAssertTrue(app.staticTexts["Day 1"].exists)
    }
    
    func testIncrementCounter() {
        // Given: Counter tracker exists
        createTestCounterTracker()
        app.cells["Drinks"].tap()
        
        // When: User taps increment button
        let initialValue = app.staticTexts["0"].value ?? ""
        app.buttons["plus.circle.fill"].tap()
        
        // Then: Counter increments
        let newValue = app.staticTexts["1"].value ?? ""
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    private func createTestStreakTracker() {
        app.buttons["Create Tracker"].tap()
        app.cells["Streak"].tap()
        app.textFields["Tracker name"].tap()
        app.typeText("Meditation")
        app.buttons["Create"].tap()
    }
    
    private func createTestCounterTracker() {
        app.buttons["add Tracker"].tap()
        app.cells["Counter"].tap()
        app.textFields["Tracker name"].tap()
        app.typeText("Drinks")
        app.buttons["Create"].tap()
    }
}
```

### Calendar Flow

```swift
// CalendarFlowTests.swift
import XCTest

final class CalendarFlowTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Create and complete test tracker
        createAndCompleteTestTracker()
    }
    
    func testViewCalendar() {
        // When: User taps on tracker and then History button
        app.cells["Meditation"].tap()
        app.buttons["View History"].tap()
        
        // Then: Calendar view is shown
        XCTAssertTrue(app.otherElements["CalendarView"].exists)
        
        // And: Today's date is selected
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        XCTAssertTrue(app.otherElements.containing(.staticText, identifier: today).element.exists)
    }
    
    func testNavigateCalendar() {
        // Given: Calendar view is open
        app.cells["Meditation"].tap()
        app.buttons["View History"].tap()
        
        // When: User navigates to previous month
        app.buttons["chevron.left"].tap()
        
        // Then: Previous month is shown
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let monthName = DateFormatter.localizedString(from: previousMonth, dateStyle: .medium, timeStyle: .none)
        XCTAssertTrue(app.staticTexts[monthName].exists)
    }
    
    private func createAndCompleteTestTracker() {
        app.buttons["Create Tracker"].tap()
        app.cells["Streak"].tap()
        app.textFields["Tracker name"].tap()
        app.typeText("Meditation")
        app.buttons["Create"].tap()
        app.cells["Meditation"].tap()
        app.buttons["Mark as Complete"].tap()
        app.buttons["Close"].tap()
    }
}
```

### Settings Flow

```swift
// SettingsFlowTests.swift
import XCTest

final class SettingsFlowTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testNavigateToSettings() {
        // When: User taps Settings tab
        app.tabBars.buttons["Settings"].tap()
        
        // Then: Settings view is shown
        XCTAssertTrue(app.otherElements["SettingsView"].exists)
    }
    
    func testToggleICloudSync() {
        // Given: Settings view is open
        app.tabBars.buttons["Settings"].tap()
        
        // When: User toggles iCloud sync
        let switchInitialValue = app.switches["Sync with iCloud"].value as? String
        app.switches["Sync with iCloud"].tap()
        
        // Then: Switch value changes
        let switchNewValue = app.switches["Sync with iCloud"].value as? String
        XCTAssertNotEqual(switchInitialValue, switchNewValue)
    }
    
    func testWeekStartSelection() {
        // Given: Settings view is open
        app.tabBars.buttons["Settings"].tap()
        
        // When: User changes week start day
        app.cells["Week starts on"].tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Monday")
        
        // Then: Selection is saved
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "Monday")
    }
}
```

## 4. Screen Tests

### Home Screen

```swift
// HomeScreenTests.swift
import XCTest

final class HomeScreenTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testEmptyStateElements() {
        // Then: All empty state elements are visible
        XCTAssertTrue(app.staticTexts["Create Your First Tracker"].exists)
        XCTAssertTrue(app.staticTexts["Start tracking your habits"].exists)
        XCTAssertTrue(app.buttons["Create Tracker"].exists)
    }
    
    func testTrackerTypeSections() {
        // Given: Trackers exist
        createTestTrackers()
        
        // Then: Tracker type sections are shown
        XCTAssertTrue(app.otherElements["Streak Section"].exists)
        XCTAssertTrue(app.otherElements["Counter Section"].exists)
    }
    
    func testAddButtonVisibility() {
        // Given: Trackers exist
        createTestTrackers()
        
        // Then: Add button is visible
        XCTAssertTrue(app.buttons["add Tracker"].exists)
    }
    
    private func createTestTrackers() {
        app.buttons["Create Tracker"].tap()
        app.cells["Streak"].tap()
        app.buttons["Create"].tap()
        
        app.buttons["add Tracker"].tap()
        app.cells["Counter"].tap()
        app.buttons["Create"].tap()
    }
}
```

## 5. Accessibility Tests

```swift
// AccessibilityTests.swift
import XCTest

final class AccessibilityTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testVoiceOverLabels() {
        // Then: All buttons have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertNotNil(button.accessibilityLabel)
        }
    }
    
    func testAccessibilityIdentifiers() {
        // Then: All interactive elements have accessibility identifiers
        let elements = app.otherElements.allElementsBoundByIndex
        for element in elements {
            // Check if element is interactive
            if element.isHittable {
                XCTAssertNotNil(element.accessibilityIdentifier)
            }
        }
    }
    
    func testDynamicTypeSupport() {
        // When: User changes text size
        app.settingsApp.buttons["Display & Text Size"].tap()
        app.settingsApp.cells["Larger Text"].tap()
        
        // Then: App adapts to larger text
        XCTAssertTrue(app.staticTexts["Create Your First Tracker"].exists)
        
        // Reset
        app.settingsApp.buttons["Track It"].tap()
    }
}
```

## 6. Test Utilities

### Test Helpers

```swift
// TestHelpers.swift
import XCTest

struct TestHelpers {
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    static func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    static func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Extensions

```swift
// XCUIElement+Extensions.swift
import XCTest

extension XCUIElement {
    func tapAndWait() {
        tap()
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    func clearText() {
        guard let stringValue = value as? String else {
            return
        }
        
        // Tap to focus
        tap()
        
        // Select all text
        let selectAll = XCUIApplication.privateRemoteHandling.selectAllMenuItem
        selectAll.tap()
        
        // Delete
        typeText(XCUIKeyboardKey.delete.rawValue)
    }
    
    func forceTap() {
        // For elements that don't respond to normal tap
        if exists {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
    
    func scrollToElement(_ element: XCUIElement) {
        // Scroll until element is visible
        while !element.visible() {
            scrollUp()
        }
    }
    
    func scrollUp() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
    
    func scrollDown() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
    
    func visible() -> Bool {
        guard exists else { return false }
        
        let frame = self.frame
        let screenFrame = XCUIScreen.main.coordinateSpace.frame
        
        return frame.intersects(screenFrame)
    }
}

extension XCUIApplication {
    static var privateRemoteHandling: XCUIRemoteHandling {
        return value(forKey: "privateRemoteHandling") as! XCUIRemoteHandling
    }
    
    static var selectAllMenuItem: XCUIElement {
        return privateRemoteHandling.menuItem("Select All")
    }
}
```

## 7. CI Integration

```yaml
# .github/workflows/ui-tests.yml
name: UI Tests

on: [push, pull_request]

jobs:
  ui-test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -switch /Applications/Xcode_15.app/Contents/Developer
    
    - name: Run UI Tests
      run: xcodebuild test \
        -workspace Track\ it.xcworkspace \
        -scheme Track\ it \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -only-testing:Track\ itUITests
    
    - name: Upload Screenshots
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: ui-test-screenshots
        path: /Users/arvoldek/Library/Developer/Xcode/DerivedData/*/Logs/Test/
```

## 8. Checklist

### User Flows
- [ ] Onboarding flow tested
- [ ] Tracker creation flow tested
- [ ] Tracker completion flow tested
- [ ] Calendar flow tested
- [ ] Graphs flow tested
- [ ] Settings flow tested

### Screens
- [ ] Empty state screen tested
- [ ] Tracker type selection tested
- [ ] Home screen tested
- [ ] Tracker detail tested
- [ ] Tracker creation tested
- [ ] Calendar tested
- [ ] Graphs tested
- [ ] Settings tested

### Accessibility
- [ ] VoiceOver support tested
- [ ] Dynamic Type tested
- [ ] Reduced Motion tested
- [ ] Color contrast verified

### CI/CD
- [ ] UI tests run on CI
- [ ] Tests run on multiple devices
- [ ] Screenshots captured on failure
- [ ] Test results reported

---

**Phase**: 6 - Testing  
**Section**: 6.2 - UI Tests  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1-5, 6.1  
**Last Updated**: [Date]  
**Version**: 1.0
