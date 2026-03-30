# Slots

A Swift macro for building SwiftUI design system components with generic view slots — without the init explosion.

---

## The problem

SwiftUI's `Button` is a great example of a well-designed component. Its primary initializer accepts a `@ViewBuilder` closure for its label slot, so you can pass anything as the label:

```swift
Button(action: signIn) {
    HStack {
        Image(systemName: "arrow.right.circle")
        Text("Sign In")
    }
}
```

But `Button` also works with a plain string:

```swift
Button("Sign In", action: signIn)
```

That convenience doesn't come for free. Under the hood, SwiftUI ships two extra initializers in constrained extensions — one for `LocalizedStringKey` (preferred) and one for `String` (disfavored), both pinning `Label == Text`:

```swift
// The generic init — lives on the struct itself
init(action: @escaping () -> Void, @ViewBuilder label: () -> Label)

// Convenience inits — live in a constrained extension
extension Button where Label == Text {
    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void)

    @_disfavoredOverload
    init<S: StringProtocol>(_ title: S, action: @escaping () -> Void)
}
```

That's manageable for a single slot. But real design-system components often have more — a card with a title, a subtitle, and an actions region; a row with a leading icon and a trailing accessory. Every slot that should accept a plain string needs its own `where` clause, and every optional slot needs its own omission variant. The combinations multiply fast.

A two-slot component with one optional slot and one text-convenience slot already needs four inits:

```swift
struct Card<Title: View, Actions: View>: View {
    // On the struct
    init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) { ... }

    // extension Card where Title == Text
    init(title: LocalizedStringKey, @ViewBuilder actions: () -> Actions) { ... }

    // extension Card where Actions == Never
    init(@ViewBuilder title: () -> Title) where Actions == Never { ... }

    // extension Card where Title == Text, Actions == Never
    init(title: LocalizedStringKey) where Actions == Never { ... }
}
```

Add a third slot and you're writing twelve inits. Add a fourth and it's more than thirty. Every new slot means updating every existing combination. It's mechanical, error-prone, and no fun.

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
| `.systemImage` | Adds an `init` variant where this slot accepts `{name}SystemName: String`, stored as `Image(systemName:)` |

### Optional slots

A common pattern for optional views in SwiftUI is to accept `some View` and have callers pass `EmptyView()` when they don't want anything rendered:

```swift
// Caller is forced to explicitly say "nothing here"
MyBadge(icon: EmptyView(), label: "New")
```

This works, but it loses information. Inside the component you might want to skip surrounding layout — padding, a divider, a spacer — when the icon is absent. With `EmptyView` you can't know at the type level whether the caller intentionally omitted the icon or just happened to pass an empty view. You'd have to reach for runtime type inspection (`Mirror`, `is EmptyView`) or `AnyView`, both of which are worse than having no slot at all.

The better approach is to make the slot's type `Optional`. When the slot is absent, the type is constrained to `Never` — and because `Never` has no values, an `Optional<Never>` can only ever be `nil`. There's nothing to check at runtime; absence is encoded in the type itself.

Inside the component body, this falls out naturally:

```swift
if let icon { icon }   // skipped entirely when Icon == Never
```

And because absence is a compile-time fact, you can write constrained extensions that are only available when the slot is missing — or, more usefully, require the slot to be present:

```swift
// Only available when there's no icon
extension Badge where Icon == Never {
    func withDefaultIcon() -> some View { ... }
}
```

Declare a slot as optional by using `?` in the property type — no `@Slot` annotation needed:

```swift
var icon: Icon?
```

Slots generates an init variant that omits the parameter entirely and stores `nil`, constraining `Icon == Never` in the where clause of that extension. Call sites just leave the argument out:

```swift
Badge(label: "New")                                    // Icon == Never; icon is always nil
Badge(label: "New") { Image(systemName: "star") }     // Icon == Image; icon is non-nil
```

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

1. **Value parameters** — plain stored properties (`style: Int`, `isEnabled: Bool`) and text/string/systemImage slot parameters (`title: LocalizedStringKey`, `iconSystemName: String`)
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
