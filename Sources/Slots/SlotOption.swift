import SwiftUI

public struct SlotOption: Sendable, Equatable {
    private let id: Int

    private init(id: Int) {
        self.id = id
    }

    /// Generate `LocalizedStringResource` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption(id: 0)
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let systemImage = SlotOption(id: 1)

    /// Omit the external parameter label from the generated init.
    public static let unlabeled = SlotOption(id: 2)

    /// Generate a convenience init that omits this slot's parameter and stores `EmptyView()`.
    /// Only valid on non-optional slots.
    public static let empty = SlotOption(id: 3)
}
