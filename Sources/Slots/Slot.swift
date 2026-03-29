import SwiftUI

// MARK: - Macro declarations

/// Generates all init permutations for a SwiftUI struct's slot properties.
///
/// Optional generic properties (e.g. `var icon: Icon?`) are automatically recognized as slots.
/// Use `@Slot` only when you need to specify options like `.text`.
///
/// ```swift
/// @Slots
/// struct Chip<Icon: View, Label: View>: View {
///     var icon: Icon?
///     @Slot(.text) var label: Label
///     var body: some View { ... }
/// }
/// ```
@attached(member, names: named(init))
@attached(extension, names: named(init))
public macro Slots() = #externalMacro(module: "SlotMacros", type: "SlotMacro")

/// Marks a non-optional generic property as a slot, or attaches options to any slot.
///
/// Optional generic properties (`Icon?`) are slots automatically — `@Slot` is only
/// required on non-optional generics (`Label`) or when specifying options.
///
/// - `.text` — add `init` variants accepting `LocalizedStringKey` and `String` (disfavored), both stored as `Text(...)`
/// - `.image` — add an `init` variant accepting `{name}SystemName: String`, stored as `Image(systemName:)`
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")

// MARK: - Options

public struct SlotOption: Sendable {
    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption()
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let image = SlotOption()
}
