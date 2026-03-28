# Slot

A Swift macro for building SwiftUI design system components with generic view slots — without the init explosion.

---

## The problem

A well-designed SwiftUI component accepts generic `View` parameters for its customizable regions ("slots"), so callers can pass anything from a `Text` to a fully custom view. But offering sane defaults — like an init that takes a plain string — creates an exponential blowup of handwritten initializers as slot count grows.

A two-slot component with one optional slot and one text-convenience slot already needs four inits. Three slots needs twelve. And every time you add a slot you have to update them all.

```swift
// Just two slots. Already four inits to write and maintain.
struct Card<Title: View, Actions: View>: View {
    init(title: Title, actions: Actions) { ... }
    init(title: LocalizedStringKey, actions: Actions) { ... }
    init(title: Title) where Actions == EmptyView { ... }
    init(title: LocalizedStringKey) where Actions == EmptyView { ... }
}
```

## The solution

Annotate your component with `@Slotted` and mark each slot property with `@Slot`. The macro generates every init permutation for you — fully type-safe, using constrained extensions with no casts.

```swift
import Slot

@Slotted
struct Card<Title: View, Actions: View>: View {
    @Slot(.text)     var title: Title
    @Slot(.optional) var actions: Actions

    var body: some View { ... }
}
```

That's it. The macro expands to:

```swift
// On the struct — caller provides any View
init(title: Title, actions: Actions)

// extension Card where Title == Text
init(title: LocalizedStringKey, actions: Actions)

// extension Card where Actions == EmptyView
init(title: Title)

// extension Card where Title == Text, Actions == EmptyView
init(title: LocalizedStringKey)
```

Call sites stay clean and exactly what you'd expect:

```swift
Card(title: "Hello", actions: likeButton)   // LocalizedStringKey + custom view
Card(title: "Hello")                         // LocalizedStringKey, no actions
Card(title: headerView, actions: likeButton) // custom view + custom view
Card(title: headerView)                      // custom view, no actions
```

---

## Slot options

Annotate each slot property with `@Slot` and one or more options:

| Option | Effect |
|---|---|
| `.text` | Adds an `init` variant where this slot accepts `LocalizedStringKey`, stored as `Text(...)` |
| `.string` | Adds a `@_disfavoredOverload init` variant accepting `String`, also stored as `Text(...)`. Pair with `.text` so string literals prefer the localized version. |
| `.optional` | Adds an `init` variant that omits this parameter entirely, storing `EmptyView()` |

### Example with all three options

```swift
@Slotted
struct Badge<Icon: View, Label: View>: View {
    @Slot(.optional)            var icon: Icon
    @Slot(.text, .string)       var label: Label

    var body: some View { ... }
}
```

Generated inits:

```swift
// Base
init(icon: Icon, label: Label)

// extension Badge where Label == Text
init(icon: Icon, label: LocalizedStringKey)           // preferred
@_disfavoredOverload
init(icon: Icon, label: String)                       // disfavored

// extension Badge where Icon == EmptyView
init(label: Label)

// extension Badge where Icon == EmptyView, Label == Text
init(label: LocalizedStringKey)                       // preferred
@_disfavoredOverload
init(label: String)                                   // disfavored
```

Call sites:

```swift
Badge(label: "New")                                   // LocalizedStringKey, no icon
Badge(label: "New" as String)                         // explicit String, no icon
Badge(icon: Image(systemName: "star"), label: "New")  // icon + LocalizedStringKey
Badge(icon: starView, label: customLabel)             // fully generic
```

---

## Plain stored properties

Non-slot stored properties without a default value are included as labeled parameters in every generated init, before the slot parameters:

```swift
@Slotted
struct Row<Content: View>: View {
    var isSelected: Bool          // no default → appears in every init
    var badge: Int = 0            // has default → omitted from inits
    @Slot(.text) var content: Content

    var body: some View { ... }
}

// Generated:
init(isSelected: Bool, content: Content)
// extension Row where Content == Text
init(isSelected: Bool, content: LocalizedStringKey)
```

---

## Installation

Add the package in Xcode via **File → Add Package Dependencies**, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kylebshr/slot.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "Slot", package: "slot"),
    ]),
]
```

Then import and use:

```swift
import Slot
import SwiftUI

@Slotted
struct MyComponent<...>: View { ... }
```

> **Note on previews:** Due to a type-checking ordering conflict between `#Preview` and `@attached(extension)` macros, use `PreviewProvider` instead of `#Preview` when writing previews inside a library module. Previews in app targets work fine with either form.

---

## How it works

`@Slotted` is an `@attached(member)` + `@attached(extension)` macro.

- The **member** expansion adds the base all-generic `init` directly on the struct.
- The **extension** expansion generates one `extension MyComponent where ...` per unique combination of fixed slot types. Grouping by where-clause means `.text` and `.string` variants for the same slot share a single extension with two `init` overloads.

Because the concrete types are fixed by the where clause rather than cast inside the init, the entire thing is fully type-safe — `Chip<EmptyView, Text>` and `Chip<Image, Text>` are genuinely different types.
