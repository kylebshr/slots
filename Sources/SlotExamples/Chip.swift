import Slots
import SwiftUI

@Slots public struct Chip<Icon: View, Label: View, Accessory: View>: View {
    @Slot(.systemImage) var icon: Icon?
    @Slot(.text) var label: Label
    var accessory: Accessory

    public var body: some View {
        HStack {
            if let icon { icon }
            label
                .font(.caption.weight(.medium))
            accessory
        }
        .padding()
        .background(Capsule().fill(.quaternary))
    }
}
