# Phase 1: Architecture Design

## Overview

This document defines the architectural patterns, layer separation, and design principles for the Track It application. The architecture follows **Clean Architecture** principles combined with **MVVM** for the presentation layer, ensuring testability, maintainability, and scalability.

## 1. Architectural Pattern: Clean Architecture + MVVM

### 1.1 Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    SwiftUI Views                           │  │
│  │  - TrackerListView, TrackerDetailView, SettingsView, etc.│  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   ViewModels (MVVM)                        │  │
│  │  - TrackerListViewModel, TrackerDetailViewModel, etc.    │  │
│  │  - Contains presentation logic and state                  │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Coordinators                             │  │
│  │  - Handles navigation between screens                     │  │
│  │  - Manages view controller/view hierarchy                 │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Entities                                │  │
│  │  - Tracker, StreakTracker, CounterTracker, etc.           │  │
│  │  - Pure Swift structs/classes (no frameworks)             │  │
│  │  - Business objects with no external dependencies        │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Use Cases                                │  │
│  │  - CreateTrackerUseCase, CompleteTrackerUseCase, etc.     │  │
│  │  - Contains all business logic                            │  │
│  │  - Orchestrates interactions between entities             │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Repositories (Interfaces)               │  │
│  │  - TrackerRepositoryProtocol, SettingsRepositoryProtocol │  │
│  │  - Defines data access contracts                         │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Repositories (Implementations)           │  │
│  │  - CoreDataTrackerRepository                              │  │
│  │  - UserDefaultsSettingsRepository                         │  │
│  │  - Implements repository protocols from Domain layer     │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Data Sources                             │  │
│  │  - Core Data Stack (NSPersistentContainer)               │  │
│  │  - CloudKit Sync (NSPersistentCloudKitContainer)          │  │
│  │  - UserDefaults for simple settings                      │  │
│  │  - File storage for complex data                          │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Services                                 │  │
│  │  - NotificationService, ReminderService, DateService     │  │
│  │  - Provides cross-cutting functionality                   │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Layer Responsibilities

| Layer | Responsibility | Dependencies | Testability |
|-------|---------------|--------------|-------------|
| **Presentation** | UI, User Interaction, Display Logic | Domain, Infrastructure | UI Tests, Snapshot Tests |
| **Domain** | Business Logic, Entities, Use Cases | None | Unit Tests |
| **Data** | Data Persistence, External Services | Domain (interfaces), Infrastructure | Unit Tests (mocked) |
| **Infrastructure** | Cross-cutting Services | Apple Frameworks | Unit Tests (mocked) |

## 2. Design Principles

### 2.1 SOLID Principles

- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Subtypes must be substitutable for base types
- **Interface Segregation**: Many specific interfaces > one general interface
- **Dependency Inversion**: Depend on abstractions, not concretions

### 2.2 Additional Principles

- **Separation of Concerns**: Each layer has distinct responsibilities
- **Dependency Rule**: Inner layers don't know about outer layers
- **Testability**: All business logic must be testable in isolation
- **Immutability**: Prefer `let` over `var`, use value types where possible
- **Protocol-Oriented Design**: Define protocols first, then implementations

## 3. MVVM Implementation

### 3.1 View Model Design

```swift
// Protocol for ViewModels
protocol ViewModel: ObservableObject {
    associatedtype Input
    associatedtype Output
    
    func transform(input: Input) -> Output
}

// Base ViewModel with common functionality
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error? = nil
    @Published var showAlert = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func bind() {}
    func unbind() {
        cancellables.removeAll()
    }
    
    deinit {
        unbind()
    }
}

// Example: TrackerListViewModel
final class TrackerListViewModel: BaseViewModel {
    @Published var trackers: [Tracker] = []
    @Published var filter: TrackerFilter = .all
    @Published var searchText = ""
    
    private let getTrackersUseCase: GetTrackersUseCase
    private let createTrackerUseCase: CreateTrackerUseCase
    private let deleteTrackerUseCase: DeleteTrackerUseCase
    
    // Dependencies injected
    init(
        getTrackersUseCase: GetTrackersUseCase,
        createTrackerUseCase: CreateTrackerUseCase,
        deleteTrackerUseCase: DeleteTrackerUseCase
    ) {
        self.getTrackersUseCase = getTrackersUseCase
        self.createTrackerUseCase = createTrackerUseCase
        self.deleteTrackerUseCase = deleteTrackerUseCase
        super.init()
        bind()
    }
    
    override func bind() {
        // Bind to use cases
        $searchText
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.searchTrackers(text: text)
            }
            .store(in: &cancellables)
    }
    
    func loadTrackers() {
        Task {
            isLoading = true
            do {
                trackers = try await getTrackersUseCase.execute()
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    func createTracker(_ tracker: Tracker) {
        Task {
            do {
                try await createTrackerUseCase.execute(tracker)
                await loadTrackers()
            } catch {
                self.error = error
            }
        }
    }
}
```

### 3.2 View Design (SwiftUI)

```swift
// TrackerListView
struct TrackerListView: View {
    @StateObject private var viewModel: TrackerListViewModel
    
    // Coordinator for navigation
    @EnvironmentObject private var coordinator: AppCoordinator
    
    init(viewModel: TrackerListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.trackers) { tracker in
                    TrackerRowView(tracker: tracker)
                        .onTapGesture {
                            coordinator.navigateToTrackerDetail(tracker)
                        }
                }
            }
            .navigationTitle("Trackers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addTracker) {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $viewModel.searchText)
            .alert("Error", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
            .task {
                viewModel.loadTrackers()
            }
        }
    }
    
    private func addTracker() {
        coordinator.navigateToTrackerCreation()
    }
}
```

## 4. Coordinator Pattern

### 4.1 Navigation Architecture

```swift
// AppCoordinator Protocol
protocol AppCoordinatorProtocol: AnyObject {
    func navigateToTrackerList()
    func navigateToTrackerDetail(_ tracker: Tracker)
    func navigateToTrackerCreation()
    func navigateToSettings()
    func dismiss()
    func popToRoot()
}

// AppCoordinator Implementation
final class AppCoordinator: AppCoordinatorProtocol {
    private let navigationController: UINavigationController
    private let dependencyContainer: DependencyContainer
    
    init(
        navigationController: UINavigationController,
        dependencyContainer: DependencyContainer
    ) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Check if user has any trackers
        let hasTrackers = dependencyContainer.trackerRepository.hasTrackers()
        
        if hasTrackers {
            navigateToTrackerList()
        } else {
            navigateToEmptyState()
        }
    }
    
    func navigateToTrackerList() {
        let viewModel = TrackerListViewModel(
            getTrackersUseCase: dependencyContainer.getTrackersUseCase,
            createTrackerUseCase: dependencyContainer.createTrackerUseCase,
            deleteTrackerUseCase: dependencyContainer.deleteTrackerUseCase
        )
        let view = TrackerListView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    func navigateToTrackerDetail(_ tracker: Tracker) {
        let viewModel = TrackerDetailViewModel(
            tracker: tracker,
            updateTrackerUseCase: dependencyContainer.updateTrackerUseCase,
            completeTrackerUseCase: dependencyContainer.completeTrackerUseCase
        )
        let view = TrackerDetailView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    func navigateToTrackerCreation() {
        let viewModel = TrackerCreationViewModel(
            createTrackerUseCase: dependencyContainer.createTrackerUseCase
        )
        let view = TrackerCreationView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.present(hostingController, animated: true)
    }
    
    func navigateToEmptyState() {
        let viewModel = EmptyStateViewModel()
        let view = EmptyStateView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.viewControllers = [hostingController]
    }
    
    func dismiss() {
        navigationController.dismiss(animated: true)
    }
    
    func popToRoot() {
        navigationController.popToRootViewController(animated: true)
    }
}
```

### 4.2 SwiftUI Navigation Adapter

Since we're using SwiftUI for views but need UIKit navigation for better control:

```swift
// NavigationAdapter for SwiftUI
struct NavigationAdapter: UIViewControllerRepresentable {
    @EnvironmentObject var coordinator: AppCoordinator
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let navController = UINavigationController()
        // Configure appearance
        navController.navigationBar.prefersLargeTitles = true
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Handle updates if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NavigationAdapter
        
        init(_ parent: NavigationAdapter) {
            self.parent = parent
        }
    }
}

// In TrackItApp.swift
@main
struct TrackItApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    private let coordinator: AppCoordinator
    
    init() {
        let navigationController = UINavigationController()
        let dependencyContainer = DependencyContainer()
        coordinator = AppCoordinator(
            navigationController: navigationController,
            dependencyContainer: dependencyContainer
        )
        coordinator.start()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationAdapter()
                .environmentObject(coordinator)
        }
    }
}
```

## 5. Dependency Injection

### 5.1 Dependency Container

```swift
// DependencyContainer
final class DependencyContainer {
    // MARK: - Repositories
    
    private(set) lazy var trackerRepository: TrackerRepositoryProtocol = {
        CoreDataTrackerRepository(persistenceController: persistenceController)
    }()
    
    private(set) lazy var settingsRepository: SettingsRepositoryProtocol = {
        UserDefaultsSettingsRepository()
    }()
    
    // MARK: - Services
    
    private(set) lazy var notificationService: NotificationServiceProtocol = {
        UserNotificationService()
    }()
    
    private(set) lazy var reminderService: ReminderServiceProtocol = {
        LocalReminderService(
            notificationService: notificationService,
            settingsRepository: settingsRepository
        )
    }()
    
    private(set) lazy var dateService: DateServiceProtocol = {
        SystemDateService()
    }()
    
    // MARK: - Use Cases
    
    private(set) lazy var getTrackersUseCase: GetTrackersUseCase = {
        GetTrackersUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var createTrackerUseCase: CreateTrackerUseCase = {
        CreateTrackerUseCase(
            trackerRepository: trackerRepository,
            reminderService: reminderService
        )
    }()
    
    private(set) lazy var updateTrackerUseCase: UpdateTrackerUseCase = {
        UpdateTrackerUseCase(trackerRepository: trackerRepository)
    }()
    
    private(set) lazy var deleteTrackerUseCase: DeleteTrackerUseCase = {
        DeleteTrackerUseCase(
            trackerRepository: trackerRepository,
            reminderService: reminderService
        )
    }()
    
    private(set) lazy var completeTrackerUseCase: CompleteTrackerUseCase = {
        CompleteTrackerUseCase(
            trackerRepository: trackerRepository,
            dateService: dateService
        )
    }()
    
    // MARK: - Core Data
    
    private(set) lazy var persistenceController: PersistenceController = {
        PersistenceController(
            containerName: "TrackIt",
            cloudKitContainerOptions: CloudKitContainerOptions()
        )
    }()
}
```

### 5.2 Protocol-Based Injection

```swift
// Example: TrackerRepositoryProtocol
protocol TrackerRepositoryProtocol {
    func getAllTrackers() async throws -> [Tracker]
    func getTracker(byId id: UUID) async throws -> Tracker?
    func createTracker(_ tracker: Tracker) async throws
    func updateTracker(_ tracker: Tracker) async throws
    func deleteTracker(_ tracker: Tracker) async throws
    func hasTrackers() -> Bool
    func getTrackers(byType type: TrackerType) async throws -> [Tracker]
    func getTrackerHistory(trackerId: UUID) async throws -> [TrackerHistory]
}

// Example: NotificationServiceProtocol
protocol NotificationServiceProtocol {
    func requestAuthorization() async throws
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool,
        repeatInterval: Calendar.Component?
    ) async throws
    func cancelNotification(id: String) async
    func cancelAllNotifications() async
}
```

## 6. State Management

### 6.1 Combine Framework

Use Combine for reactive programming:

```swift
// Example: Tracker state management
class Tracker: ObservableObject, Identifiable {
    @Published var id: UUID
    @Published var name: String
    @Published var type: TrackerType
    @Published var isCompleted: Bool
    @Published var streakCount: Int
    @Published var targetCount: Int
    @Published var completionFrequency: CompletionFrequency
    @Published var reminder: Reminder?
    @Published var history: [TrackerHistory]
    
    // Computed properties
    var progress: Double {
        Double(streakCount) / Double(targetCount)
    }
    
    var statusColor: Color {
        isCompleted ? .green : .red
    }
}

// Example: Using Combine in ViewModel
final class TrackerDetailViewModel: ObservableObject {
    @Published var tracker: Tracker
    @Published var showHistory = false
    @Published var showEditSheet = false
    
    private var cancellables = Set<AnyCancellable>()
    private let updateTrackerUseCase: UpdateTrackerUseCase
    
    init(tracker: Tracker, updateTrackerUseCase: UpdateTrackerUseCase) {
        self.tracker = tracker
        self.updateTrackerUseCase = updateTrackerUseCase
        bind()
    }
    
    private func bind() {
        tracker.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func toggleCompletion() {
        Task {
            tracker.isCompleted.toggle()
            try await updateTrackerUseCase.execute(tracker)
        }
    }
}
```

### 6.2 @ObservedObject vs @StateObject

- Use `@StateObject` for view-owned objects (created within the view)
- Use `@ObservedObject` for externally-created objects (passed in)
- Use `@EnvironmentObject` for shared objects across the hierarchy

## 7. Design System

### 7.1 Color Palette

```swift
// Color+Extensions.swift
exension Color {
    // Semantic Colors
    static let primary = Color("AccentColor")
    static let secondary = Color("SecondaryColor")
    static let background = Color("BackgroundColor")
    static let surface = Color("SurfaceColor")
    static let error = Color("ErrorColor")
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    
    // Tracker Type Colors
    static let streak = Color("StreakColor")
    static let negativeStreak = Color("NegativeStreakColor")
    static let timeSince = Color("TimeSinceColor")
    static let timeAhead = Color("TimeAheadColor")
    static let counter = Color("CounterColor")
}
```

### 7.2 Typography

```swift
// Font+Extensions.swift
exension Font {
    // Headlines
    static let headline1 = Font.system(.largeTitle, design: .rounded)
    static let headline2 = Font.system(.title, design: .rounded)
    static let headline3 = Font.system(.title2, design: .rounded)
    static let headline4 = Font.system(.title3, design: .rounded)
    
    // Body
    static let body = Font.system(.body, design: .rounded)
    static let bodyBold = Font.system(.body, design: .rounded).weight(.semibold)
    
    // Captions
    static let caption = Font.system(.caption, design: .rounded)
    static let captionBold = Font.system(.caption, design: .rounded).weight(.semibold)
    
    // Buttons
    static let button = Font.system(.headline, design: .rounded)
}
```

### 7.3 Spacing System

```swift
// Spacing.swift
enum Spacing {
    static let xxs = 4.0
    static let xs = 8.0
    static let sm = 12.0
    static let md = 16.0
    static let lg = 24.0
    static let xl = 32.0
    static let xxl = 48.0
}
```

## 8. Delivery Checklist

- [ ] Architecture diagram created
- [ ] Layer responsibilities defined
- [ ] MVVM pattern implemented for sample feature
- [ ] Coordinator pattern implemented
- [ ] Dependency injection container created
- [ ] Design system defined (colors, fonts, spacing)
- [ ] Base classes and protocols created
- [ ] All patterns documented

---

**Duration**: 2 days
**Priority**: Critical
**Next**: Proceed to [03-data-models.md](./03-data-models.md)
