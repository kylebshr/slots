import Slots
import SwiftUI

@Slots public struct EmptyState<Icon: View, Title: View, Action: View>: View {
    @Slot(.systemImage) var icon: Icon?
    @Slot(.text) var title: Title
    var action: Action?

    public var body: some View {
        VStack(spacing: 16) {
            if let icon {
                icon
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            title
                .font(.title3.weight(.medium))
            if let action { action }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
