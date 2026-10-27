import SwiftUI

/// Marks a non-optional generic property as a slot, or attaches options to any slot.
///
/// Optional generic properties (`Icon?`) are slots automatically — `@Slot` is only
/// required on non-optional generics (`Label`) or when specifying options.
///
/// - `.text` — add `init` variants accepting `LocalizedStringResource` and `String` (disfavored), both stored as `Text(...)`
/// - `.systemImage` — add an `init` variant accepting `{name}SystemName: String`, stored as `Image(systemName:)`
/// - `.unlabeled` — omit the external parameter label (`_ name:`) in this attribute's `.text` and resolver inits
/// - `.empty` — add an `init` variant that omits a non-optional slot and stores `EmptyView()`
///
/// A property can have several `@Slot` attributes. Each attribute's `.unlabeled` applies only to the
/// variants on that attribute, so `@Slot(.text) @Slot(MyResolver.self, .unlabeled)` gives a labeled
/// text init and an unlabeled resolver init.
@attached(peer)
public macro Slot(_ options: SlotOption...) = #externalMacro(module: "SlotMacros", type: "SlotPropertyMacro")

/// Marks a generic property as a slot with a custom resolver.
///
/// The resolver's `Input` type becomes the parameter type and `Output` becomes the view type.
/// Pass `.unlabeled` to omit the external parameter label from this attribute's inits.
@attached(peer)
public macro Slot<R: SlotResolver>(_ resolver: R.Type, _ options: SlotOption...) =
    #externalMacro(
        module: "SlotMacros", type: "SlotPropertyMacro"
    )
