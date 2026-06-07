# Phase 5.2: Animations Implementation

## Overview

Implement smooth, native-feeling animations throughout the app following Apple's HIG.

**Part of**: Phase 5 - Advanced Features
**Duration**: 0.5 day
**Priority**: Medium

## 1. Animation Standards

### Duration Guidelines
- **Micro-interactions** (button taps, state changes): 0.1-0.2s
- **Transitions** (screen navigation, modals): 0.2-0.3s
- **Complex animations** (reordering, special effects): 0.3-0.5s
- **Loading states**: 0.5-1.0s

### Easing Curves
- **Default**: `.easeInOut` or `.interactiveSpring`
- **Entering**: `.easeOut`
- **Exiting**: `.easeIn`
- **Bouncy**: `.spring(response: 0.3, dampingFraction: 0.6)`

### Respect Reduced Motion
```swift
let isReducedMotion = UIAccessibility.isReduceMotionEnabled
```

## 2. Common Animations

### Button Tap
```swift
Button(action: {}) {
    Label("Complete", systemImage: "checkmark")
}
.buttonStyle(
    .borderedProminent
    .animation(.spring(response: 0.3, dampingFraction: 0.6))
)
```

### Tracker Card Tap
```swift
TrackerCard(tracker: tracker)
    .contentShape(Rectangle())
    .onTapGesture {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
            // Action
        }
    }
```

### Completion Animation
```swift
// When tracker is completed
withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
    tracker.isCompleted = true
}

// Success checkmark
Image(systemName: "checkmark.circle.fill")
    .transition(.scale.combined(with: .opacity))
```

### Counter Increment/Decrement
```swift
Text("\(counter.currentValue)")
    .transaction { transaction in
        transaction.disablesAnimations = true
    }
    .id(counter.currentValue) // Force redraw

// Or with animation
withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
    counter.currentValue += 1
}
```

### Streak Increment
```swift
Text("Day \(streak.currentStreak)")
    .transition(.asymmetric(
        insertion: .scale.combined(with: .opacity),
        removal: .opacity
    ))
```

### Sheet Presentation
```swift
.sheet(item: $coordinator.sheet) { destination in
    // Content
}
.transition(.move(edge: .bottom))
.animation(.easeOut(duration: 0.25))
```

### Tab Selection
```swift
TabView(selection: $selectedTab) {
    // Tabs
}
.tabViewStyle(.page(indexDisplayMode: .never))
.animation(.easeInOut(duration: 0.3))
```

## 3. Custom Animations

### Streak Counter Animation
```swift
struct StreakCounter: View {
    let streak: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Day")
                .font(.caption)
            
            Text("\(streak)")
                .font(.title)
                .contentTransition(.numericText(countsDown: false))
        }
        .transaction { transaction in
            transaction.disablesAnimations = false
        }
    }
}
```

### Time Counter Animation
```swift
struct TimeCounter: View {
    let time: String
    
    var body: some View {
        Text(time)
            .font(.title)
            .fontWeight(.semibold)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.5), value: time)
    }
}
```

### Chart Animation
```swift
Chart(data) { point in
    LineMark(
        x: .value("Date", point.date),
        y: .value("Value", point.value)
    )
    .interpolationMethod(.catmullRom)
    .animation(.easeInOut(duration: 1.0))
}
.animation(.easeInOut(duration: 1.0))
```

## 4. Haptic Feedback

```swift
// HapticService.swift
import UIKit

protocol HapticService {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func selection()
}

final class DefaultHapticService: HapticService {
    private let impactGenerator = UIImpactFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        impactGenerator.impactOccurred(style: style)
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        notificationGenerator.notificationOccurred(type)
    }
    
    func selection() {
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        selectionGenerator.selectionChanged()
    }
}

// Usage
hapticService.impact(.light) // Light tap
hapticService.impact(.medium) // Medium tap
hapticService.impact(.heavy) // Heavy tap

hapticService.notification(.success) // Success
hapticService.notification(.warning) // Warning
hapticService.notification(.error) // Error

hapticService.selection() // Selection changed
```

## 5. Accessibility Considerations

```swift
// Always check for reduced motion
let animation = UIAccessibility.isReduceMotionEnabled 
    ? .none 
    : .spring(response: 0.3, dampingFraction: 0.6)

// Disable animations when reduced motion is enabled
if !UIAccessibility.isReduceMotionEnabled {
    withAnimation(.easeInOut) {
        // Animated code
    }
}
```

## 6. Checklist

### Animations
- [ ] Button tap animations
- [ ] Tracker card interactions
- [ ] Completion animations
- [ ] Counter increment/decrement
- [ ] Streak counter animation
- [ ] Time counter animation
- [ ] Chart animations
- [ ] Screen transitions
- [ ] Sheet presentations

### Haptics
- [ ] HapticService implemented
- [ ] Impact feedback for taps
- [ ] Notification feedback for actions
- [ ] Selection feedback for changes
- [ ] Respect reduced motion setting

### Testing
- [ ] All animations smooth
- [ ] No animation jank
- [ ] Reduced motion support verified
- [ ] Haptic feedback working
- [ ] Animations tested on all devices

---

**Phase**: 5 - Advanced Features  
**Section**: 5.2 - Animations & Haptics  
**Duration**: 0.5 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 4  
**Last Updated**: [Date]  
**Version**: 1.0
