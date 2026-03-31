import SwiftUI

/// Marks a non-optional generic property as a slot, or attaches options to any slot.
///
/// Optional generic properties (`Icon?`) are slots automatically — `@Slot` is only
/// required on non-optional generics (`Label`) or when specifying options.
///
/// - `.text` — add `init` variants accepting `LocalizedStringKey` and `String` (disfavored), both stored as `Text(...)`
/// - `.systemImage` — add an `init` variant accepting `{name}SystemName: String`, stored as `Image(systemName:)`
/// - `MyResolver.self` — add an `init` variant accepting the resolver's `Input`, stored via `MyResolver.resolve(_:)`
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")

/// Marks a non-optional generic property as a slot with a custom resolver.
///
/// The resolver's `Input` type becomes the parameter type and `Output` becomes the view type.
@attached(peer)
public macro Slot<R: SlotResolver>(_ resolver: R.Type) =
    #externalMacro(
        module: "SlotMacros", type: "SlotPropertyMacro"
    )
