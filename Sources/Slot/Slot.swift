import SwiftUI

// MARK: - Macro declarations

/// Attach to a SwiftUI struct to generate all init permutations for its `@Slot`-annotated properties.
///
/// ```swift
/// @Slotted
/// struct Chip<Icon: View, Label: View>: View {
///     @Slot var icon: Icon?
///     @Slot(.text) var label: Label
///     var body: some View { ... }
/// }
/// ```
///
/// The macro generates:
/// - A base `init` on the struct (all slots take their generic `View` type)
/// - One constrained `extension ... where GenericParam == ConcreteType` per unique
///   combination of fixed slots, with multiple `init` overloads inside when `.text`
///   is present (both `LocalizedStringKey` and `@_disfavoredOverload String` variants)
@attached(member, names: named(init))
@attached(extension, names: named(init))
public macro Slotted() = #externalMacro(module: "SlotMacros", type: "SlotMacro")

/// Annotates a stored property in a `@Slot`-decorated struct.
///
/// Optionality is inferred from the property type: `var icon: Icon?` automatically
/// generates a no-parameter init variant that stores `nil`.
///
/// - `.text` — add `init` variants accepting `LocalizedStringKey` and `String` (disfavored), both stored as `Text(...)`
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")

// MARK: - Options

public struct SlotOption: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption(rawValue: 1 << 0)
}
