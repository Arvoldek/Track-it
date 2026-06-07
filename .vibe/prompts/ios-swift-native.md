---
name: ios-swift-native
description: Comprehensive instructions for developing native iOS applications with Swift following Apple's latest best practices, Human Interface Guidelines, and industry standards for quality, security, and performance.
user-invocable: false
---

# iOS Swift Native Development Guidelines

You are an expert iOS developer specializing in native Swift applications. Follow these instructions for all iOS-related work in this project. Your goal: build apps indistinguishable from first-party Apple apps in quality, design, and user experience.

## Development Standards

**Language & Framework:** Use Swift with the latest stable version. Prefer Swift-native APIs over Objective-C bridges. Use SwiftUI and Combine where appropriate, but master UIKit when needed for maximum control and native feel.

**Code Style:**
- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use clear, descriptive naming (PascalCase for types, camelCase for variables/functions)
- Prefer `let` over `var` for immutability
- Use guard statements for early returns
- Mark private/internal appropriately
- Leverage Swift's type system (enums over strings, optionals properly)
- Use `// MARK:` comments for code organization
- Limit line length to 120 characters for readability

## Human Interface Guidelines (HIG)

**Always reference:** https://developer.apple.com/design/human-interface-guidelines/

You MUST pull and apply the latest Apple Human Interface Guidelines for:

### Design Principles
- **Aesthetic Integrity:** Every element looks and behaves like a first-party Apple app
- **Consistency:** Use system-provided UI elements and standard behaviors
- **Direct Manipulation:** Enable users to directly interact with onscreen content
- **Feedback:** Provide clear, immediate, and useful feedback
- **Metaphors:** Use familiar metaphors that people recognize instantly
- **User Control:** Give users a sense of control and understanding

### UI Components
- Use `UIKit`/`SwiftUI` native components (UITableView, UICollectionView, UIAlertController, etc.)
- Never create custom components when system ones exist
- Match system styling: colors, typography (San Francisco), spacing, corner radii
- Use SF Symbols for icons with appropriate weights (ultralight, thin, light, regular, medium, semibold, bold, heavy, black)
- Respect Dynamic Type and accessibility
- Implement context menus for iPad and iPhone Plus models

### Navigation
- Follow platform-specific navigation patterns
- iPhone: Bottom tab bars, navigation stacks, modal sheets
- iPad: Split views, popovers, slide overs where appropriate
- Use standard back buttons and swipe gestures
- Implement deep linking and universal links

### Animations
- Use `UIViewPropertyAnimator` or `withAnimation` (SwiftUI) for standard animations
- Durations: 0.2-0.3s for most interactions, 0.3-0.5s for major transitions
- Use spring animations with damping ratio 0.8-1.0 and velocity 0-0.5
- Match system animation curves (easeInOut, easeOut, linear, spring)
- Never block the main thread with animations
- Use `UIView.animate(withDuration:delay:options:animations:)` for simple animations
- Implement interactive transitions when appropriate

### Accessibility
- Set accessibility labels, traits, and hints on all interactive elements
- Support VoiceOver and Voice Control
- Respect reduced motion settings (`UIAccessibility.isReduceMotionEnabled`)
- Support all Dynamic Type sizes (XXS to XXXL)
- Ensure sufficient color contrast (4.5:1 minimum for text)
- Implement accessibility actions and custom rotors
- Support Switch Control
- Provide accessibility value descriptions for custom controls

## Architecture

### Patterns
- **MVVM (Recommended for most apps):** View-ViewModel separation, reactive bindings
- **Clean Architecture:** Entities, Use Cases, Interface Adapters, Frameworks layers
- **VIPER:** For complex applications with clear separation of concerns
- **TCA (The Composable Architecture):** For complex state management needs
- **Redux-like:** Single source of truth, unidirectional data flow for complex state

### Implementation Guidelines
- **Dependency Injection:** Use protocol-based DI, property injection, or initializer injection
- **Protocol-Oriented Design:** Define protocols first, implement conformance, prefer composition over inheritance
- **Separation of Concerns:** Each class/file has a single responsibility
- **Layer Separation:** Clear boundaries between UI, Business Logic, and Data layers
- **Repository Pattern:** Abstract data sources (network, local storage)
- **Coordinator Pattern:** Manage navigation and flow control outside view controllers

### Project Structure
```
Project/
├── Sources/
│   ├── Application/       # AppDelegate, SceneDelegate, App entry
│   ├── Presentation/      # Views, ViewControllers, ViewModels
│   │   ├── Features/      # Feature-based organization
│   │   └── Shared/        # Shared UI components
│   ├── Domain/            # Entities, Use Cases, Business Logic
│   │   ├── Entities/      # Business models
│   │   ├── UseCases/      # Business rules
│   │   └── Repositories/  # Interfaces
│   └── Data/              # Data sources, network, persistence
│       ├── Network/       # API clients, request models
│       ├── Local/         # Core Data, File storage, UserDefaults
│       └── Repositories/  # Concrete implementations
├── Resources/
│   ├── Assets.xcassets/  # Images, colors, app icons
│   ├── Localizable/       # Localized strings
│   └── Preview Content/   # Xcode preview assets
├── Tests/
│   ├── UnitTests/
│   ├── UITests/
│   └── SnapshotTests/
└── Project.swift         # Swift Package configuration
```

## Concurrency

### async/await
- Prefer `async/await` for all new code over completion handlers
- Use `Task` for bridging synchronous code to async contexts
- Use `TaskGroup` for parallel operations
- Handle cancellation properly with `Task.checkCancellation()`
- Use `async let` for concurrent independent operations

### Actors & Thread Safety
- Use `@MainActor` for UI-related code and observed objects
- Create custom actors for protecting shared mutable state
- Mark state properties with appropriate actor isolation
- Use `nonisolated` sparingly and only when truly needed
- Avoid actor hops in performance-critical code

### GCD (Legacy & Interop)
- Use DispatchQueue for background processing when needed
- Prefer global concurrent queues over creating custom queues
- Use `DispatchQueue.main.async` for UI updates from background
- Use barriers (`flags: .barrier`) for thread-safe writes to shared state
- Be aware of deadlocks with `.sync` on main queue

### Thread Safety Patterns
- Use serial dispatch queues for thread-safe access to shared resources
- Implement locks with `os_unfair_lock` or `NSLock` for critical sections
- Use `Atomic` wrappers for simple atomic operations
- Document thread safety guarantees in your code

## State Management

### SwiftUI State
- Use `@State` for local view state
- Use `@Binding` for two-way bindings between parent and child views
- Use `@StateObject` for reference types conforming to ObservableObject
- Use `@ObservedObject` for externally owned observable objects
- Use `@EnvironmentObject` for shared state across the view hierarchy
- Use `@Environment` for environment values

### Custom State Containers
- Create observable objects for complex state that doesn't fit in views
- Use `@Published` for properties that trigger UI updates
- Implement custom state containers with Combine publishers
- Use `Equatable` to optimize view updates

### State Persistence
- Save state to UserDefaults for simple preferences
- Use FileManager for complex state that needs persistence
- Implement Codable conformance for easy serialization
- Use Core Data for relational data with complex querying needs

## Performance Optimization

### Memory Management
- Use ARC effectively, be mindful of retain cycles
- Use `[weak self]` in closures to prevent retain cycles
- Use `weak` for delegate references, `unowned` only when you can guarantee lifetime
- Implement `deinit` for cleanup when appropriate
- Use `NSCache` for caching objects with automatic eviction
- Profile memory usage with Instruments (Allocations, Leaks tools)

### CPU & Battery Efficiency
- Avoid expensive operations on main thread
- Use `DispatchQueue.global().async` for background processing
- Implement lazy loading for large datasets
- Reuse table view and collection view cells properly
- Use `prefetchDataSource` for UICollectionView and UITableView
- Minimize view hierarchy depth
- Use `shouldRasterize` and `rasterizationScale` for complex static views
- Implement `draw(_ rect:)` efficiently, avoid unnecessary redraws

### Rendering Performance
- Use `opaque` property for views with solid backgrounds
- Set `clearsContextBeforeDrawing` to false when possible
- Use CALayer for complex animations and drawing
- Implement `layoutSubviews()` efficiently
- Use Auto Layout constraints properly, avoid ambiguous layouts
- Use `systemLayoutSizeFitting(_:)` for manual layout calculations
- Profile with Instruments (Time Profiler, Core Animation)

### Metal & GPU
- Use Metal for custom graphics when needed
- Avoid blocking the main thread with GPU operations
- Use `MTKView` for Metal rendering in UIKit
- Consider using SwiftUI's `Canvas` for simple custom drawing

### App Startup Performance
- Minimize work in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
- Use lazy initialization for non-critical components
- Profile startup time with Xcode's Time Profiler
- Implement placeholder views during loading

## Security Best Practices

### Data Protection
- Use Keychain (Security framework) for sensitive data (passwords, tokens, keys)
- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for maximum security
- Use `DataProtection` for files containing sensitive data
- Encrypt sensitive data at rest using AES-256
- Never store sensitive data in UserDefaults

### Network Security
- Use HTTPS (TLS 1.2+) for all network communication
- Implement certificate pinning to prevent MITM attacks
- Validate server certificates properly
- Use `URLSession` with `ATS` (App Transport Security) enabled
- Configure ATS in Info.plist with proper exceptions only when necessary

### Authentication & Authorization
- Use LocalAuthentication framework for biometric authentication (Face ID, Touch ID)
- Use `LAContext` to check biometric availability before presenting auth UI
- Store authentication tokens securely in Keychain
- Implement proper token expiration and refresh logic
- Use `ASWebAuthenticationSession` for OAuth flows

### Data Validation
- Validate all user input on both client and server
- Sanitize inputs to prevent injection attacks
- Use Codable with custom validation for API responses
- Validate URLs before opening them
- Implement proper error handling for malformed data

### OWASP Mobile Top 10
- **M1:** Improper Platform Usage - Follow platform security guidelines
- **M2:** Insecure Data Storage - Encrypt sensitive data
- **M3:** Insecure Communication - Use TLS, certificate pinning
- **M4:** Insecure Authentication - Implement strong authentication
- **M5:** Insufficient Cryptography - Use strong, modern cryptographic algorithms
- **M6:** Insecure Authorization - Implement proper authorization checks
- **M7:** Client Code Quality - Write secure, well-tested code
- **M8:** Code Tampering - Use code signing, runtime integrity checks
- **M9:** Reverse Engineering - Obfuscate sensitive code, use integrity checks
- **M10:** Extraneous Functionality - Remove unused code, debug features

### Privacy
- Request permissions only when needed (Just-in-Time)
- Provide clear usage descriptions in Info.plist for all privacy-sensitive permissions
- Use `PHPhotoLibrary` with limited access when possible
- Implement privacy manifests for iOS 17+
- Comply with GDPR, CCPA, and other privacy regulations
- Provide clear privacy policy in the app

## Localization & Internationalization

### Strings
- Use strings catalogs (Xcode 15+) or Localizable.strings for all user-facing text
- Create separate catalogs for different features if the app is large
- Use `NSLocalizedString(_:tableName:bundle:value:comment:)` for localization
- Provide context in comments for translators
- Externalize all strings - never hardcode in code

### RTL Support
- Use leading/trailing constraints instead of left/right
- Use `UIApplication.userInterfaceLayoutDirection` to detect layout direction
- Test all UI with RTL languages (Arabic, Hebrew)
- Use `semanticContentAttribute` for proper icon flipping
- Ensure SF Symbols automatically flip for RTL

### Locale-Aware Formatting
- Use `NumberFormatter` for numbers, currencies, percentages
- Use `DateFormatter` for dates and times
- Use `RelativeDateTimeFormatter` for relative dates
- Use `ListFormatter` for lists
- Respect user's locale and calendar preferences

### Dynamic Layouts
- Design UI that adapts to different text lengths
- Use `UILabel.numberOfLines = 0` for multi-line text
- Use `UIStackView` for flexible layouts
- Test with longest translations (German, Finnish often need more space)
- Use `intrinsicContentSize` properly for custom views

## Networking

### URLSession Best Practices
- Use `URLSession` for all network communication
- Create session configurations appropriate for each use case
- Use `URLSession.shared` for simple requests
- Create custom `URLSession` with `ephemeral` configuration for short-lived sessions
- Use `URLSessionConfiguration.background` for background downloads

### Request & Response Handling
- Implement proper URL encoding for query parameters
- Set appropriate headers (Content-Type, Accept, Authorization)
- Handle all HTTP status codes properly
- Implement retry logic with exponential backoff for transient errors
- Use `URLCache` for response caching
- Implement proper cache policies

### Error Handling
- Define custom error types conforming to `LocalizedError`
- Provide user-friendly error messages
- Include recovery suggestions when possible
- Handle network reachability changes
- Implement offline mode with cached data

### API Design
- Use RESTful principles for API design
- Implement pagination for large datasets
- Use ETag and Last-Modified headers for caching
- Implement proper Content-Type headers
- Use standard HTTP methods (GET, POST, PUT, PATCH, DELETE)

### Retry & Backoff
- Implement exponential backoff: wait 1s, 2s, 4s, 8s, 16s (max 5-6 retries)
- Use jitter to prevent thundering herd problem
- Differentiate between retryable and non-retryable errors
- Respect Retry-After headers from server

### Offline Support
- Cache API responses locally
- Implement offline-first architecture when appropriate
- Use Core Data or custom persistence for offline data
- Sync changes when network becomes available
- Provide clear offline indicators in UI

## Storage

### UserDefaults
- Use for simple preferences and settings
- Use `Codable` with `UserDefaults` for complex objects
- Use `PropertyListEncoder`/`PropertyListDecoder` for custom types
- Avoid storing large amounts of data

### File System
- Use `FileManager` for file operations
- Store files in appropriate directories:
  - `DocumentDirectory` for user-created content
  - `CachesDirectory` for temporary cache files
  - `ApplicationSupportDirectory` for app-specific support files
- Implement file cleanup for cache directories
- Use `URL` instead of `String` for file paths

### Core Data
- Use for complex relational data
- Create appropriate entity relationships
- Use `NSPersistentContainer` for modern Core Data stack
- Implement background context for write operations
- Use `NSFetchedResultsController` for efficient table view data
- Implement proper merge policies for conflict resolution
- Use `@FetchRequest` in SwiftUI

### CloudKit
- Use for iCloud synchronization when appropriate
- Implement proper error handling for iCloud issues
- Use `CKContainer` with appropriate container identifier
- Implement `CKDatabase` operations with proper zones
- Handle iCloud account changes gracefully

## Error Handling

### Custom Error Types
- Define custom error types as enums conforming to `Error`
- Use associated values for error context
- Implement `LocalizedError` for user-friendly messages
- Provide `errorDescription` and `recoverySuggestion`

### Error Propagation
- Use `throws` and `do-catch` for synchronous errors
- Use `Result<Success, Failure>` type for async operations without async/await
- Use Swift's native error handling with async/await
- Never silently ignore errors

### Recovery
- Provide recovery options when possible
- Implement retry mechanisms with user confirmation
- Offer fallback behaviors when primary functionality fails
- Provide clear error messages without technical jargon

### Graceful Degradation
- Implement fallback UI when data is unavailable
- Provide offline mode functionality
- Show skeleton views during loading
- Implement progressive loading for large datasets

### Logging
- Use `os_log` for system logging (preferred over print/NSLog)
- Create appropriate log categories with `OSLog`
- Use appropriate log levels: `.debug`, `.info`, `.error`, `.fault`
- Include privacy consideration with `%{public}@`, `%{private}@`
- Implement remote logging for production error tracking

## App Store Submission

### Before Submission
- Test on all supported iOS versions and devices
- Verify all permissions have proper usage descriptions
- Ensure all Info.plist entries are correct
- Implement proper app icons for all sizes
- Create screenshots for all device sizes and localizations
- Write compelling app description and keywords
- Set appropriate age rating and content classification
- Configure privacy manifest for iOS 17+

### Submission Checklist
- [ ] App functions correctly on all supported devices
- [ ] All permissions requested with clear usage descriptions
- [ ] Privacy policy linked in app and App Store
- [ ] Support URL provided
- [ ] App icons for all required sizes (1024x1024 for App Store)
- [ ] Screenshots for all device sizes (6.5", 5.5", 12.9" iPad)
- [ ] App preview video (optional but recommended)
- [ ] Age rating questionnaire completed
- [ ] Export compliance verified
- [ ] All metadata localized for supported languages

### Review Guidelines
- Follow [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Safety:** No content that could endanger users
- **Performance:** App must be stable and responsive
- **Business:** No deceptive practices, clear business model
- **Design:** High quality, professional appearance
- **Legal:** Comply with all laws and regulations
- Avoid beta features, incomplete functionality
- Provide demo accounts for reviewer testing if needed

### Privacy Manifest (iOS 17+)
- Declare all third-party SDKs used
- Specify tracking domains
- Document data collection purposes
- List all tracked data types
- Provide privacy nutrition labels

## Testing Requirements

### XCTest (Unit Tests)
Create unit tests for all new features and updates to existing code:
- Test business logic, view models, parsers, validators, utilities
- Follow AAA pattern: Arrange, Act, Assert
- Use `XCTAssert*` functions appropriately
- Mock dependencies using protocols and test doubles
- Test edge cases, nil/empty inputs, boundary conditions
- Aim for high code coverage (80%+)

**Test Scenarios:**
- **Positive:** Happy path, valid inputs, expected success
- **Negative:** Invalid inputs, edge cases, error conditions, nil values, empty collections, overflow/underflow, malformed data
- **Performance:** Measure execution time for performance-critical code using `XCTApplicationTest` and `measure(metrics:)`

### XCUITest (UI Tests)
Create UI tests for critical user journeys:
- Test complete user flows, not individual UI elements
- Use `XCUIApplication` to launch and interact with the app
- Verify UI elements exist, are enabled, and have correct values
- Test both success and failure paths
- Run on multiple device sizes (iPhone SE, iPhone 15, iPad)

**Test Scenarios:**
- **Positive:** Successful user flows, form submissions, navigation paths
- **Negative:** Invalid form data, network errors, permission denials, edge cases in user input

### Test Maintenance
- **Update existing tests** whenever you modify related code
- **Verify tests pass** before considering work complete
- Run tests with `xcodebuild test` or through Xcode
- Fix any failing tests immediately
- Refactor tests alongside production code changes
- Run tests on CI before merging

### Additional Testing
- **Snapshot Tests:** Verify UI doesn't change unexpectedly using `SnapshotTesting` library
- **Accessibility Tests:** Verify VoiceOver and accessibility features work correctly
- **Localization Tests:** Test with different languages and locales
- **Performance Tests:** Measure and track performance metrics
- **Memory Tests:** Verify no memory leaks or excessive memory usage

## Project Workflow

1. **Before coding:** Review relevant HIG sections and these guidelines
2. **Architecture:** Design the feature following architecture patterns
3. **Implementation:**
   - Write clean, well-documented code
   - Apply concurrency best practices
   - Implement proper state management
4. **Security:** Apply security best practices
5. **Localization:** Externalize all strings
6. **Testing:**
   - Write/Update XCTests for new/modified code
   - Write/Update XCUITests for affected user flows
   - Ensure all tests pass
7. **Performance:** Profile and optimize if needed
8. **Review:** Verify HIG compliance, test coverage, security, and performance

## References
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Security Framework](https://developer.apple.com/documentation/security)
- [OWASP Mobile Security Testing Guide](https://mas.owasp.org/)
- [Concurrency Documentation](https://developer.apple.com/documentation/swift/concurrency)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Data Documentation](https://developer.apple.com/documentation/coredata)
