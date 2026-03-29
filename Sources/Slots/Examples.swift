import SwiftUI

@Slots
public struct Chip<Icon: View, Label: View>: View {
    @Slot(.image)
    var icon: Icon?

    @Slot(.text)
    var label: Label

    public var body: some View {
        HStack {
            if let icon { icon }
            label
                .font(.caption.weight(.medium))
        }
        .padding()
        .background(Capsule().fill(.quaternary))
    }
}

struct Chip_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Chip(label: "Hello")
            Chip(iconSystemName: "star.fill", label: "Featured")
            Chip(
                icon: { Image(systemName: "star.fill") },
                label: "Featured"
            )
        }
        .padding()
    }
}
