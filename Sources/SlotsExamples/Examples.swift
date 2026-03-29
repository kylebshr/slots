import Slots
import SwiftUI

// MARK: - Chip (2 slots + 1 generic view)

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

// MARK: - Banner (1 slot)

@Slots public struct Banner<Message: View>: View {
    @Slot(.text) var message: Message
    var style: BannerStyle

    public enum BannerStyle {
        case info, warning, error
    }

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

// MARK: - ListRow (3 slots)

@Slots public struct ListRow<Leading: View, Content: View, Trailing: View>: View {
    @Slot(.image) var leading: Leading?
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

// MARK: - Card (4 slots)

@Slots public struct Card<Header: View, Media: View, Body: View, Footer: View>: View {
    @Slot(.text) var header: Header
    @Slot(.image) var media: Media?
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

// MARK: - EmptyState (3 slots)

@Slots public struct EmptyState<Icon: View, Title: View, Action: View>: View {
    @Slot(.image) var icon: Icon?
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

// MARK: - Toolbar (3 slots)

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

// MARK: - ActionButton (1 slot + closure property)

@Slots public struct ActionButton<Label: View>: View {
    var action: () -> Void
    @Slot(.text) var label: Label

    public var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.tint))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

struct Examples_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chip examples
                Chip(label: "Default", accessory: { EmptyView() })
                Chip(iconSystemName: "star.fill", label: "Featured", accessory: { EmptyView() })

                // Banner examples
                Banner(style: .info, message: "Sync complete.")
                Banner(style: .warning, message: "Storage nearly full.")
                Banner(style: .error, message: "Upload failed.")

                // ListRow examples
                ListRow(content: "Wi-Fi", trailing: "Connected")
                ListRow(leadingSystemName: "wifi", content: "Wi-Fi", trailing: "Connected")

                // Card examples
                Card(header: "Welcome Back", body_: "Pick up where you left off.")
                Card(header: "Photo", mediaSystemName: "photo", body_: "A landscape shot.")

                // EmptyState examples
                EmptyState(iconSystemName: "tray", title: "No Messages")
                EmptyState(
                    title: "Nothing Here",
                    action: {
                        Button("Refresh") {}
                    })

                // ActionButton examples
                ActionButton(label: "Save", action: {})
                ActionButton(action: {}) { Text("Custom Label").bold() }

                // ToolbarRow examples
                ToolbarRow(title: "Inbox")
                ToolbarRow(
                    title: "Details",
                    leading: {
                        Button(action: {}) { Image(systemName: "chevron.left") }
                    },
                    trailing: {
                        Button(action: {}) { Image(systemName: "ellipsis") }
                    })
            }
            .padding()
        }
    }
}
