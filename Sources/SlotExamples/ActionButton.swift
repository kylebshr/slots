import Slots
import SwiftUI

@Slots(.viewBuilderTrailing) public struct ActionButton<Label: View>: View {
    var action: () -> Void
    @Slot(.text, .unlabeled) var label: Label

    public var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.tint))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
