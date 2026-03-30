import Slots
import SwiftUI

@Slots public struct ToolbarRow<Leading: View, Title: View, Trailing: View>: View {
    var leading: Leading?
    @Slot(.text) var title: Title
    var trailing: Trailing?

    public var body: some View {
        HStack {
            if let leading { leading }
            Spacer()
            title.font(.headline)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
