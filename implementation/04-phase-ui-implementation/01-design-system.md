# Phase 4.1: Design System

## Overview

This document defines the design system for the Track It application, following Apple's Human Interface Guidelines to ensure a native, first-party Apple app experience.

**Part of**: Phase 4 - UI Implementation
**Duration**: 1 day
**Priority**: Critical

## 1. Color Palette

### Tracker Type Colors

```swift
// Color+AppColors.swift
import SwiftUI

extension Color {
    // Tracker type colors
    static let streak = Color("StreakColor")
    static let negativeStreak = Color("NegativeStreakColor")
    static let timeSince = Color("TimeSinceColor")
    static let timeAhead = Color("TimeAheadColor")
    static let counter = Color("CounterColor")
}
```

### Semantic Colors

```swift
// Color+Semantic.swift
extension Color {
    // Background
    static let primaryBackground = Color("PrimaryBackground")
    static let secondaryBackground = Color("SecondaryBackground")
    static let tertiaryBackground = Color("TertiaryBackground")
    
    // Text
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let tertiaryText = Color("TertiaryText")
    
    // Accent
    static let accent = Color("AccentColor")
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    static let error = Color("ErrorColor")
    
    // State
    static let completed = Color("CompletedColor")
    static let incomplete = Color("IncompleteColor")
}
```

## 2. Typography

```swift
// Font+AppFonts.swift
import SwiftUI

extension Font {
    // Headings
    static let largeTitle = Font.system(.largeTitle, design: .rounded)
    static let title = Font.system(.title, design: .rounded)
    static let title2 = Font.system(.title2, design: .rounded)
    static let title3 = Font.system(.title3, design: .rounded)
    
    // Body
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let subheadline = Font.system(.subheadline, design: .rounded)
    
    // Fixed size
    static let trackerValue = Font.system(.title, weight: .semibold, design: .rounded)
    static let trackerLabel = Font.system(.body, weight: .medium, design: .rounded)
    static let button = Font.system(.headline, weight: .semibold, design: .rounded)
}
```

## 3. Spacing System

```swift
// Spacing.swift
import SwiftUI

enum Spacing {
    case xxs
    case xs
    case sm
    case md
    case lg
    case xl
    case xxl
    
    var value: CGFloat {
        switch self {
        case .xxs: return 4
        case .xs: return 8
        case .sm: return 12
        case .md: return 16
        case .lg: return 24
        case .xl: return 32
        case .xxl: return 48
        }
    }
    
    var view: some View {
        SwiftUI.Spacer().frame(height: value)
    }
}
```

## 4. Corner Radii

```swift
// CornerRadius.swift
import SwiftUI

enum CornerRadius {
    case none
    case sm
    case md
    case lg
    case xl
    case full
    
    var value: CGFloat {
        switch self {
        case .none: return 0
        case .sm: return 8
        case .md: return 12
        case .lg: return 16
        case .xl: return 24
        case .full: return .infinity
        }
    }
}
```

## 5. Checklist

- [ ] Color palette defined in Assets.xcassets
- [ ] Typography system defined
- [ ] Spacing system implemented
- [ ] Corner radius system implemented
- [ ] All colors and fonts used consistently

---

**Phase**: 4 - UI Implementation  
**Section**: 4.1 - Design System  
**Duration**: 1 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 1-3  
**Last Updated**: [Date]  
**Version**: 1.0
