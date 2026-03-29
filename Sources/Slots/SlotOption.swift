import SwiftUI

public struct SlotOption: Sendable, Equatable {
    private let id: Int
    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption(id: 0)
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let image = SlotOption(id: 1)
}
