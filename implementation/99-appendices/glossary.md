# Glossary

## Terms and Definitions

### Architecture Terms

- **Clean Architecture**: A software design philosophy that separates the elements of a design into ring levels, where the inner rings contain the business logic and the outer rings contain the implementation details.
- **MVVM (Model-View-ViewModel)**: A design pattern that separates the business logic and presentation layer from the user interface.
- **Repository Pattern**: A design pattern that abstracts the data access layer, providing a collection-like interface for accessing domain objects.
- **Dependency Injection**: A design pattern that allows for decoupling the creation of dependencies from the classes that use them.
- **Coordinator Pattern**: A design pattern that centralizes navigation logic in a dedicated object.

### Domain Terms

- **Tracker**: The main domain object representing a habit, streak, counter, or time-based event that the user wants to track.
- **Streak Tracker**: A tracker type that counts consecutive days of completion.
- **Negative Streak Tracker**: A tracker type that counts consecutive days of avoidance (not doing something).
- **Time Since Tracker**: A tracker type that counts time elapsed since a specific event.
- **Time Ahead Tracker**: A tracker type that counts down to a future event.
- **Counter Tracker**: A tracker type that counts occurrences, with optional threshold.
- **Tracker History**: A record of a tracker's completion status and value for a specific date.
- **Reminder**: A notification that can be scheduled to remind the user about a tracker.

### Technical Terms

- **Core Data**: Apple's object graph and persistence framework for iOS and macOS.
- **CloudKit**: Apple's cloud-based database service for storing app data.
- **NSPersistentCloudKitContainer**: A Core Data container that automatically synchronizes with CloudKit.
- **iCloud Sync**: The process of synchronizing data between devices using iCloud.
- **Local Notifications**: Alerts that are scheduled and displayed by the local device.
- **UNUserNotificationCenter**: The iOS framework for managing local and remote notifications.
- **Combine Framework**: Apple's framework for reactive programming with Swift.
- **SwiftUI**: Apple's declarative framework for building user interfaces.

### UI Terms

- **HIG (Human Interface Guidelines)**: Apple's design principles and best practices for iOS and macOS apps.
- **SF Symbols**: Apple's built-in icon library for iOS and macOS.
- **Dynamic Type**: Apple's system for adjustable text sizes based on user preferences.
- **Accessibility**: Features that make apps usable by people with disabilities.

### Development Terms

- **XCTest**: Apple's testing framework for unit tests and UI tests.
- **XCUITest**: Apple's framework for UI testing.
- **Snapshot Tests**: Tests that verify UI doesn't change unexpectedly by comparing rendered views to stored snapshots.
- **Code Coverage**: A metric that measures the percentage of code executed during testing.
- **Continuous Integration (CI)**: The practice of automatically building, testing, and deploying code changes.

## Acronyms

| Acronym | Meaning |
|--------|---------|
| HIG | Human Interface Guidelines |
| MVVM | Model-View-ViewModel |
| MVC | Model-View-Controller |
| VIPER | View-Interactor-Presenter-Entity-Router |
| TCA | The Composable Architecture |
| UI | User Interface |
| UX | User Experience |
| iOS | iPhone Operating System |
| macOS | Macintosh Operating System |
| iPadOS | iPad Operating System |
| SDK | Software Development Kit |
| API | Application Programming Interface |
| CRUD | Create, Read, Update, Delete |
| URL | Uniform Resource Locator |
| JSON | JavaScript Object Notation |
| UUID | Universally Unique Identifier |
| NS | NextStep (prefix for Apple frameworks) |
| UI | User Interface |
| CK | CloudKit |
| UN | User Notifications |
| EK | EventKit |

## File Extensions

| Extension | Meaning |
|-----------|---------|
| .swift | Swift source code |
| .md | Markdown documentation |
| .xcodeproj | Xcode project file |
| .xcworkspace | Xcode workspace file |
| .pbxproj | Project builder project file |
| .xcdatamodeld | Core Data model file |
| .xcassets | Asset catalog |
| .xcstrings | Localized strings catalog |
| .plist | Property list (configuration) |
| .entitlements | App entitlements file |
| .cer | Certificate file |
| .mobileprovision | Provisioning profile |

## Design System Terms

- **Semantic Colors**: Colors that represent specific meanings (e.g., success, error, warning).
- **Typography**: The style, arrangement, and appearance of text.
- **Spacing System**: A consistent set of spacing values used throughout the app.
- **Component Library**: A collection of reusable UI components.
- **Design Token**: A variable that represents a design value (e.g., color, spacing, typography).

## Testing Terms

- **Unit Test**: A test that verifies the functionality of a single unit of code (e.g., a function or method).
- **UI Test**: A test that verifies the behavior and appearance of the user interface.
- **Integration Test**: A test that verifies the interaction between multiple components.
- **Mock**: A test double that simulates the behavior of a real object.
- **Stub**: A test double that provides predefined responses to calls.
- **Spy**: A test double that records information about calls made to it.
- **Test Coverage**: The percentage of code that is executed by tests.
- **Assertion**: A condition that must be true for a test to pass.

## Performance Terms

- **CPU**: Central Processing Unit - the main processor of the device.
- **GPU**: Graphics Processing Unit - the processor that handles graphics rendering.
- **Memory**: The device's RAM (Random Access Memory) used for temporary data storage.
- **FPS**: Frames Per Second - a measure of animation smoothness.
- **Latency**: The time delay between a user action and the app's response.
- **Throughput**: The amount of data processed in a given time period.
- **Battery Efficiency**: How efficiently the app uses the device's battery.

## Security Terms

- **Encryption**: The process of converting data into a secure format that can only be read by authorized parties.
- **Keychain**: Apple's secure storage for sensitive data like passwords and cryptographic keys.
- **Sandbox**: A security mechanism that restricts an app's access to system resources.
- **App Transport Security (ATS)**: A feature that enforces secure connections between an app and web services.
- **TLS/SSL**: Transport Layer Security/Secure Sockets Layer - protocols for secure communication over a network.
- **OWASP**: Open Web Application Security Project - an organization that provides resources for software security.

## App Store Terms

- **App Review**: The process by which Apple reviews apps before they are published on the App Store.
- **App Store Guidelines**: The rules and requirements that apps must follow to be published on the App Store.
- **Metadata**: Information about the app such as name, description, keywords, and screenshots.
- **Localization**: The process of adapting an app for different languages and regions.
- **Privacy Policy**: A document that describes how an app collects, uses, and shares user data.
- **Age Rating**: A classification that indicates the minimum age for which an app is suitable.
