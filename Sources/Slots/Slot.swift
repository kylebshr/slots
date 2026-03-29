import SwiftUI

/// Marks a non-optional generic property as a slot, or attaches options to any slot.
///
/// Optional generic properties (`Icon?`) are slots automatically — `@Slot` is only
/// required on non-optional generics (`Label`) or when specifying options.
///
/// - `.text` — add `init` variants accepting `LocalizedStringKey` and `String` (disfavored), both stored as `Text(...)`
/// - `.systemImage` — add an `init` variant accepting `{name}SystemName: String`, stored as `Image(systemName:)`
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")
