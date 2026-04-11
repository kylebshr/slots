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
public macro Slots(_ options: SlotsOption...) = #externalMacro(module: "SlotMacros", type: "SlotMacro")
