import SwiftUI

@Slots public struct Chip<Icon: View, Label: View, Accessory: View>: View {
    @Slot(.image) var icon: Icon?
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

struct Chip_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Chip(
                accessory: {
                    Image(systemName: "star.fill")
                }, label: "Hello")

            Chip(
                accessory: {
                    Image(systemName: "star.fill")
                }, iconSystemName: "star.fill", label: "Featured")

            Chip(
                accessory: {
                    Image(systemName: "star.fill")
                },
                icon: { Image(systemName: "star.fill") },
                label: "Featured"
            )
        }
        .padding()
    }
}
