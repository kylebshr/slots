import Slots
import SwiftUI

@Slots public struct ListRow<Leading: View, Content: View, Trailing: View>: View {
    @Slot(.systemImage) var leading: Leading?
    @Slot(.text) var content: Content
    @Slot(.text) var trailing: Trailing?

    public var body: some View {
        HStack {
            if let leading { leading }
            content
            Spacer()
            if let trailing {
                trailing
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
