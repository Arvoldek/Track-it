# Phase 5.3: Accessibility Implementation

## Overview

Implement comprehensive accessibility features to ensure the app is usable by everyone.

**Part of**: Phase 5 - Advanced Features
**Duration**: 0.5 day
**Priority**: High

## 1. Accessibility Standards

### WCAG Compliance
- **Minimum contrast ratio**: 4.5:1 for normal text
- **Large text contrast**: 3:1 minimum
- **Touch targets**: Minimum 44x44 points

### Apple HIG Accessibility
- Support VoiceOver
- Support Voice Control
- Support Switch Control
- Support Dynamic Type
- Support Reduced Motion

## 2. Implementation

### VoiceOver Support

```swift
// All interactive elements need accessibility labels
Image(systemName: "plus")
    .accessibilityLabel("Add")
    .accessibilityAddTraits(.isButton)

Button(action: {}) {
    Label("Create Tracker", systemImage: "plus")
}
.accessibilityHint("Creates a new tracker")

// Custom views need accessibility elements
struct TrackerCard: View {
    let tracker: any BaseTrackerProtocol
    
    var body: some View {
        VStack {
            // Content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tracker.name), \(tracker.isCompleted ? "Completed" : "Incomplete")")
        .accessibilityHint("Tap to view details")
    }
}
```

### Dynamic Type Support

```swift
// All fonts use system text styles
Text("Hello")
    .font(.body) // System body text
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Optional max size

// Custom fonts should scale
Font.system(.body, design: .rounded)

// Test with all Dynamic Type sizes
// Settings > Accessibility > Display & Text Size > Larger Text
```

### Color Contrast

```swift
// Use semantic colors that automatically adapt
Color.primaryText // Dark mode aware
Color.secondaryText

// Custom colors in Assets.xcassets with both light and dark variants
// Verify contrast with Xcode's contrast checker

// Test contrast programmatically
import UIKit

let foreground = UIColor.label
let background = UIColor.systemBackground
let contrastRatio = foreground.contrastRatio(with: background)
// Should be >= 4.5 for normal text
```

### Reduced Motion

```swift
// Check before animations
if !UIAccessibility.isReduceMotionEnabled {
    withAnimation(.spring) {
        // Animation code
    }
}

// Custom animation modifier
struct ConditionalAnimation: ViewModifier {
    let animation: Animation?
    
    func body(content: Content) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            content
        } else if let animation = animation {
            content
                .animation(animation, value: UUID())
        } else {
            content
        }
    }
}

// Usage
Text("Value")
    .modifier(ConditionalAnimation(animation: .spring()))
```

### Touch Targets

```swift
// Minimum 44x44 points
Button(action: {}) {
    Image(systemName: "plus")
}
.buttonStyle(.plain)
.contentShape(Circle())
.frame(minWidth: 44, minHeight: 44)

// Or use .imageScale to ensure SF Symbols are large enough
Image(systemName: "plus")
    .imageScale(.large)
```

### Accessibility Actions

```swift
// Custom accessibility actions
struct CounterView: View {
    @Binding var count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
        }
        .accessibilityAction(named: "Increment") {
            count += 1
        }
        .accessibilityAction(named: "Decrement") {
            count -= 1
        }
    }
}

// Or use .accessibilityAddTraits for standard actions
Button(action: {}) {
    Text("Delete")
}
.accessibilityAddTraits(.isDestructive)
```

### Accessibility Values

```swift
// For custom controls, provide accessibility value
struct ProgressIndicator: View {
    let progress: Double
    
    var body: some View {
        ProgressView(value: progress)
            .accessibilityValue("\(Int(progress * 100))%")
            .accessibilityLabel("Progress")
    }
}

// For numeric values
Text("\(value)")
    .accessibilityValue("\(value)")
```

### Focus Management

```swift
// For Voice Control and Switch Control
@FocusState private var isFocused: Bool

TextField("Name", text: $name)
    .focused($isFocused)
    .onAppear {
        isFocused = true
    }

// Custom focus order
struct FormView: View {
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, email, password
    }
    
    var body: some View {
        VStack {
            TextField("Name", text: $name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
            
            TextField("Email", text: $email)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
            
            SecureField("Password", text: $password)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
        }
        .onSubmit {
            switch focusedField {
            case .name: focusedField = .email
            case .email: focusedField = .password
            case .password: submitForm()
            case .none: break
            }
        }
    }
}
```

### Screen Reader Testing

```swift
// Test VoiceOver programmatically
import Accessibility

// In tests
func testAccessibility() {
    let app = XCUIApplication()
    app.launch()
    
    // Verify elements are accessible
    let button = app.buttons["Create Tracker"]
    XCTAssertTrue(button.exists)
    
    // Verify labels
    XCTAssertEqual(button.label, "Create Tracker")
    
    // Verify hints
    XCTAssertEqual(button.hint, "Creates a new tracker")
}
```

## 3. Testing Checklist

### Manual Testing
- [ ] Test with VoiceOver on all screens
- [ ] Test with Voice Control
- [ ] Test with Switch Control
- [ ] Test with all Dynamic Type sizes
- [ ] Test with Reduced Motion enabled
- [ ] Test with Smart Invert enabled
- [ ] Test with Display & Text Size settings

### Automated Testing
- [ ] Accessibility tests for all interactive elements
- [ ] Contrast ratio verification
- [ ] Touch target size verification
- [ ] Dynamic Type compatibility tests

## 4. Common Issues to Avoid

### Don't
- ❌ Use hardcoded colors that don't adapt to dark mode
- ❌ Use fixed font sizes
- ❌ Create custom controls without accessibility
- ❌ Use color alone to convey meaning
- ❌ Assume users can see the screen

### Do
- ✅ Use semantic colors
- ✅ Use system font styles
- ✅ Add accessibility labels to all elements
- ✅ Provide text alternatives for colors
- ✅ Test with screen readers

## 5. Resources

- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Accessibility Scanner for iOS](https://developer.apple.com/documentation/xcode/using-the-accessibility-inspector)

## 6. Checklist

### Implementation
- [ ] All interactive elements have accessibility labels
- [ ] All elements have appropriate traits
- [ ] Touch targets are minimum 44x44 points
- [ ] Color contrast meets WCAG standards
- [ ] Dynamic Type support implemented
- [ ] Reduced Motion support implemented
- [ ] Custom controls have accessibility actions
- [ ] VoiceOver tested on all screens

### Testing
- [ ] VoiceOver tests pass
- [ ] Voice Control tests pass
- [ ] Switch Control tests pass
- [ ] Dynamic Type tests pass
- [ ] Reduced Motion tests pass

---

**Phase**: 5 - Advanced Features  
**Section**: 5.3 - Accessibility  
**Duration**: 0.5 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 4  
**Last Updated**: [Date]  
**Version**: 1.0
