import Slots
import SwiftUI

@Slots public struct EmptyViewDemo<Icon: View, Title: View>: View {
    @Slot(.systemImage, .empty) var icon: Icon
    @Slot(.text) var title: Title

    public var body: some View {
        VStack(spacing: 16) {
            icon
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            title
                .font(.title3.weight(.medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
