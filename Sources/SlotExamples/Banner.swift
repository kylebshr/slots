import Slots
import SwiftUI

public enum BannerStyle {
    case info, warning, error
}

@Slots public struct Banner<Message: View>: View {
    @Slot(.text) var message: Message
    var style: BannerStyle

    public var body: some View {
        HStack {
            image
            message
            Spacer()
        }
        .padding()
        .background(backgroundColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var image: some View {
        let name: String =
            switch style {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        return Image(systemName: name)
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch style {
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}
