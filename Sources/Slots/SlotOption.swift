import SwiftUI

public struct SlotOption: Sendable, Equatable {
    private let id: Int

    private init(id: Int) {
        self.id = id
    }

    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption(id: 0)
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let systemImage = SlotOption(id: 1)

    /// Generate a convenience init using a custom `SlotResolver` to map an input type to a view.
    /// The macro reads the resolver type from syntax and generates constrained extensions using
    /// `Resolver.Input`, `Resolver.Output`, and `Resolver.makeView(_:)`.
    public static func custom<R: SlotResolver>(_ resolver: R.Type) -> SlotOption {
        SlotOption(id: -1)
    }

    /// Modifier that removes the parameter label from the generated init.
    /// Use as `.text.unlabeled` or `.custom(R.self).unlabeled`.
    public var unlabeled: SlotOption { self }
}
