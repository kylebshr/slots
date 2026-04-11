import SwiftUI

struct Examples_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chip examples
                Chip(label: "Default", accessory: { EmptyView() })
                Chip(iconSystemName: "star.fill", label: "Featured", accessory: { EmptyView() })

                // Banner examples
                Banner(message: "Sync complete.", style: .info)
                Banner(message: "Storage nearly full.", style: .warning)
                Banner(message: "Upload failed.", style: .error)

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

                EmptyViewDemo(iconSystemName: "tray", title: "Icon")
                EmptyViewDemo(title: "No icon")

                // TaskRow examples — uses custom resolver slot with .unlabeled
                TaskRow(title: "Buy groceries", .high)
                TaskRow(title: "Read article", .low)
                TaskRow(title: "No priority")
                TaskRow(title: "Custom badge") {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }

                // ActionButton examples — uses .unlabeled so no label: prefix
                ActionButton("Save", action: {})
                ActionButton(action: {}) { Text("Custom Label").bold() }

                // ToolbarRow examples
                ToolbarRow(title: "Inbox")
                ToolbarRow(
                    leading: {
                        Button(action: {}) { Image(systemName: "chevron.left") }
                    },
                    title: "Details",
                    trailing: {
                        Button(action: {}) { Image(systemName: "ellipsis") }
                    })
            }
            .padding()
        }
    }
}
