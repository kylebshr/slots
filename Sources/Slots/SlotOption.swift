//
//  SlotOption.swift
//  Slots
//
//  Created by Kyle Bashour on 3/29/26.
//


public struct SlotOption: Sendable {
    /// Generate `LocalizedStringKey` → `Text` and `@_disfavoredOverload` `String` → `Text` convenience inits for this slot.
    public static let text = SlotOption()
    /// Generate `{name}SystemName: String` → `Image(systemName:)` convenience init for this slot.
    public static let image = SlotOption()
}
