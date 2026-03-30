import SwiftUI

public struct SlotOption: Sendable, Equatable {
    let id: Int
    let isUnlabeled: Bool

    private init(id: Int, isUnlabeled: Bool = false) {
        self.id = id
        self.isUnlabeled = isUnlabeled
    }

    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption(id: 0)
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let systemImage = SlotOption(id: 1)

    /// Omit the external parameter label (`_ name:`) in text/string convenience inits, matching `Button(_ title:)` ergonomics.
    public var unlabeled: SlotOption {
        SlotOption(id: id, isUnlabeled: true)
    }
}
