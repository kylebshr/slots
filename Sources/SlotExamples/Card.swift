import Slots
import SwiftUI

@Slots public struct Card<Header: View, Media: View, Body: View, Footer: View>: View {
    @Slot(.text) var header: Header
    @Slot(.systemImage) var media: Media?
    @Slot(.text) var body_: Body?
    var footer: Footer?

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .font(.headline)
            if let media { media }
            if let body_ {
                body_
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let footer { footer }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(radius: 2)
    }
}
