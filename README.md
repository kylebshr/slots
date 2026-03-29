# Slots

A Swift macro for building SwiftUI design system components with generic view slots — without the init explosion.

---

## The problem

A well-designed SwiftUI component accepts generic `View` parameters for its customizable regions ("slots"), so callers can pass anything from a `Text` to a fully custom view. But offering sane defaults — like an init that takes a plain string — creates an exponential blowup of handwritten initializers as slot count grows.

A two-slot component with one optional slot and one text-convenience slot already needs four inits. Three slots needs twelve. And every time you add a slot you have to update them all.

```swift
// Just two slots. Already four inits to write and maintain.
struct Card<Title: View, Actions: View>: View {
    init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) { ... }
    init(title: LocalizedStringKey, @ViewBuilder actions: () -> Actions) { ... }
    init(@ViewBuilder title: () -> Title) where Actions == Never { ... }
    init(title: LocalizedStringKey) where Actions == Never { ... }
}
```

## The solution

Annotate your component with `@Slots`. Optional generic properties are automatically recognized as slots; use `@Slot` only when you need options like `.text`. The macro generates every init permutation for you — fully type-safe, using constrained extensions with no casts.

```swift
import Slots

@Slots
struct Card<Title: View, Actions: View>: View {
    @Slot(.text)
    var title: Title

    var actions: Actions?

    var body: some View { ... }
}
```

That's it. The macro expands to:

```swift
// On the struct — caller provides any View via @ViewBuilder closure
init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions)

// extension Card where Title == Text
init(title: LocalizedStringKey, @ViewBuilder actions: () -> Actions)
@_disfavoredOverload
init(title: String, @ViewBuilder actions: () -> Actions)

// extension Card where Actions == Never
init(@ViewBuilder title: () -> Title)

// extension Card where Title == Text, Actions == Never
init(title: LocalizedStringKey)
@_disfavoredOverload
init(title: String)
```

Call sites stay clean and exactly what you'd expect:

```swift
Card(title: "Hello") { likeButton }           // LocalizedStringKey + custom view
Card(title: "Hello")                           // LocalizedStringKey, no actions
Card { headerView } actions: { likeButton }   // custom view + custom view
Card { headerView }                            // custom view, no actions
```

---

## Slot options

The `@Slot` property annotation accepts one or more options:

| Option | Effect |
|---|---|
| `.text` | Adds `init` variants where this slot accepts `LocalizedStringKey` (preferred) or `String` (disfavored), both stored as `Text(...)` |
| `.image` | Adds an `init` variant where this slot accepts `{name}SystemName: String`, stored as `Image(systemName:)` |

### Optional slots

Declare a slot as optional by using `?` in the property type — no `@Slot` annotation needed:

```swift
var icon: Icon?
```

This automatically generates an init variant that omits the parameter entirely, storing `nil`. The absent slot type is constrained to `Never`.

### Example

```swift
@Slots
struct Badge<Icon: View, Label: View>: View {
    var icon: Icon?
    @Slot(.text) var label: Label

    var body: some View { ... }
}
```

Generated inits:

```swift
// Base — all @ViewBuilder
init(@ViewBuilder icon: () -> Icon, @ViewBuilder label: () -> Label)

// extension Badge where Label == Text — value param before @ViewBuilder
init(label: LocalizedStringKey, @ViewBuilder icon: () -> Icon)           // preferred
@_disfavoredOverload
init(label: String, @ViewBuilder icon: () -> Icon)                       // disfavored

// extension Badge where Icon == Never
init(@ViewBuilder label: () -> Label)

// extension Badge where Icon == Never, Label == Text
init(label: LocalizedStringKey)                                          // preferred
@_disfavoredOverload
init(label: String)                                                      // disfavored
```

Call sites:

```swift
Badge(label: "New")                                    // LocalizedStringKey, no icon
Badge(label: "New" as String)                          // explicit String, no icon
Badge(label: "New") { Image(systemName: "star") }     // LocalizedStringKey + icon
Badge { starView } label: { customLabel }              // fully generic
```

---

## Plain stored properties

Non-slot stored properties are included as labeled parameters in every generated init. Properties with a default value carry that default in the generated signature:

```swift
@Slots
struct Row<Content: View>: View {
    var isSelected: Bool          // no default → required in every init
    var badge: Int = 0            // has default → optional param in every init
    @Slot(.text) var content: Content

    var body: some View { ... }
}

// Generated:
init(isSelected: Bool, badge: Int = 0, @ViewBuilder content: () -> Content)
// extension Row where Content == Text
init(isSelected: Bool, badge: Int = 0, content: LocalizedStringKey)
@_disfavoredOverload
init(isSelected: Bool, badge: Int = 0, content: String)
```

## Parameter ordering

Generated init parameters are sorted by type to match SwiftUI conventions, regardless of declaration order in the struct:

1. **Value parameters** — plain stored properties (`style: Int`, `isEnabled: Bool`) and text/string/image slot parameters (`title: LocalizedStringKey`, `iconSystemName: String`)
2. **Closure parameters** — plain stored properties with function types (`action: @escaping () -> Void`). Non-optional closures automatically get `@escaping`.
3. **@ViewBuilder closures** — slots in generic mode and plain generic view properties (`@ViewBuilder label: () -> Label`)

This means the last `@ViewBuilder` parameter always supports trailing closure syntax:

```swift
@Slots
struct ActionButton<Label: View>: View {
    var action: () -> Void
    @Slot(.text) var label: Label

    var body: some View { ... }
}

// text mode: value → closure
ActionButton(label: "Save", action: { print("saved") })

// generic mode: closure → @ViewBuilder (trailing closure)
ActionButton(action: { print("saved") }) {
    Text("Save").bold()
}
```

---

## Installation

Add the package in Xcode via **File → Add Package Dependencies**, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kylebshr/slots.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "Slots", package: "slots"),
    ]),
]
```

Then import and use:

```swift
import Slots
import SwiftUI

@Slots
struct MyComponent<...>: View { ... }
```

---

## How it works

`@Slots` is an `@attached(member)` + `@attached(extension)` macro. Non-required generic properties (those typed as optional generics like `Icon?`) are automatically treated as slots. The `@Slot` annotation is only needed to specify options.

- The **member** expansion adds the base all-generic `init` directly on the struct, with each slot parameter as a `@ViewBuilder` closure.
- The **extension** expansion generates one `extension MyComponent where ...` per unique combination of fixed slot types. Grouping by where-clause means `LocalizedStringKey` and `String` variants for the same slot share a single extension with two `init` overloads.
