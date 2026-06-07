# Phase 1: Project Setup

## Overview

This document details the initial project configuration, dependencies, and build settings for the Track It application. The goal is to establish a solid foundation that follows iOS best practices and supports all planned features.

## 1. Xcode Project Configuration

### 1.1 Project Creation

- **Project Name**: TrackIt (no spaces for bundle identifier)
- **Bundle Identifier**: com.arvoldek.TrackIt
- **Interface**: SwiftUI (with UIKit interoperability)
- **Lifecycle**: SwiftUI App (App protocol)
- **Language**: Swift 5.0+
- **Minimum Deployment**: iOS 17.0+ (to use latest Swift features)

### 1.2 Target Configuration

#### Main Target: TrackIt
- **Display Name**: Track It
- **Version**: 1.0.0
- **Build Number**: 1
- **Device Requirements**: iPhone and iPad (Universal)
- **Orientation**: Portrait (iPhone), All (iPad)

#### Capabilities
Enable the following in Signing & Capabilities:
- [x] **iCloud**: For data synchronization
  - Services: CloudKit (NSPersistentCloudKitContainer)
  - Containers: iCloud.com.arvoldek.TrackIt
- [x] **Background Modes**: 
  - Remote notifications (for reminder sync)
- [x] **User Notifications**: For local reminders
- [x] **Keychain Sharing**: For secure storage of sensitive data

#### Info.plist Configuration

```xml
<!-- Required for iCloud -->
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.arvoldek.TrackIt</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <false/>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
        <key>NSUbiquitousContainerName</key>
        <string>TrackIt</string>
    </dict>
</dict>

<!-- User Notifications -->
<key>UIUserNotificationAlertStyle</key>
<string>alert</string>

<!-- Privacy Descriptions -->
<key>NSUserTrackingUsageDescription</key>
<string>Track It uses iCloud to sync your trackers across devices.</string>
<key>NSCalendarsUsageDescription</key>
<string>Track It needs access to calendars to set reminders.</string>
<key>NSRemindersUsageDescription</key>
<string>Track It needs access to reminders to set tracker notifications.</string>

<!-- Week Start Setting -->
<key>NSLocaleCalendar</key>
<string>gregorian</string>
```

### 1.3 Build Settings

#### Swift Compiler Settings
- **Swift Language Version**: Latest stable
- **Optimization Level**: 
  - Debug: None [-Onone]
  - Release: Fast, Single-File Optimization [-O]
- **Debug Information Format**: DWARF with dSYM File
- **Enable Testability**: Yes
- **Code Coverage**: Enable for Debug

#### Linking
- **Dead Code Stripping**: No (for better debugging)
- **Run Script Phases**: 
  - SwiftLint (if installed)
  - Code signing verification

### 1.4 Dependencies

#### Swift Package Manager
Add the following packages to the project:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackIt",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TrackIt",
            targets: ["TrackIt"]),
    ],
    dependencies: [
        // No external dependencies - pure native Swift
        // All functionality will use Apple frameworks
    ],
    targets: [
        .target(
            name: "TrackIt",
            dependencies: []),
        .testTarget(
            name: "TrackItTests",
            dependencies: ["TrackIt"]),
    ]
)
```

**Note**: We're NOT using any third-party libraries to ensure:
- Maximum compatibility with future iOS versions
- No dependency conflicts
- Full control over all features
- Better App Store review process
- Smaller app size

#### Apple Frameworks to Import
- `SwiftUI` - UI framework
- `Combine` - Reactive programming
- `CoreData` - Local persistence
- `CloudKit` - iCloud sync
- `UserNotifications` - Local notifications
- `EventKit` - Calendar integration (optional, for advanced reminders)
- `WidgetKit` - For potential future widgets
- `Charts` - For analytics visualization (iOS 16+)

### 1.5 File Structure

```
TrackIt/
├── TrackIt.xcodeproj
├── TrackIt/
│   ├── Application/
│   │   ├── TrackItApp.swift          # Main app entry
│   │   └── AppDelegate.swift        # For UIKit interop (optional)
│   │
│   ├── Presentation/
│   │   ├── Views/                   # SwiftUI Views
│   │   ├── ViewModels/              # ViewModels
│   │   ├── Coordinators/            # Navigation coordinators
│   │   └── Components/              # Reusable UI components
│   │
│   ├── Domain/
│   │   ├── Entities/                # Business models
│   │   ├── UseCases/                # Business logic
│   │   └── Repositories/            # Repository interfaces
│   │
│   ├── Data/
│   │   ├── CoreData/                # Core Data stack
│   │   │   ├── Models/              # ManagedObject subclasses
│   │   │   ├── Migrations/          # Core Data migrations
│   │   │   └── Persistence.swift    # Persistence controller
│   │   ├── CloudKit/                # iCloud sync
│   │   ├── Local/                   # UserDefaults, File storage
│   │   └── Repositories/            # Repository implementations
│   │
│   ├── Services/
│   │   ├── NotificationService.swift
│   │   ├── ReminderService.swift
│   │   ├── AnalyticsService.swift
│   │   └── DateService.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/              # Swift extensions
│   │   ├── Helpers/                 # Helper classes
│   │   └── Constants/               # App constants
│   │
│   └── Resources/
│       ├── Assets.xcassets/        # Images, colors, icons
│       ├── Localizable.xcstrings/   # Localized strings (Xcode 15+)
│       └── Preview Content/         # Xcode preview assets
│
├── TrackItTests/
│   ├── UnitTests/
│   ├── UITests/
│   └── SnapshotTests/
│
├── TrackItUITests/
│   └── UITests.swift
│
└── implementation/
    └── ...                          # This implementation plan
```

### 1.6 Environment Configuration

#### Debug vs Release

```swift
// In BuildConfig.swift
#if DEBUG
public struct BuildConfig {
    static let isDebug = true
    static let baseURL = "https://debug.api.example.com"
    static let enableLogging = true
    static let enableAnalytics = false
}
#else
public struct BuildConfig {
    static let isDebug = false
    static let baseURL = "https://api.example.com"
    static let enableLogging = false
    static let enableAnalytics = true
}
#endif
```

#### Configuration Files
- **Debug.xcconfig**: Debug-specific settings
- **Release.xcconfig**: Release-specific settings
- **App.xcconfig**: Common settings

### 1.7 Code Signing

- **Automatically manage signing**: Enabled
- **Team**: [Your Apple Developer Team]
- **Provisioning Profile**: Automatic
- **Signing Certificate**: Apple Development (Debug), Apple Distribution (Release)

### 1.8 App Icons

Create app icons for all required sizes:
- iPhone: 20pt, 29pt, 40pt
- iPad: 20pt, 29pt, 40pt, 76pt, 83.5pt
- App Store: 1024pt

Use SF Symbols for consistent iconography:
- App icon: Consider using `checkmark.circle` or `list.bullet` as base
- Tab bar icons: Use SF Symbols with appropriate weights

### 1.9 Launch Screen

Create a simple launch screen using SwiftUI:
```swift
// LaunchScreen.swift
import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                
                Text("Track It")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color("LaunchText"))
            }
        }
    }
}
```

### 1.10 Delivery Checklist

- [ ] Xcode project created with correct settings
- [ ] All capabilities enabled
- [ ] Info.plist configured
- [ ] Build settings optimized
- [ ] File structure created
- [ ] Dependencies configured (none for now)
- [ ] Code signing configured
- [ ] App icons added
- [ ] Launch screen implemented
- [ ] First build succeeds without errors

---

**Duration**: 1 day
**Priority**: Critical (Blocker for all other phases)
**Next**: Proceed to [02-architecture.md](./02-architecture.md)
