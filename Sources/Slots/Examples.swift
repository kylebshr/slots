import SwiftUI

@Slots
public struct Chip<Icon: View, Label: View>: View {
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
            Chip(
                icon: { Image(systemName: "star.fill") },
                label: "Featured"
            )
            Chip {
                Text("Hello")
                    .font(.largeTitle)
            }
        }
        .padding()
    }
}
