import SwiftUI

// MARK: - Macro declarations

/// Attach to a SwiftUI struct to generate all init permutations for its `@Slot`-annotated properties.
///
/// ```swift
/// @Slotted
/// struct Chip<Icon: View, Label: View>: View {
///     @Slot(.optional)        var icon: Icon
///     @Slot(.text, .string)   var label: Label
///     var body: some View { ... }
/// }
/// ```
///
/// The macro generates:
/// - A base `init` on the struct (all slots take their generic `View` type)
/// - One constrained `extension ... where GenericParam == ConcreteType` per unique
///   combination of fixed slots, with multiple `init` overloads inside when `.text`
///   and `.string` are both present (the `String` variant is `@_disfavoredOverload`)
@attached(member, names: named(init))
@attached(extension, names: named(init))
public macro Slotted() = #externalMacro(module: "SlotMacros", type: "SlotMacro")

/// Annotates a stored property in a `@Slot`-decorated struct.
///
/// - `.text`     — add an `init` variant accepting `LocalizedStringKey`, stored as `Text(...)`
/// - `.string`   — add a `@_disfavoredOverload init` variant accepting `String`, stored as `Text(...)`
/// - `.optional` — add an `init` variant that omits this parameter, storing `EmptyView()`
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")

// MARK: - Options

public struct SlotOption: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Generate a `LocalizedStringKey` → `Text` convenience init for this slot.
    public static let text     = SlotOption(rawValue: 1 << 0)

    /// Generate an `EmptyView` default init variant for this slot (parameter omitted).
    public static let optional = SlotOption(rawValue: 1 << 1)

    /// Generate a `@_disfavoredOverload` `String` → `Text` convenience init for this slot.
    /// Pair with `.text` so that string literals resolve to the `LocalizedStringKey` variant.
    public static let string   = SlotOption(rawValue: 1 << 2)
}
