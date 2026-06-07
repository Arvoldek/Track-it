# Phase 4.2: Navigation Architecture

## Overview

This document defines the navigation architecture for Track It, using a Coordinator pattern combined with SwiftUI's NavigationStack and sheet presentations.

**Part of**: Phase 4 - UI Implementation
**Duration**: 1 day
**Priority**: Critical

## 1. App Coordinator

```swift
// AppCoordinator.swift
import SwiftUI

final class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: Tab = .home
    
    enum Tab: Hashable {
        case home
        case settings
    }
    
    // Sheet destinations
    @Published var sheet: SheetDestination?
    
    enum SheetDestination: Identifiable {
        case trackerTypeSelection
        case trackerCreation(TrackerType)
        case trackerDetails(UUID)
        case settings
        
        var id: String { /* unique ID */ }
    }
    
    // Full screen destinations
    @Published var fullScreen: FullScreenDestination?
    
    enum FullScreenDestination: Identifiable {
        case calendar(UUID)
        case graphs(UUID)
        
        var id: String { /* unique ID */ }
    }
    
    func presentSheet(_ sheet: SheetDestination) {
        self.sheet = sheet
    }
    
    func dismissSheet() {
        self.sheet = nil
    }
    
    func presentFullScreen(_ destination: FullScreenDestination) {
        self.fullScreen = destination
    }
    
    func dismissFullScreen() {
        self.fullScreen = nil
    }
}
```

## 2. Navigation Adapter

```swift
// NavigationAdapter.swift
import SwiftUI

struct NavigationAdapter: View {
    @StateObject var coordinator = AppCoordinator()
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeTabView()
                .tabItem { Label("Trackers", systemImage: "list.bullet") }
                .tag(AppCoordinator.Tab.home)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppCoordinator.Tab.settings)
        }
        .sheet(item: $coordinator.sheet) { destination in
            switch destination {
            case .trackerTypeSelection: TrackerTypeSelectionView()
            case .trackerCreation(let type): TrackerCreationView(trackerType: type)
            case .trackerDetails(let id): TrackerDetailView(trackerId: id)
            case .settings: SettingsView()
            }
        }
        .fullScreenCover(item: $coordinator.fullScreen) { destination in
            switch destination {
            case .calendar(let id): CalendarView(trackerId: id)
            case .graphs(let id): GraphsView(trackerId: id)
            }
        }
    }
}
```

## 3. Navigation Flows

### Main Flow
1. **Launch** -> TabView (Home or Settings)
2. **Home Tab** -> Shows tracker type sections or EmptyState
3. **Add Tracker** -> TrackerTypeSelection (Sheet)
4. **Select Type** -> TrackerCreation (Sheet)
5. **Create Tracker** -> Dismiss sheet, show in list
6. **Tap Tracker** -> TrackerDetail (Sheet)
7. **Detail Actions** -> View History (Full Screen) or View Graphs (Full Screen)

### Settings Flow
1. **Settings Tab** -> SettingsView
2. **Toggle Settings** -> Save immediately
3. **Data Management** -> Show confirmation alert

## 4. Screen Hierarchy

```
Track It App
├── TabView
│   ├── Home Tab
│   │   ├── EmptyStateView (if no trackers)
│   │   └── HomeView (with tracker type sections)
│   │       ├── TrackerTypeSection (per type)
│   │       │   └── TrackerCard (scrollable)
│   │       └── AddTrackerButton
│   └── Settings Tab
│       └── SettingsView
│
├── Sheets
│   ├── TrackerTypeSelectionView
│   ├── TrackerCreationView
│   └── TrackerDetailView
│
└── Full Screen Covers
    ├── CalendarView
    └── GraphsView
```

## 5. Checklist

- [ ] AppCoordinator implemented
- [ ] NavigationAdapter implemented
- [ ] All navigation flows defined
- [ ] Sheet presentations configured
- [ ] Full screen presentations configured
- [ ] Navigation tested on all device sizes

---

**Phase**: 4 - UI Implementation  
**Section**: 4.2 - Navigation Architecture  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1-3  
**Last Updated**: [Date]  
**Version**: 1.0
