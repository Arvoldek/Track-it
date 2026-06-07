# Phase 1: Base Classes & Protocols

## Overview

This document defines the base classes, protocols, and extensions that form the foundation of the Track It application. These components provide common functionality, reduce code duplication, and ensure consistent behavior across the app.

## 1. Base Classes

### 1.1 BaseViewModel

```swift
// BaseViewModel.swift
import Combine
import SwiftUI

/// Base class for all ViewModels providing common functionality
class BaseViewModel: ObservableObject {
    
    // MARK: - State
    
    @Published var isLoading = false
    @Published var error: Error? = nil
    @Published var showAlert = false
    @Published var alertTitle = "Error"
    @Published var alertMessage = ""
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    init() {
        bind()
    }
    
    deinit {
        unbind()
    }
    
    /// Override to set up bindings
    func bind() {
        // Bind error to alert
        $error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
            .store(in: &cancellables)
    }
    
    /// Override to clean up bindings
    func unbind() {
        cancellables.removeAll()
    }
    
    // MARK: - Error Handling
    
    /// Present an error to the user
    func presentError(_ error: Error, title: String = "Error") {
        self.error = error
        self.alertTitle = title
    }
    
    /// Clear any current error
    func clearError() {
        self.error = nil
        self.showAlert = false
    }
    
    // MARK: - Loading State
    
    /// Execute an async operation with loading state
    @MainActor
    func withLoading<T>(_ operation: @escaping () async throws -> T) async rethrows -> T {
        isLoading = true
        clearError()
        
        do {
            let result = try await operation()
            isLoading = false
            return result
        } catch {
            isLoading = false
            presentError(error)
            throw error
        }
    }
    
    /// Execute an async operation that returns Void
    @MainActor
    func withLoading(_ operation: @escaping () async throws -> Void) async rethrows {
        isLoading = true
        clearError()
        
        do {
            try await operation()
            isLoading = false
        } catch {
            isLoading = false
            presentError(error)
            throw error
        }
    }
}
```

### 1.2 ViewModel Protocol

```swift
// ViewModelProtocol.swift
import Combine

/// Protocol defining the interface for all ViewModels
protocol ViewModelProtocol: ObservableObject {
    associatedtype Input
    associatedtype Output
    
    /// Transform input into output
    func transform(input: Input) -> Output
}

/// Default empty implementation
extension ViewModelProtocol {
    func transform(input: Input) -> Output {
        fatalError("transform(input:) must be implemented")
    }
}
```

### 1.3 ListViewModel (Base for List Views)

```swift
// ListViewModel.swift
import Combine

/// Base class for ViewModels that manage a list of items
class ListViewModel<Item: Identifiable & Hashable>: BaseViewModel {
    
    // MARK: - State
    
    @Published var items: [Item] = []
    @Published var filteredItems: [Item] = []
    @Published var searchText = ""
    @Published var filter: FilterType<Item> = .none
    @Published var sortOrder: SortOrder<Item> = .none
    
    // MARK: - Filtering
    
    enum FilterType<Item> {
        case none
        case custom((Item) -> Bool)
    }
    
    enum SortOrder<Item> {
        case none
        case ascending(keyPath: KeyPath<Item, some Comparable>)
        case descending(keyPath: KeyPath<Item, some Comparable>)
    }
    
    // MARK: - Lifecycle
    
    override func bind() {
        super.bind()
        
        // Bind search and filter to filtered items
        Publishers.CombineLatest($items, $searchText)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .map { [weak self] items, searchText in
                self?.applyFilterAndSearch(items: items, searchText: searchText)
            }
            .assign(to: \.filteredItems, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Filtering
    
    private func applyFilterAndSearch(items: [Item], searchText: String) -> [Item] {
        var result = items
        
        // Apply filter
        if case .custom(let predicate) = filter {
            result = result.filter(predicate)
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter { item in
                // Try to find a string representation
                if let name = (item as? Any) as? String {
                    return name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .ascending(let keyPath):
            result.sort { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
        case .descending(let keyPath):
            result.sort { $0[keyPath: keyPath] > $1[keyPath: keyPath] }
        case .none:
            break
        }
        
        return result
    }
    
    // MARK: - CRUD Operations
    
    func append(_ item: Item) {
        items.append(item)
    }
    
    func insert(_ item: Item, at index: Int) {
        items.insert(item, at: index)
    }
    
    func remove(at index: Int) {
        items.remove(at: index)
    }
    
    func remove(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            remove(at: index)
        }
    }
    
    func update(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
    
    func replaceAll(with newItems: [Item]) {
        items = newItems
    }
}
```

## 2. Protocols

### 2.1 Identifiable Models

```swift
// IdentifiableModel.swift
import Foundation

/// Protocol for models that have a unique identifier
protocol IdentifiableModel: Identifiable, Hashable {
    var id: UUID { get }
}

/// Protocol for models that can be created from a Decodable type
protocol DecodableModel: Decodable, IdentifiableModel {}

/// Protocol for models that can be encoded to Data
protocol EncodableModel: Encodable, IdentifiableModel {}

/// Combined protocol for models that are both Decodable and Encodable
protocol CodableModel: CodableModel, DecodableModel, EncodableModel {}
```

### 2.2 Repository Protocols

```swift
// RepositoryProtocols.swift
import Foundation

/// Base repository protocol
protocol RepositoryProtocol {
    associatedtype Model: IdentifiableModel
    
    func getAll() async throws -> [Model]
    func get(byId id: UUID) async throws -> Model?
    func create(_ model: Model) async throws
    func update(_ model: Model) async throws
    func delete(_ model: Model) async throws
}

/// Paginated repository protocol
protocol PaginatedRepositoryProtocol: RepositoryProtocol {
    func getPaginated(page: Int, pageSize: Int) async throws -> PaginatedResult<Model>
}

struct PaginatedResult<T> {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}

/// Queryable repository protocol
protocol QueryableRepositoryProtocol: RepositoryProtocol {
    func query(predicate: NSPredicate) async throws -> [Model]
    func query(sortDescriptors: [NSSortDescriptor]) async throws -> [Model]
    func query(predicate: NSPredicate, sortDescriptors: [NSSortDescriptor]) async throws -> [Model]
}
```

### 2.3 Service Protocols

```swift
// ServiceProtocols.swift
import Foundation

/// Base service protocol
protocol ServiceProtocol {
    // Marker protocol
}

/// Notification service protocol
protocol NotificationServiceProtocol: ServiceProtocol {
    func requestAuthorization() async throws
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger
    ) async throws
    func cancelNotification(id: String) async
    func cancelAllNotifications() async
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
}

/// Reminder service protocol
protocol ReminderServiceProtocol: ServiceProtocol {
    func scheduleReminder(for tracker: Tracker) async throws
    func cancelReminder(for tracker: Tracker) async
    func updateReminder(for tracker: Tracker) async throws
    func getNextReminderDate(for tracker: Tracker) -> Date?
}

/// Date service protocol (for testing)
protocol DateServiceProtocol: ServiceProtocol {
    var currentDate: Date { get }
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool
    func startOfDay(for date: Date) -> Date
    func endOfDay(for date: Date) -> Date
    func date(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date?
    func dateComponents(_ components: Set<Calendar.Component>, from date: Date) -> DateComponents
    func isDate(_ date: Date, inSameDayAs other: Date) -> Bool
}

/// Analytics service protocol
protocol AnalyticsServiceProtocol: ServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent)
    func trackScreenView(_ screen: AnalyticsScreen)
    func trackTrackerCompletion(type: TrackerType)
    func trackTrackerCreation(type: TrackerType)
}

/// Settings service protocol
protocol SettingsServiceProtocol: ServiceProtocol {
    var settings: AppSettings { get set }
    func saveSettings(_ settings: AppSettings) async throws
    func loadSettings() async throws -> AppSettings
}
```

### 2.4 Use Case Protocols

```swift
// UseCaseProtocols.swift
import Foundation

/// Base use case protocol
protocol UseCaseProtocol {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) async throws -> Output
}

/// Use case with no input
protocol NoInputUseCaseProtocol: UseCaseProtocol {
    associatedtype Output
    
    func execute() async throws -> Output
}

/// Use case with no output (returns Void)
protocol NoOutputUseCaseProtocol: UseCaseProtocol {
    associatedtype Input
    
    func execute(_ input: Input) async throws
}

/// Use case with no input and no output
protocol NoIOUseCaseProtocol: UseCaseProtocol {
    func execute() async throws
}

/// Default implementations
extension NoInputUseCaseProtocol {
    func execute() async throws -> Output {
        try await execute(() as! Input)
    }
}

extension NoOutputUseCaseProtocol {
    func execute(_ input: Input) async throws {
        _ = try await execute(input: input)
    }
}

extension NoIOUseCaseProtocol where Input == Void, Output == Void {
    func execute() async throws {
        try await execute(()) 
    }
    
    func execute(_ input: Input) async throws -> Output {
        try await execute()
        return ()
    }
}
```

## 3. Extensions

### 3.1 Date Extensions

```swift
// Date+Extensions.swift
import Foundation

exension Date {
    
    // MARK: - Components
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
    
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }
    
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }
    
    var second: Int {
        Calendar.current.component(.second, from: self)
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    var weekOfYear: Int {
        Calendar.current.component(.weekOfYear, from: self)
    }
    
    // MARK: - Date Ranges
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }
    
    var endOfWeek: Date {
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek)!
    }
    
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
    
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    // MARK: - Comparisons
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isSameWeek(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .weekOfYear)
    }
    
    func isSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    func isSameYear(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .year)
    }
    
    // MARK: - Formatting
    
    func formatted(with format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    func formattedMedium() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formattedShort() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func formattedRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // MARK: - Time Intervals
    
    func timeIntervalSince(_ date: Date) -> TimeInterval {
        self.timeIntervalSince(date)
    }
    
    func daysSince(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: date, to: self)
        return components.day ?? 0
    }
    
    func hoursSince(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour], from: date, to: self)
        return components.hour ?? 0
    }
    
    // MARK: - Manipulation
    
    func adding(days: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: days, to: self)
    }
    
    func adding(weeks: Int) -> Date? {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self)
    }
    
    func adding(months: Int) -> Date? {
        Calendar.current.date(byAdding: .month, value: months, to: self)
    }
    
    func adding(years: Int) -> Date? {
        Calendar.current.date(byAdding: .year, value: years, to: self)
    }
    
    // MARK: - Static
    
    static var now: Date {
        Date()
    }
    
    static var today: Date {
        Date().startOfDay
    }
    
    static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date().startOfDay)!
    }
    
    static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay)!
    }
}
```

### 3.2 Calendar Extensions

```swift
// Calendar+Extensions.swift
import Foundation

exension Calendar {
    
    static var current: Calendar {
        var calendar = Calendar.current
        // Configure based on user settings
        return calendar
    }
    
    /// Get the first day of the week based on user's week start preference
    func startOfWeek(for date: Date, weekStartDay: DayOfWeek) -> Date {
        let currentWeekday = component(.weekday, from: date)
        let daysToSubtract = (currentWeekday - weekStartDay.rawValue + 7) % 7
        return self.date(byAdding: .day, value: -daysToSubtract, to: date)!
    }
    
    /// Generate all dates in a week
    func datesInWeek(for date: Date, weekStartDay: DayOfWeek) -> [Date] {
        let startOfWeek = self.startOfWeek(for: date, weekStartDay: weekStartDay)
        return (0..<7).compactMap { day in
            self.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
    
    /// Generate all dates in a month
    func datesInMonth(for date: Date) -> [Date] {
        let startOfMonth = self.startOfMonth(for: date)
        let endOfMonth = self.endOfMonth(for: date)
        
        var dates: [Date] = []
        var currentDate = startOfMonth
        
        while currentDate <= endOfMonth {
            dates.append(currentDate)
            currentDate = self.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    /// Get the number of days in a month
    func numberOfDaysInMonth(for date: Date) -> Int {
        let range = self.range(of: .day, in: .month, for: date)!
        return range.count
    }
    
    /// Check if a date is today
    func isDateInToday(_ date: Date) -> Bool {
        self.isDate(date, inSameDayAs: Date())
    }
    
    /// Get weekday symbols based on week start day
    func weekdaySymbols(weekStartDay: DayOfWeek) -> [String] {
        let symbols = self.weekdaySymbols
        let startIndex = weekStartDay.rawValue - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
    
    /// Get short weekday symbols based on week start day
    func shortWeekdaySymbols(weekStartDay: DayOfWeek) -> [String] {
        let symbols = self.shortWeekdaySymbols
        let startIndex = weekStartDay.rawValue - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
}
```

### 3.3 Color Extensions

```swift
// Color+Extensions.swift
import SwiftUI

exension Color {
    
    // MARK: - Semantic Colors
    
    static let primary = Color("AccentColor")
    static let secondary = Color("SecondaryColor")
    static let background = Color("BackgroundColor")
    static let surface = Color("SurfaceColor")
    static let error = Color("ErrorColor")
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    static let info = Color("InfoColor")
    
    // MARK: - Tracker Type Colors
    
    static let streak = Color("StreakColor")
    static let negativeStreak = Color("NegativeStreakColor")
    static let timeSince = Color("TimeSinceColor")
    static let timeAhead = Color("TimeAheadColor")
    static let counter = Color("CounterColor")
    
    // MARK: - Status Colors
    
    static let completed = Color.green
    static let incomplete = Color.red
    static let inProgress = Color.orange
    
    // MARK: - Initializers
    
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
    
    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    // MARK: - Computed Properties
    
    var components: (red: Double, green: Double, blue: Double, opacity: Double)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o) else {
            return nil
        }
        
        return (Double(r), Double(g), Double(b), Double(o))
    }
    
    var inverted: Color {
        guard let components = components else { return .white }
        return Color(
            red: 1.0 - components.red,
            green: 1.0 - components.green,
            blue: 1.0 - components.blue,
            opacity: components.opacity
        )
    }
    
    var lightened: Color {
        guard let components = components else { return .white }
        return Color(
            red: min(components.red * 1.2, 1.0),
            green: min(components.green * 1.2, 1.0),
            blue: min(components.blue * 1.2, 1.0),
            opacity: components.opacity
        )
    }
    
    var darkened: Color {
        guard let components = components else { return .black }
        return Color(
            red: max(components.red * 0.8, 0.0),
            green: max(components.green * 0.8, 0.0),
            blue: max(components.blue * 0.8, 0.0),
            opacity: components.opacity
        )
    }
    
    // MARK: - Gradients
    
    static func gradient(
        from fromColor: Color,
        to toColor: Color,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [fromColor, toColor]),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    static var primaryGradient: LinearGradient {
        gradient(from: .primary, to: .secondary)
    }
}
```

### 3.4 View Extensions

```swift
// View+Extensions.swift
import SwiftUI

exension View {
    
    // MARK: - Conditional Modifiers
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func ifLet<Content: View, Value>(_ value: Value?, transform: (Self, Value) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
    
    // MARK: - Frame
    
    func squareFrame(size: CGFloat) -> some View {
        frame(width: size, height: size)
    }
    
    func aspectRatio(_ ratio: CGFloat) -> some View {
        aspectRatio(ratio, contentMode: .fit)
    }
    
    // MARK: - Alignment
    
    func centerHorizontally() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
    
    func centerVertically() -> some View {
        VStack {
            Spacer()
            self
            Spacer()
        }
    }
    
    func center() -> some View {
        centerHorizontally().centerVertically()
    }
    
    // MARK: - Background
    
    func backgroundIf<T: View>(_ condition: Bool, background: T) -> some View {
        background(condition ? background : nil)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // MARK: - Shadows
    
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    func buttonShadow() -> some View {
        shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Animations
    
    func pressAnimation(scale: CGFloat = 0.95) -> some View {
        buttonStyle(PressAnimationStyle(scale: scale))
    }
    
    func fadeInAnimation(duration: Double = 0.3, delay: Double = 0) -> some View {
        modifier(FadeInModifier(duration: duration, delay: delay))
    }
    
    func slideInAnimation(
        from edge: Edge = .top,
        duration: Double = 0.3,
        delay: Double = 0
    ) -> some View {
        modifier(SlideInModifier(edge: edge, duration: duration, delay: delay))
    }
    
    // MARK: - Overlays
    
    func loadingOverlay(isLoading: Bool, color: Color = .primary) -> some View {
        overlay {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: color))
                    .scaleEffect(1.5)
            }
        }
    }
    
    func emptyStateOverlay<Content: View>(
        isEmpty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        overlay {
            if isEmpty {
                content()
            }
        }
    }
    
    // MARK: - Geometry
    
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
    
    // MARK: - Scroll
    
    func refreshable(action: @escaping () async -> Void) -> some View {
        modifier(RefreshableModifier(action: action))
    }
    
    // MARK: - Accessibility
    
    func accessibilityHint(_ hint: String) -> some View {
        accessibilityHint(hint)
    }
    
    func accessibilityValue(_ value: String) -> some View {
        accessibilityValue(value)
    }
}

// MARK: - Supporting Types

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct PressAnimationStyle: ButtonStyle {
    var scale: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct FadeInModifier: ViewModifier {
    var duration: Double
    var delay: Double
    
    @State private var show = false
    
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    show = true
                }
            }
    }
}

struct SlideInModifier: ViewModifier {
    var edge: Edge
    var duration: Double
    var delay: Double
    
    @State private var show = false
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    show = true
                }
            }
    }
    
    private var offset: CGSize {
        switch edge {
        case .top: return CGSize(width: 0, height: show ? 0 : -1000)
        case .bottom: return CGSize(width: 0, height: show ? 0 : 1000)
        case .leading: return CGSize(width: show ? 0 : -1000, height: 0)
        case .trailing: return CGSize(width: show ? 0 : 1000, height: 0)
        @unknown default: return .zero
        }
    }
}

struct RefreshableModifier: ViewModifier {
    var action: () async -> Void
    
    @State private var isRefreshing = false
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                isRefreshing = true
                await action()
                isRefreshing = false
            }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
```

### 3.5 Binding Extensions

```swift
// Binding+Extensions.swift
import SwiftUI

exension Binding {
    
    /// Create a binding to a key path of the base value
    subscript<T>(_ keyPath: WrappedKeyPath<T, Value>) -> Binding<T> {
        Binding<T>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
    
    /// Create a binding with a default value
    static func constant<T>(_ value: T) -> Binding<T> {
        Binding<T>(
            get: { value },
            set: { _ in }
        )
    }
    
    /// Create a binding that transforms the value
    func map<T>(_ transform: @escaping (Value) -> T, _ reverse: @escaping (T) -> Value) -> Binding<T> {
        Binding<T>(
            get: { transform(self.wrappedValue) },
            set: { self.wrappedValue = reverse($0) }
        )
    }
    
    /// Create a binding with a nil-coalescing default
    func orDefault(_ defaultValue: Value) -> Binding<Value> {
        Binding<Value>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
    
    /// Create a binding that only sets when the new value is different
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding<Value>(
            get: { self.wrappedValue },
            set: { newValue in
                if self.wrappedValue != newValue {
                    self.wrappedValue = newValue
                    handler(newValue)
                }
            }
        )
    }
}

exension Binding where Value == Bool {
    
    /// Negates the boolean binding
    var negated: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
    
    /// Creates a binding that toggles when set
    func toggle() -> Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue },
            set: { _ in self.wrappedValue.toggle() }
        )
    }
}

exension Binding where Value: Equatable {
    
    /// Creates a binding that only updates when the value changes
    func debounced(duration: Double) -> Binding<Value> {
        var lastValue: Value? = nil
        
        return Binding<Value>(
            get: { self.wrappedValue },
            set: { newValue in
                if lastValue != newValue {
                    lastValue = newValue
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self.wrappedValue = newValue
                    }
                }
            }
        )
    }
}
```

## 4. Utility Classes

### 4.1 WeakReference

```swift
// WeakReference.swift
import Foundation

/// Wrapper for weak references to class instances
final class WeakReference<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T? = nil) {
        self.value = value
    }
}

/// Collection of weak references
final class WeakCollection<T: AnyObject> {
    private var references: [WeakReference<T>] = []
    
    var all: [T] {
        references.compactMap { $0.value }
    }
    
    func add(_ value: T) {
        cleanup()
        references.append(WeakReference(value))
    }
    
    func remove(_ value: T) {
        references.removeAll { $0.value === value }
    }
    
    private func cleanup() {
        references = references.filter { $0.value != nil }
    }
}
```

### 4.2 Debouncer

```swift
// Debouncer.swift
import Foundation

/// Utility for debouncing operations
final class Debouncer {
    private let queue: DispatchQueue
    private let delay: TimeInterval
    private var timer: DispatchSourceTimer?
    private var handler: (() -> Void)?
    
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    func debounce(handler: @escaping () -> Void) {
        self.handler = handler
        timer?.cancel()
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + delay)
        timer?.setEventHandler { [weak self] in
            self?.handler?()
            self?.handler = nil
        }
        timer?.resume()
    }
    
    deinit {
        timer?.cancel()
    }
}
```

### 4.3 Throttler

```swift
// Throttler.swift
import Foundation

/// Utility for throttling operations
final class Throttler {
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private var lastExecution: Date = .distantPast
    private var timer: DispatchSourceTimer?
    private var handler: (() -> Void)?
    
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    func throttle(handler: @escaping () -> Void) {
        self.handler = handler
        
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastExecution)
        
        if timeSinceLast >= interval {
            lastExecution = now
            handler()
        } else {
            timer?.cancel()
            
            let delay = interval - timeSinceLast
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.schedule(deadline: .now() + delay)
            timer?.setEventHandler { [weak self] in
                self?.lastExecution = Date()
                self?.handler?()
                self?.handler = nil
            }
            timer?.resume()
        }
    }
    
    deinit {
        timer?.cancel()
    }
}
```

### 4.4 Logger

```swift
// Logger.swift
import os.log

/// Unified logging utility
final class Logger {
    
    static let shared = Logger()
    
    private let log: OSLog
    
    private init() {
        log = OSLog(subsystem: "com.arvoldek.TrackIt", category: "App")
    }
    
    // MARK: - Log Levels
    
    enum Level: String {
        case debug
        case info
        case warning
        case error
        case fault
    }
    
    // MARK: - Logging Methods
    
    func log(_ level: Level, message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        #if DEBUG
        let messageWithArgs = String(format: message, arguments: args)
        
        switch level {
        case .debug:
            os_log("%{private}@", log: log, type: .debug, messageWithArgs)
        case .info:
            os_log("%{private}@", log: log, type: .info, messageWithArgs)
        case .warning:
            os_log("%{private}@", log: log, type: .default, messageWithArgs)
        case .error:
            os_log("%{private}@", log: log, type: .error, messageWithArgs)
        case .fault:
            os_log("%{private}@", log: log, type: .fault, messageWithArgs)
        }
        #endif
    }
    
    func debug(_ message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        log(.debug, message: message, privacy: privacy, args)
    }
    
    func info(_ message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        log(.info, message: message, privacy: privacy, args)
    }
    
    func warning(_ message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        log(.warning, message: message, privacy: privacy, args)
    }
    
    func error(_ message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        log(.error, message: message, privacy: privacy, args)
    }
    
    func fault(_ message: String, privacy: OSLogPrivacy = .auto, _ args: Any...) {
        log(.fault, message: message, privacy: privacy, args)
    }
    
    // MARK: - Convenience Methods
    
    func logError(_ error: Error) {
        #if DEBUG
        error("Error: %{private}@", error.localizedDescription)
        #endif
    }
}

// Usage examples:
// Logger.shared.debug("Loading trackers...")
// Logger.shared.info("Loaded %d trackers", trackers.count)
// Logger.shared.error("Failed to load: %{private}@", error.localizedDescription)
```

## 5. Delivery Checklist

- [ ] BaseViewModel created with common functionality
- [ ] ListViewModel created for list management
- [ ] All necessary protocols defined
- [ ] Date extensions implemented
- [ ] Calendar extensions implemented
- [ ] Color extensions implemented
- [ ] View extensions implemented
- [ ] Binding extensions implemented
- [ ] Utility classes created (WeakReference, Debouncer, Throttler, Logger)
- [ ] All extensions documented

---

**Duration**: 1 day
**Priority**: Critical
**Next**: Proceed to [Phase 2: Core Infrastructure](../02-phase-core-infrastructure/01-core-data-stack.md)
