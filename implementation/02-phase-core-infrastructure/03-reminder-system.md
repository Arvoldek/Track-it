# Phase 2: Reminder System

## Overview

This document details the implementation of the reminder system for the Track It application, including local notifications, calendar integration, and reminder management for trackers.

## 1. Reminder System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    REMINDER SYSTEM                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  ReminderServiceProtocol                                 │  │
│  │  - LocalReminderService (default)                       │  │
│  │  - CalendarReminderService (optional)                   │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  NotificationServiceProtocol                            │  │
│  │  - UserNotificationService (UNUserNotificationCenter)  │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Reminder Scheduler                                      │  │
│  │  - Schedules reminders based on tracker settings        │  │
│  │  - Handles repeat intervals (daily, weekly)             │  │
│  │  - Manages notification IDs                            │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    iOS NOTIFICATION SYSTEM                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  UNUserNotificationCenter                               │  │
│  │  - Local notifications                                  │  │
│  │  - Notification categories                              │  │
│  │  - Notification actions                                 │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 2. Notification Service

### 2.1 NotificationServiceProtocol

```swift
// NotificationServiceProtocol.swift
import UserNotifications

protocol NotificationServiceProtocol {
    /// Request notification permission
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    
    /// Check current notification authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus
    
    /// Schedule a local notification
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger,
        sound: UNNotificationSound?,
        badge: Int?,
        userInfo: [AnyHashable: Any]?
    ) async throws
    
    /// Schedule multiple local notifications
    func scheduleLocalNotifications(_ requests: [UNNotificationRequest]) async throws
    
    /// Get all pending notification requests
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
    
    /// Get all delivered notifications
    func getDeliveredNotifications() async -> [UNNotification]
    
    /// Remove a specific notification by ID
    func removeNotification(id: String) async
    
    /// Remove all pending notifications
    func removeAllPendingNotifications() async
    
    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() async
    
    /// Remove notifications with specific IDs
    func removeNotifications(withIds ids: [String]) async
    
    /// Notification categories
    var notificationCategories: Set<UNNotificationCategory> { get }
}
```

### 2.2 UserNotificationService Implementation

```swift
// UserNotificationService.swift
import UserNotifications

final class UserNotificationService: NotificationServiceProtocol, NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = UserNotificationService()
    
    private let notificationCenter: UNUserNotificationCenter
    
    // MARK: - Initialization
    
    override init() {
        notificationCenter = UNUserNotificationCenter.current()
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .sound, .badge]) async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization(options: options)
        
        if granted {
            Logger.shared.info("Notification authorization granted")
        } else {
            Logger.shared.warning("Notification authorization denied")
        }
        
        return granted
    }
    
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }
    
    // MARK: - Scheduling
    
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger,
        sound: UNNotificationSound? = nil,
        badge: Int? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ?? .default
        content.badge = badge as NSNumber?
        content.userInfo = userInfo ?? [:]
        content.categoryIdentifier = NotificationCategory.trackerReminder.rawValue
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        Logger.shared.debug("Scheduled notification with id: \(id)")
    }
    
    func scheduleLocalNotifications(_ requests: [UNNotificationRequest]) async throws {
        try await notificationCenter.add(requests)
        Logger.shared.debug("Scheduled \(requests.count) notifications")
    }
    
    // MARK: - Retrieval
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        await notificationCenter.deliveredNotifications()
    }
    
    // MARK: - Removal
    
    func removeNotification(id: String) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
        Logger.shared.debug("Removed notification with id: \(id)")
    }
    
    func removeAllPendingNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        Logger.shared.debug("Removed all pending notifications")
    }
    
    func removeAllDeliveredNotifications() async {
        notificationCenter.removeAllDeliveredNotifications()
        Logger.shared.debug("Removed all delivered notifications")
    }
    
    func removeNotifications(withIds ids: [String]) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
        Logger.shared.debug("Removed notifications with ids: \(ids)")
    }
    
    // MARK: - Categories
    
    lazy var notificationCategories: Set<UNNotificationCategory> = {
        var categories: Set<UNNotificationCategory> = []
        
        // Tracker reminder category
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.complete.rawValue,
            title: "Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze 10 min",
            options: []
        )
        
        let trackerCategory = UNNotificationCategory(
            identifier: NotificationCategory.trackerReminder.rawValue,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Tracker reminder",
            options: [.customDismissAction]
        )
        
        categories.insert(trackerCategory)
        
        // Time since reminder category
        let resetAction = UNNotificationAction(
            identifier: NotificationAction.reset.rawValue,
            title: "Reset Counter",
            options: [.foreground, .destructive]
        )
        
        let timeSinceCategory = UNNotificationCategory(
            identifier: NotificationCategory.timeSinceReminder.rawValue,
            actions: [resetAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Time since reminder",
            options: [.customDismissAction]
        )
        
        categories.insert(timeSinceCategory)
        
        // Time ahead reminder category
        let timeAheadCategory = UNNotificationCategory(
            identifier: NotificationCategory.timeAheadReminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Time ahead reminder",
            options: [.customDismissAction]
        )
        
        categories.insert(timeAheadCategory)
        
        return categories
    }()
    
    // MARK: - Setup
    
    func setupNotificationCategories() {
        notificationCenter.setNotificationCategories(Array(notificationCategories))
        Logger.shared.info("Notification categories set up")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Called when a notification is about to be presented
        // We want to show notifications even when the app is in foreground
        
        // Check if the app is in foreground
        if UIApplication.shared.applicationState == .active {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.banner, .sound, .badge, .list])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Called when user interacts with a notification
        
        Logger.shared.debug("User interacted with notification: \(response.notification.request.identifier)")
        
        // Handle the action
        handleNotificationResponse(response)
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        // Called when user taps "Settings" in notification banner
        Logger.shared.debug("User tapped settings for notification")
    }
    
    // MARK: - Response Handling
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let action = NotificationAction(rawValue: response.actionIdentifier) else {
            Logger.shared.warning("Unknown notification action: \(response.actionIdentifier)")
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        
        // Extract tracker ID from userInfo
        guard let trackerIdString = userInfo["trackerId"] as? String,
              let trackerId = UUID(uuidString: trackerIdString) else {
            Logger.shared.warning("No tracker ID in notification userInfo")
            return
        }
        
        Logger.shared.info("Handling action \(action) for tracker \(trackerId)")
        
        switch action {
        case .complete:
            handleCompleteAction(trackerId: trackerId)
        case .snooze:
            handleSnoozeAction(trackerId: trackerId, response: response)
        case .reset:
            handleResetAction(trackerId: trackerId)
        case .dismiss:
            // Notification was dismissed
            Logger.shared.debug("Notification dismissed for tracker \(trackerId)")
        }
    }
    
    private func handleCompleteAction(trackerId: UUID) {
        // Notify the app to complete the tracker
        NotificationCenter.default.post(
            name: .completeTrackerNotification,
            object: nil,
            userInfo: ["trackerId": trackerId.uuidString]
        )
    }
    
    private func handleSnoozeAction(trackerId: UUID, response: UNNotificationResponse) {
        // Calculate new fire date (10 minutes from now)
        let newFireDate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        
        // Create new trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: newFireDate
            ),
            repeats: false
        )
        
        // Reschedule the notification
        Task {
            let userInfo = response.notification.request.content.userInfo
            let title = response.notification.request.content.title
            let body = response.notification.request.content.body
            
            try await scheduleLocalNotification(
                id: "snooze_\(UUID())",
                title: title,
                body: body,
                trigger: trigger,
                userInfo: userInfo
            )
        }
    }
    
    private func handleResetAction(trackerId: UUID) {
        // Notify the app to reset the time since tracker
        NotificationCenter.default.post(
            name: .resetTimeSinceTrackerNotification,
            object: nil,
            userInfo: ["trackerId": trackerId.uuidString]
        )
    }
}

// Notification Category and Action Enums

enum NotificationCategory: String {
    case trackerReminder = "trackerReminder"
    case timeSinceReminder = "timeSinceReminder"
    case timeAheadReminder = "timeAheadReminder"
    case counterReminder = "counterReminder"
}

enum NotificationAction: String {
    case complete = "complete"
    case snooze = "snooze"
    case reset = "reset"
    case dismiss = "dismiss"
}

// Notification Center Extensions

extension Notification.Name {
    static let completeTrackerNotification = Notification.Name("CompleteTrackerNotification")
    static let resetTimeSinceTrackerNotification = Notification.Name("ResetTimeSinceTrackerNotification")
    static let reminderFiredNotification = Notification.Name("ReminderFiredNotification")
}
```

## 3. Reminder Service

### 3.1 ReminderServiceProtocol

```swift
// ReminderServiceProtocol.swift
import Foundation

protocol ReminderServiceProtocol {
    /// Schedule a reminder for a tracker
    func scheduleReminder(for tracker: Tracker) async throws
    
    /// Cancel the reminder for a tracker
    func cancelReminder(for tracker: Tracker) async
    
    /// Update the reminder for a tracker
    func updateReminder(for tracker: Tracker) async throws
    
    /// Get the next reminder date for a tracker
    func getNextReminderDate(for tracker: Tracker) -> Date?
    
    /// Cancel all reminders
    func cancelAllReminders() async
    
    /// Check if a reminder is scheduled for a tracker
    func hasReminder(for tracker: Tracker) async -> Bool
    
    /// Get all scheduled reminders
    func getAllScheduledReminders() async -> [Tracker]
}
```

### 3.2 LocalReminderService Implementation

```swift
// LocalReminderService.swift
import Foundation
import UserNotifications

final class LocalReminderService: ReminderServiceProtocol {
    
    private let notificationService: NotificationServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let trackerRepository: TrackerRepositoryProtocol
    
    private var notificationIds: [UUID: String] = [:]
    
    // MARK: - Initialization
    
    init(
        notificationService: NotificationServiceProtocol = UserNotificationService.shared,
        settingsRepository: SettingsRepositoryProtocol,
        trackerRepository: TrackerRepositoryProtocol
    ) {
        self.notificationService = notificationService
        self.settingsRepository = settingsRepository
        self.trackerRepository = trackerRepository
        
        // Setup notification categories
        if let userNotificationService = notificationService as? UserNotificationService {
            userNotificationService.setupNotificationCategories()
        }
        
        // Load existing notification IDs
        loadNotificationIds()
    }
    
    // MARK: - Reminder Management
    
    func scheduleReminder(for tracker: Tracker) async throws {
        guard let reminder = tracker.reminder, reminder.isEnabled else {
            return
        }
        
        // Cancel existing reminder first
        await cancelReminder(for: tracker)
        
        // Calculate next fire date
        guard let nextDate = calculateNextFireDate(for: reminder) else {
            Logger.shared.warning("Could not calculate next fire date for reminder")
            return
        }
        
        // Create notification ID
        let notificationId = "tracker_\(tracker.id.uuidString)"
        notificationIds[tracker.id] = notificationId
        saveNotificationIds()
        
        // Create trigger
        let trigger = createTrigger(for: reminder, fireDate: nextDate)
        
        // Create notification content
        let (title, body) = createNotificationContent(for: tracker)
        
        // Create user info
        let userInfo: [AnyHashable: Any] = [
            "trackerId": tracker.id.uuidString,
            "trackerType": tracker.type.rawValue,
            "trackerName": tracker.name
        ]
        
        // Schedule notification
        try await notificationService.scheduleLocalNotification(
            id: notificationId,
            title: title,
            body: body,
            trigger: trigger,
            userInfo: userInfo
        )
        
        Logger.shared.debug("Scheduled reminder for tracker \(tracker.id) at \(nextDate)")
    }
    
    func cancelReminder(for tracker: Tracker) async {
        guard let notificationId = notificationIds[tracker.id] else {
            return
        }
        
        await notificationService.removeNotification(id: notificationId)
        notificationIds.removeValue(forKey: tracker.id)
        saveNotificationIds()
        
        Logger.shared.debug("Cancelled reminder for tracker \(tracker.id)")
    }
    
    func updateReminder(for tracker: Tracker) async throws {
        // This is essentially cancel and reschedule
        await cancelReminder(for: tracker)
        try await scheduleReminder(for: tracker)
    }
    
    func getNextReminderDate(for tracker: Tracker) -> Date? {
        guard let reminder = tracker.reminder, reminder.isEnabled else {
            return nil
        }
        
        return calculateNextFireDate(for: reminder)
    }
    
    func cancelAllReminders() async {
        // Cancel all notifications
        await notificationService.removeAllPendingNotifications()
        
        // Clear notification IDs
        notificationIds.removeAll()
        saveNotificationIds()
        
        Logger.shared.debug("Cancelled all reminders")
    }
    
    func hasReminder(for tracker: Tracker) async -> Bool {
        notificationIds[tracker.id] != nil
    }
    
    func getAllScheduledReminders() async -> [Tracker] {
        let allTrackers = try? await trackerRepository.getAllTrackers()
        
        return allTrackers?.filter { tracker in
            Task {
                await hasReminder(for: tracker)
            }.result ?? false
        } ?? []
    }
    
    // MARK: - Private Helpers
    
    private func calculateNextFireDate(for reminder: Reminder) -> Date? {
        let calendar = Calendar.current
        
        // Get the time components from the reminder time
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: reminder.time)
        
        // Get today's date components
        let today = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        
        // Set the time
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        // Create the base date
        guard let baseDate = calendar.date(from: components) else {
            return nil
        }
        
        switch reminder.repeatInterval {
        case .once:
            // Only fire once at the specified time
            return baseDate > today ? baseDate : nil
            
        case .daily:
            // Fire every day at the same time
            if baseDate > today {
                return baseDate
            }
            
            // Next day
            components.day! += 1
            return calendar.date(from: components)
            
        case .weekly:
            // Fire on selected days of the week
            let currentWeekday = DayOfWeek.fromDate(today)
            
            // Check if we can fire today
            if reminder.daysOfWeek.contains(currentWeekday) {
                if baseDate > today {
                    return baseDate
                }
            }
            
            // Find the next valid day
            let allDays = DayOfWeek.allCases.sorted { $0.rawValue < $1.rawValue }
            let currentIndex = allDays.firstIndex(of: currentWeekday) ?? 0
            
            for i in 1...7 {
                let index = (currentIndex + i) % allDays.count
                let nextDay = allDays[index]
                
                if reminder.daysOfWeek.contains(nextDay) {
                    components.day! += i
                    if let date = calendar.date(from: components) {
                        return date
                    }
                }
            }
            
            return nil
        }
    }
    
    private func createTrigger(for reminder: Reminder, fireDate: Date) -> UNNotificationTrigger {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        
        switch reminder.repeatInterval {
        case .once:
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .daily:
            // Repeat every day at the same time
            return UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.hour, .minute, .second], from: fireDate),
                repeats: true
            )
        case .weekly:
            // Repeat weekly on selected days
            return UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
        }
    }
    
    private func createNotificationContent(for tracker: Tracker) -> (title: String, body: String) {
        let trackerName = tracker.name
        
        switch tracker.type {
        case .streak:
            return (
                "Streak Reminder",
                "Don't forget to complete your streak: \(trackerName)"
            )
        case .negativeStreak:
            return (
                "Negative Streak Reminder",
                "Remember to avoid: \(trackerName)"
            )
        case .timeSince:
            return (
                "Time Since Reminder",
                "Time since \(trackerName): \(tracker.timeSinceFormatted)"
            )
        case .timeAhead:
            return (
                "Countdown Reminder",
                "Time until \(trackerName): \(tracker.timeAheadFormatted)"
            )
        case .counter:
            return (
                "Counter Reminder",
                "Don't forget to update your counter: \(trackerName)"
            )
        }
    }
    
    // MARK: - Notification ID Persistence
    
    private func saveNotificationIds() {
        do {
            let data = try JSONEncoder().encode(notificationIds)
            UserDefaults.standard.set(data, forKey: "reminderNotificationIds")
        } catch {
            Logger.shared.error("Failed to save notification IDs: %{private}@", error.localizedDescription)
        }
    }
    
    private func loadNotificationIds() {
        guard let data = UserDefaults.standard.data(forKey: "reminderNotificationIds") else {
            return
        }
        
        do {
            notificationIds = try JSONDecoder().decode([UUID: String].self, from: data)
        } catch {
            Logger.shared.error("Failed to load notification IDs: %{private}@", error.localizedDescription)
        }
    }
}
```

## 4. Reminder Scheduling

### 4.1 ReminderScheduler

```swift
// ReminderScheduler.swift
import Foundation

/// Schedules and manages reminders for all trackers
final class ReminderScheduler {
    
    static let shared = ReminderScheduler()
    
    private let reminderService: ReminderServiceProtocol
    private let trackerRepository: TrackerRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    
    private var scheduledTrackerIds: Set<UUID> = []
    
    // MARK: - Initialization
    
    init(
        reminderService: ReminderServiceProtocol = DependencyContainer.shared.reminderService,
        trackerRepository: TrackerRepositoryProtocol = DependencyContainer.shared.trackerRepository,
        notificationService: NotificationServiceProtocol = UserNotificationService.shared
    ) {
        self.reminderService = reminderService
        self.trackerRepository = trackerRepository
        self.notificationService = notificationService
        
        // Setup observers
        setupObservers()
    }
    
    // MARK: - Scheduling
    
    /// Schedule reminders for all trackers
    func scheduleAllReminders() async {
        do {
            let trackers = try await trackerRepository.getAllTrackers()
            
            for tracker in trackers {
                if tracker.reminder?.isEnabled == true {
                    try await scheduleReminder(for: tracker)
                }
            }
            
            Logger.shared.info("Scheduled reminders for \(trackers.count) trackers")
            
        } catch {
            Logger.shared.error("Failed to schedule reminders: %{private}@", error.localizedDescription)
        }
    }
    
    /// Schedule reminder for a specific tracker
    func scheduleReminder(for tracker: Tracker) async throws {
        guard scheduledTrackerIds.contains(tracker.id) == false else {
            Logger.shared.debug("Reminder already scheduled for tracker \(tracker.id)")
            return
        }
        
        try await reminderService.scheduleReminder(for: tracker)
        scheduledTrackerIds.insert(tracker.id)
        
        Logger.shared.debug("Scheduled reminder for tracker \(tracker.id)")
    }
    
    /// Cancel reminder for a specific tracker
    func cancelReminder(for tracker: Tracker) async {
        await reminderService.cancelReminder(for: tracker)
        scheduledTrackerIds.remove(tracker.id)
        
        Logger.shared.debug("Cancelled reminder for tracker \(tracker.id)")
    }
    
    /// Reschedule reminders when a tracker is updated
    func rescheduleReminder(for tracker: Tracker) async throws {
        await cancelReminder(for: tracker)
        try await scheduleReminder(for: tracker)
    }
    
    // MARK: - Cleanup
    
    /// Clean up reminders for deleted trackers
    func cleanupReminders() async {
        do {
            let allTrackers = try await trackerRepository.getAllTrackers()
            let trackerIds = Set(allTrackers.map { $0.id })
            
            // Find reminders for non-existent trackers
            let remindersToCancel = scheduledTrackerIds.subtracting(trackerIds)
            
            for trackerId in remindersToCancel {
                // Create a dummy tracker with the ID
                let dummyTracker = Tracker(
                    id: trackerId,
                    name: "Deleted",
                    type: .streak,
                    isCompleted: false,
                    completionCount: 0,
                    targetCount: 0,
                    completionFrequency: .once,
                    autoCompleteDays: [],
                    reminder: nil,
                    createdAt: Date(),
                    updatedAt: Date(),
                    lastCompletedAt: nil,
                    history: []
                )
                
                await reminderService.cancelReminder(for: dummyTracker)
                scheduledTrackerIds.remove(trackerId)
            }
            
            Logger.shared.info("Cleaned up \(remindersToCancel.count) reminders")
            
        } catch {
            Logger.shared.error("Failed to clean up reminders: %{private}@", error.localizedDescription)
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe tracker changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackerDidChange(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        
        // Observe app events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func trackerDidChange(_ notification: Notification) {
        // Reschedule reminders when trackers change
        Task {
            await scheduleAllReminders()
        }
    }
    
    @objc private func appDidBecomeActive(_ notification: Notification) {
        // Clean up reminders when app becomes active
        Task {
            await cleanupReminders()
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

## 5. Calendar Integration (Optional)

### 5.1 CalendarReminderService

For users who prefer calendar reminders over notifications:

```swift
// CalendarReminderService.swift
import EventKit
import EventKitUI

final class CalendarReminderService: ReminderServiceProtocol {
    
    private let eventStore: EKEventStore
    private let calendarName = "Track It"
    private var trackItCalendar: EKCalendar?
    
    // MARK: - Initialization
    
    init() {
        eventStore = EKEventStore()
        
        // Request access to calendar
        requestCalendarAccess()
    }
    
    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                self.setupCalendar()
            } else if let error = error {
                Logger.shared.error("Calendar access denied: %{private}@", error.localizedDescription)
            }
        }
    }
    
    private func setupCalendar() {
        // Check if our calendar already exists
        let calendars = eventStore.calendars(for: .event)
        trackItCalendar = calendars.first { $0.title == calendarName }
        
        if trackItCalendar == nil {
            // Create new calendar
            trackItCalendar = EKCalendar(for: .event, eventStore: eventStore)
            trackItCalendar?.title = calendarName
            trackItCalendar?.source = eventStore.defaultCalendarForNewEvents?.source
            
            do {
                try eventStore.saveCalendar(trackItCalendar!, commit: true)
                Logger.shared.info("Created Track It calendar")
            } catch {
                Logger.shared.error("Failed to create calendar: %{private}@", error.localizedDescription)
            }
        }
    }
    
    // MARK: - ReminderServiceProtocol
    
    func scheduleReminder(for tracker: Tracker) async throws {
        guard let reminder = tracker.reminder, reminder.isEnabled else { return }
        
        // Create event
        let event = EKEvent(eventStore: eventStore)
        event.title = "Track It: \(tracker.name)"
        event.notes = createEventNotes(for: tracker)
        event.calendar = trackItCalendar
        
        // Set start and end dates
        if let fireDate = calculateNextFireDate(for: reminder) {
            event.startDate = fireDate
            event.endDate = fireDate.addingTimeInterval(3600) // 1 hour duration
        } else {
            throw ReminderError.invalidFireDate
        }
        
        // Set alarm
        if reminder.isEnabled {
            let alarm = EKAlarm(relativeOffset: 0) // At start date
            event.addAlarm(alarm)
        }
        
        // Set recurrence
        switch reminder.repeatInterval {
        case .once:
            // No recurrence
            break
        case .daily:
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
            event.addRecurrenceRule(recurrenceRule)
        case .weekly:
            var daysOfWeek: [EKRecurrenceDayOfWeek] = []
            
            for day in reminder.daysOfWeek {
                daysOfWeek.append(
                    EKRecurrenceDayOfWeek(
                        EKWeekday(day.rawValue),
                        weekNumber: 1
                    )
                )
            }
            
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: daysOfWeek,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
            event.addRecurrenceRule(recurrenceRule)
        }
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            Logger.shared.debug("Created calendar event for tracker \(tracker.id)")
        } catch {
            Logger.shared.error("Failed to create calendar event: %{private}@", error.localizedDescription)
            throw error
        }
    }
    
    func cancelReminder(for tracker: Tracker) async {
        // Find and delete the event
        let predicate = eventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [trackItCalendar].compactMap { $0 }
        )
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if event.title.contains(tracker.id.uuidString) {
                do {
                    try eventStore.remove(event, span: .thisEvent, commit: true)
                    Logger.shared.debug("Removed calendar event for tracker \(tracker.id)")
                } catch {
                    Logger.shared.error("Failed to remove calendar event: %{private}@", error.localizedDescription)
                }
            }
        }
    }
    
    func updateReminder(for tracker: Tracker) async throws {
        await cancelReminder(for: tracker)
        try await scheduleReminder(for: tracker)
    }
    
    func getNextReminderDate(for tracker: Tracker) -> Date? {
        // This would query the calendar for the next event
        // Implementation omitted for brevity
        return nil
    }
    
    func cancelAllReminders() async {
        if let calendar = trackItCalendar {
            let predicate = eventStore.predicateForEvents(
                withStart: Date.distantPast,
                end: Date.distantFuture,
                calendars: [calendar]
            )
            
            let events = eventStore.events(matching: predicate)
            
            for event in events {
                if event.title.contains("Track It:") {
                    do {
                        try eventStore.remove(event, span: .thisEvent, commit: true)
                    } catch {
                        Logger.shared.error("Failed to remove calendar event: %{private}@", error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func hasReminder(for tracker: Tracker) async -> Bool {
        // Query calendar for events matching this tracker
        // Implementation omitted for brevity
        return false
    }
    
    func getAllScheduledReminders() async -> [Tracker] {
        // Implementation omitted for brevity
        return []
    }
    
    // MARK: - Helpers
    
    private func createEventNotes(for tracker: Tracker) -> String {
        switch tracker.type {
        case .streak:
            return "Complete your streak: \(tracker.name)"
        case .negativeStreak:
            return "Remember to avoid: \(tracker.name)"
        case .timeSince:
            return "Time since: \(tracker.name)"
        case .timeAhead:
            return "Countdown to: \(tracker.name)"
        case .counter:
            return "Update counter: \(tracker.name)"
        }
    }
    
    private func calculateNextFireDate(for reminder: Reminder) -> Date? {
        // Same implementation as in LocalReminderService
        // Omitted for brevity
        return Date()
    }
}

enum ReminderError: Error, LocalizedError {
    case calendarAccessDenied
    case calendarNotFound
    case invalidFireDate
    case eventSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access denied"
        case .calendarNotFound:
            return "Track It calendar not found"
        case .invalidFireDate:
            return "Could not calculate fire date"
        case .eventSaveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        }
    }
}
```

## 6. UI Integration

### 6.1 Reminder Creation View

```swift
// ReminderCreationView.swift
import SwiftUI

struct ReminderCreationView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var viewModel: ReminderCreationViewModel
    
    @State private var selectedTime = Date()
    @State private var selectedDays: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    @State private var selectedRepeatInterval: RepeatInterval = .daily
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                } header: {
                    Text("When to remind me?")
                }
                
                Section {
                    if selectedRepeatInterval == .weekly {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Toggle(day.shortDisplayName, isOn: Binding(
                                get: { selectedDays.contains(day) },
                                set: { isOn in
                                    if isOn {
                                        selectedDays.insert(day)
                                    } else {
                                        selectedDays.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                } header: {
                    Picker("Repeat", selection: $selectedRepeatInterval) {
                        ForEach(RepeatInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("Enabled", isOn: $viewModel.isReminderEnabled)
                }
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveReminder()
                        dismiss()
                    }
                    .disabled(!viewModel.isReminderEnabled)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private func setupInitialValues() {
        if let existingReminder = viewModel.existingReminder {
            selectedTime = existingReminder.time
            selectedDays = existingReminder.daysOfWeek
            selectedRepeatInterval = existingReminder.repeatInterval
        }
    }
    
    private func saveReminder() {
        let reminder = Reminder(
            id: UUID(),
            isEnabled: viewModel.isReminderEnabled,
            time: selectedTime,
            daysOfWeek: selectedDays,
            repeatInterval: selectedRepeatInterval
        )
        
        viewModel.saveReminder(reminder)
    }
}
```

### 6.2 ReminderCreationViewModel

```swift
// ReminderCreationViewModel.swift
import Combine

final class ReminderCreationViewModel: BaseViewModel {
    
    @Published var isReminderEnabled = true
    @Published var showSaveSuccess = false
    
    let existingReminder: Reminder?
    private let trackerId: UUID?
    private let onSave: (Reminder) -> Void
    
    init(
        existingReminder: Reminder? = nil,
        trackerId: UUID? = nil,
        onSave: @escaping (Reminder) -> Void
    ) {
        self.existingReminder = existingReminder
        self.trackerId = trackerId
        self.onSave = onSave
        
        super.init()
        
        if let existingReminder = existingReminder {
            isReminderEnabled = existingReminder.isEnabled
        }
    }
    
    func saveReminder(_ reminder: Reminder) {
        onSave(reminder)
        showSaveSuccess = true
    }
}
```

### 6.3 Reminder Settings in Tracker Detail

```swift
// ReminderSettingsSection.swift
import SwiftUI

struct ReminderSettingsSection: View {
    @ObservedObject var viewModel: TrackerDetailViewModel
    @State private var showReminderSheet = false
    
    var body: some View {
        Section {
            if let reminder = viewModel.tracker.reminder, reminder.isEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminder")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "alarm.fill")
                        
                        VStack(alignment: .leading) {
                            Text(reminder.time.formattedTime())
                            
                            if reminder.repeatInterval == .weekly {
                                let days = Array(reminder.daysOfWeek).sorted { $0.rawValue < $1.rawValue }
                                let dayNames = days.map { $0.shortDisplayName }.joined(separator: ", ")
                                Text("On: \(dayNames)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(reminder.repeatInterval.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button("Edit") {
                        showReminderSheet = true
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            } else {
                Button("Add Reminder") {
                    showReminderSheet = true
                }
            }
        } header: {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                Text("Reminders")
            }
        }
        .sheet(isPresented: $showReminderSheet) {
            NavigationStack {
                ReminderCreationView(viewModel: ReminderCreationViewModel(
                    existingReminder: viewModel.tracker.reminder,
                    trackerId: viewModel.tracker.id
                ) { reminder in
                    var tracker = viewModel.tracker
                    tracker.reminder = reminder
                    viewModel.updateTracker(tracker)
                    
                    // Reschedule reminder
                    Task {
                        try await DependencyContainer.shared.reminderService.scheduleReminder(for: tracker)
                    }
                })
            }
        }
    }
}
```

## 7. Notification Handling

### 7.1 Notification Handler

```swift
// NotificationHandler.swift
import UserNotifications

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationHandler()
    
    private let reminderService: ReminderServiceProtocol
    private let trackerRepository: TrackerRepositoryProtocol
    
    // MARK: - Initialization
    
    override init() {
        reminderService = DependencyContainer.shared.reminderService
        trackerRepository = DependencyContainer.shared.trackerRepository
        
        super.init()
        
        // Set as delegate
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        let options: UNNotificationPresentationOptions = [.banner, .sound, .badge, .list]
        completionHandler(options)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }
    
    // MARK: - Response Handling
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let action = NotificationAction(rawValue: response.actionIdentifier) else {
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        
        // Extract tracker ID
        guard let trackerIdString = userInfo["trackerId"] as? String,
              let trackerId = UUID(uuidString: trackerIdString) else {
            return
        }
        
        switch action {
        case .complete:
            handleCompleteAction(trackerId: trackerId)
        case .snooze:
            handleSnoozeAction(trackerId: trackerId, userInfo: userInfo)
        case .reset:
            handleResetAction(trackerId: trackerId)
        case .dismiss:
            // Notification dismissed, do nothing
            break
        }
    }
    
    private func handleCompleteAction(trackerId: UUID) {
        Task {
            do {
                let tracker = try await trackerRepository.getTracker(byId: trackerId)
                
                if var tracker = tracker {
                    // Mark as completed based on tracker type
                    switch tracker.type {
                    case .streak, .counter:
                        var updatedTracker = tracker
                        updatedTracker.complete()
                        try await trackerRepository.updateTracker(updatedTracker)
                        
                        // Reschedule reminder if it's a repeating reminder
                        if let reminder = tracker.reminder, reminder.repeatInterval != .once {
                            try await reminderService.scheduleReminder(for: updatedTracker)
                        }
                        
                    case .negativeStreak:
                        // For negative streaks, marking as incomplete breaks the streak
                        // So we don't want to auto-complete these
                        break
                        
                    case .timeSince:
                        // Reset the counter
                        var updatedTracker = tracker
                        updatedTracker.resetTimeSince()
                        try await trackerRepository.updateTracker(updatedTracker)
                        
                    case .timeAhead:
                        // Time ahead trackers don't have completion
                        break
                    }
                }
            } catch {
                Logger.shared.error("Failed to handle complete action: %{private}@", error.localizedDescription)
            }
        }
    }
    
    private func handleSnoozeAction(trackerId: UUID, userInfo: [AnyHashable: Any]) {
        Task {
            do {
                let tracker = try await trackerRepository.getTracker(byId: trackerId)
                
                if let tracker = tracker, let reminder = tracker.reminder {
                    // Calculate new fire date (10 minutes from now)
                    let newFireDate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
                    
                    // Create new reminder with updated time
                    var newReminder = reminder
                    newReminder.time = newFireDate
                    
                    var updatedTracker = tracker
                    updatedTracker.reminder = newReminder
                    
                    try await trackerRepository.updateTracker(updatedTracker)
                    try await reminderService.scheduleReminder(for: updatedTracker)
                }
            } catch {
                Logger.shared.error("Failed to handle snooze action: %{private}@", error.localizedDescription)
            }
        }
    }
    
    private func handleResetAction(trackerId: UUID) {
        Task {
            do {
                let tracker = try await trackerRepository.getTracker(byId: trackerId)
                
                if let tracker = tracker, tracker.type == .timeSince {
                    var updatedTracker = tracker
                    updatedTracker.resetTimeSince()
                    
                    try await trackerRepository.updateTracker(updatedTracker)
                    
                    // Reschedule reminder if needed
                    if let reminder = tracker.reminder, reminder.isEnabled {
                        try await reminderService.scheduleReminder(for: updatedTracker)
                    }
                }
            } catch {
                Logger.shared.error("Failed to handle reset action: %{private}@", error.localizedDescription)
            }
        }
    }
}
```

## 8. Testing Reminder System

### 8.1 Test Configuration

```swift
// ReminderServiceTests.swift
import XCTest

final class LocalReminderServiceTests: XCTestCase {
    
    var reminderService: LocalReminderService!
    var mockNotificationService: MockNotificationService!
    var mockSettingsRepository: MockSettingsRepository!
    var mockTrackerRepository: MockTrackerRepository!
    
    override func setUp() {
        super.setUp()
        
        mockNotificationService = MockNotificationService()
        mockSettingsRepository = MockSettingsRepository()
        mockTrackerRepository = MockTrackerRepository()
        
        reminderService = LocalReminderService(
            notificationService: mockNotificationService,
            settingsRepository: mockSettingsRepository,
            trackerRepository: mockTrackerRepository
        )
    }
    
    override func tearDown() {
        reminderService = nil
        mockNotificationService = nil
        mockSettingsRepository = nil
        mockTrackerRepository = nil
        super.tearDown()
    }
    
    func testScheduleReminder() async {
        // Create a tracker with a reminder
        let reminder = Reminder(
            id: UUID(),
            isEnabled: true,
            time: Date().addingTimeInterval(3600), // 1 hour from now
            daysOfWeek: [.monday, .tuesday, .wednesday, .thursday, .friday],
            repeatInterval: .daily
        )
        
        let tracker = Tracker.createStreak(
            name: "Test Tracker",
            reminder: reminder
        )
        
        try? await reminderService.scheduleReminder(for: tracker)
        
        // Check if notification was scheduled
        XCTAssertEqual(mockNotificationService.scheduledNotifications.count, 1)
    }
    
    func testCancelReminder() async {
        // Create a tracker with a reminder
        let reminder = Reminder(
            id: UUID(),
            isEnabled: true,
            time: Date().addingTimeInterval(3600),
            daysOfWeek: [.monday],
            repeatInterval: .daily
        )
        
        let tracker = Tracker.createStreak(
            name: "Test Tracker",
            reminder: reminder
        )
        
        try? await reminderService.scheduleReminder(for: tracker)
        await reminderService.cancelReminder(for: tracker)
        
        // Check if notification was cancelled
        XCTAssertEqual(mockNotificationService.cancelledNotificationIds.count, 1)
    }
    
    func testNextFireDate_Daily() {
        let calendar = Calendar.current
        let now = Date()
        
        // Set time to 2 hours from now
        let twoHoursLater = calendar.date(byAdding: .hour, value: 2, to: now)!
        
        let reminder = Reminder(
            isEnabled: true,
            time: twoHoursLater,
            daysOfWeek: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
            repeatInterval: .daily
        )
        
        let nextDate = reminder.nextOccurrence(from: now)
        
        XCTAssertNotNil(nextDate)
        XCTAssertEqual(calendar.component(.hour, from: nextDate!), calendar.component(.hour, from: twoHoursLater))
    }
    
    func testNextFireDate_Weekly() {
        let calendar = Calendar.current
        let now = Date()
        
        // Set time to 2 hours from now, but on a different day
        let twoHoursLater = calendar.date(byAdding: .hour, value: 2, to: now)!
        
        // Only schedule for Monday
        let reminder = Reminder(
            isEnabled: true,
            time: twoHoursLater,
            daysOfWeek: [.monday],
            repeatInterval: .weekly
        )
        
        let nextDate = reminder.nextOccurrence(from: now)
        
        // Should be next Monday at the same time
        XCTAssertNotNil(nextDate)
        if let nextDate = nextDate {
            let weekday = calendar.component(.weekday, from: nextDate)
            XCTAssertEqual(weekday, 2) // Monday
        }
    }
}

// Mock Services
final class MockNotificationService: NotificationServiceProtocol {
    var scheduledNotifications: [UNNotificationRequest] = []
    var cancelledNotificationIds: [String] = []
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }
    
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        .authorized
    }
    
    func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger,
        sound: UNNotificationSound?,
        badge: Int?,
        userInfo: [AnyHashable: Any]?
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo ?? [:]
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        scheduledNotifications.append(request)
    }
    
    func scheduleLocalNotifications(_ requests: [UNNotificationRequest]) async throws {
        scheduledNotifications.append(contentsOf: requests)
    }
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        scheduledNotifications
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        []
    }
    
    func removeNotification(id: String) async {
        cancelledNotificationIds.append(id)
    }
    
    func removeAllPendingNotifications() async {
        scheduledNotifications.removeAll()
    }
    
    func removeAllDeliveredNotifications() async {
        // No-op for mock
    }
    
    func removeNotifications(withIds ids: [String]) async {
        cancelledNotificationIds.append(contentsOf: ids)
    }
    
    var notificationCategories: Set<UNNotificationCategory> = []
}

final class MockTrackerRepository: TrackerRepositoryProtocol {
    var trackers: [Tracker] = []
    
    func getAllTrackers() async throws -> [Tracker] {
        trackers
    }
    
    func getTracker(byId id: UUID) async throws -> Tracker? {
        trackers.first { $0.id == id }
    }
    
    func getTrackers(byType type: TrackerType) async throws -> [Tracker] {
        trackers.filter { $0.type == type }
    }
    
    func createTracker(_ tracker: Tracker) async throws {
        trackers.append(tracker)
    }
    
    func updateTracker(_ tracker: Tracker) async throws {
        if let index = trackers.firstIndex(where: { $0.id == tracker.id }) {
            trackers[index] = tracker
        }
    }
    
    func deleteTracker(_ tracker: Tracker) async throws {
        trackers.removeAll { $0.id == tracker.id }
    }
    
    func hasTrackers() -> Bool {
        !trackers.isEmpty
    }
    
    func getTrackerHistory(trackerId: UUID, limit: Int?) async throws -> [TrackerHistory] {
        trackers.first { $0.id == trackerId }?.history ?? []
    }
    
    func getTrackerHistory(forDate date: Date) async throws -> [TrackerHistory] {
        []
    }
    
    func getCompletionStats(trackerId: UUID) async throws -> CompletionStats {
        CompletionStats()
    }
    
    func resetAllTrackers() async throws {
        trackers = []
    }
    
    func deleteAllTrackers() async throws {
        trackers = []
    }
}
```

## 9. Delivery Checklist

- [ ] NotificationServiceProtocol defined
- [ ] UserNotificationService implemented
- [ ] ReminderServiceProtocol defined
- [ ] LocalReminderService implemented
- [ ] CalendarReminderService implemented (optional)
- [ ] ReminderScheduler implemented
- [ ] Notification categories configured
- [ ] Notification handling implemented
- [ ] UI components for reminder management created
- [ ] Tests for reminder system written

---

**Duration**: 2-3 days
**Priority**: High
**Next**: Proceed to [04-repository-pattern.md](./04-repository-pattern.md)
