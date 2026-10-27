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

That convenience doesn't come for free. Under the hood, SwiftUI ships two extra initializers in constrained extensions — one for `LocalizedStringResource` (preferred) and one for `String` (disfavored), both pinning `Label == Text`:

```swift
// The generic init — lives on the struct itself
init(action: @escaping () -> Void, @ViewBuilder label: () -> Label)

// Convenience inits — live in a constrained extension
extension Button where Label == Text {
    init(_ titleKey: LocalizedStringResource, action: @escaping () -> Void)

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
    init(title: LocalizedStringResource, @ViewBuilder actions: () -> Actions) { ... }

    // extension Card where Actions == Never
    init(@ViewBuilder title: () -> Title) where Actions == Never { ... }

    // extension Card where Title == Text, Actions == Never
    init(title: LocalizedStringResource) where Actions == Never { ... }
}
```

Add a third slot and you're writing twelve inits. Add a fourth and it's more than thirty. Every new slot means updating every existing combination. It's mechanical, error-prone, and no fun.

## The solution

Annotate your component with `@Slots`. Every generic `View` property is automatically a slot — no per-property annotation needed. The macro picks them all up and generates a `@ViewBuilder` init parameter for each one. Mark a slot optional with `?` and the omission variants are generated too.

The `@Slot` annotation is entirely optional. You only need it when you want convenience inits that accept a `String` or system image name rather than a `@ViewBuilder` closure — the same thing SwiftUI does for `Button`'s label.

```swift
import Slots

@Slots
struct Card<Title: View, Actions: View>: View {
    @Slot(.text)   // optional: adds LocalizedStringResource / String convenience inits
    var title: Title

    var actions: Actions?   // optional slot — no annotation needed

    var body: some View { ... }
}
```

That's it. The macro expands to:

```swift
// On the struct — caller provides any View via @ViewBuilder closure
init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions)

// extension Card where Title == Text
init(title: LocalizedStringResource, @ViewBuilder actions: () -> Actions)
@_disfavoredOverload
init(title: String, @ViewBuilder actions: () -> Actions)

// extension Card where Actions == Never
init(@ViewBuilder title: () -> Title)

// extension Card where Title == Text, Actions == Never
init(title: LocalizedStringResource)
@_disfavoredOverload
init(title: String)
```

Call sites stay clean and exactly what you'd expect:

```swift
Card(title: "Hello") { likeButton }           // LocalizedStringResource + custom view
Card(title: "Hello")                           // LocalizedStringResource, no actions
Card { headerView } actions: { likeButton }   // custom view + custom view
Card { headerView }                            // custom view, no actions
```

---

## The `@Slot` annotation

You don't need `@Slot` to define a slot. Any generic `View` property — required or optional — is a slot automatically, and `@Slots` generates the corresponding `@ViewBuilder` init parameters without it.

`@Slot` is purely additive: it attaches convenience options to a slot, asking the macro to also generate inits that accept a plain value (a string, a system image name) and construct the view internally. Without any options it has no effect.

The available options are:

| Option | Effect |
|---|---|
| `.text` | Adds `init` variants where this slot accepts `LocalizedStringResource` (preferred) or `String` (disfavored), both stored as `Text(...)` |
| `.systemImage` | Adds an `init` variant where this slot accepts `{name}SystemName: String`, stored as `Image(systemName:)` |
| `SomeResolver.self` | Adds an `init` variant where this slot accepts the resolver's `Input`, stored as its `Output` |
| `.unlabeled` | Omits the parameter label (`_ name:`) from the `.text` and resolver variants on the same `@Slot` attribute |
| `.empty` | Adds an `init` variant that omits a non-optional slot and stores `EmptyView()` |

A property can have more than one `@Slot` attribute. Each attribute's `.unlabeled` applies only to the variants on that attribute, so you can label one variant and not another:

```swift
@Slot(.text) @Slot(PriorityResolver.self, .unlabeled) var badge: Badge

// Generated:
// init(badge: LocalizedStringResource)   where Badge == Text
// init(_ badge: Priority)                where Badge == PriorityResolver.Output
```

Each option or resolver can appear only once per property.

Each slot needs its own generic parameter. A convenience init fixes the slot's parameter to one type (`Text`, `Never`, ...). That type then also applies to every other property that uses the same parameter. `@Slots` reports an error when two slots, or a slot and another property, share one.

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
struct Badge<Label: View, Icon: View>: View {
    @Slot(.text) var label: Label
    var icon: Icon?

    var body: some View { ... }
}
```

Generated inits:

```swift
// Base — all @ViewBuilder
init(@ViewBuilder label: () -> Label, @ViewBuilder icon: () -> Icon)

// extension Badge where Label == Text
init(label: LocalizedStringResource, @ViewBuilder icon: () -> Icon)           // preferred
@_disfavoredOverload
init(label: String, @ViewBuilder icon: () -> Icon)                       // disfavored

// extension Badge where Icon == Never
init(@ViewBuilder label: () -> Label)

// extension Badge where Icon == Never, Label == Text
init(label: LocalizedStringResource)                                          // preferred
@_disfavoredOverload
init(label: String)                                                      // disfavored
```

Call sites:

```swift
Badge(label: "New")                                    // LocalizedStringResource, no icon
Badge(label: "New" as String)                          // explicit String, no icon
Badge(label: "New") { Image(systemName: "star") }     // LocalizedStringResource + icon
Badge { customLabel } icon: { starView }               // fully generic
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
init(isSelected: Bool, badge: Int = 0, content: LocalizedStringResource)
@_disfavoredOverload
init(isSelected: Bool, badge: Int = 0, content: String)
```

## Parameter ordering

Generated init parameters follow the order of the stored properties in the struct. Non-optional closure parameters automatically get `@escaping`.

```swift
@Slots
struct ActionButton<Label: View>: View {
    @Slot(.text) var label: Label
    var action: () -> Void

    var body: some View { ... }
}

ActionButton(label: "Save", action: { print("saved") })
ActionButton(label: { Text("Save").bold() }, action: { print("saved") })
```

To sort parameters by kind instead, as SwiftUI does, use `@Slots(.trailingViewBuilders)`. The parameters then come in this order, and declaration order applies within each group:

1. Value parameters: plain stored properties (`style: Int`, `isEnabled: Bool`) and text, string, and system image slot parameters (`title: LocalizedStringResource`, `iconSystemName: String`)
2. Closure parameters: plain stored properties with function types (`action: @escaping () -> Void`)
3. `@ViewBuilder` closures: slots in generic mode, generic view properties, and closure properties marked `@ViewBuilder` (`@ViewBuilder label: () -> Label`)

With this option, the last `@ViewBuilder` parameter supports trailing closure syntax:

```swift
@Slots(.trailingViewBuilders)
struct ActionButton<Label: View>: View {
    @Slot(.text) var label: Label
    var action: () -> Void

    var body: some View { ... }
}

ActionButton(label: "Save", action: { print("saved") })
ActionButton(action: { print("saved") }) {
    Text("Save").bold()
}
```

## Access level

Generated inits have the same access level as the struct, so a `public` component gets `public` inits. A `private` struct gets `fileprivate` inits, so the rest of the file can call them.

A `public init` cannot expose a property whose type or default value is internal. For those structs, use `@Slots(.internalInit)` to generate `internal` inits instead:

```swift
@Slots(.internalInit)
public struct Badge<Label: View>: View {
    var style: InternalStyle
    @Slot(.text) var label: Label

    public var body: some View { ... }
}
```

---

## Installation

Add the package in Xcode via **File → Add Package Dependencies**, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kylebshr/slots.git", from: "1.0.0"),
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
- The **extension** expansion generates one `extension MyComponent where ...` per unique combination of fixed slot types. Grouping by where-clause means `LocalizedStringResource` and `String` variants for the same slot share a single extension with two `init` overloads.
