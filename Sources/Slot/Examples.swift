import SwiftUI

/// A pill-shaped chip with an optional leading icon and a required label.
///
/// Usage:
/// ```swift
/// Chip(label: "New")
/// Chip(icon: Image(systemName: "star.fill"), label: "Featured")
/// Chip(label: MyCustomLabel())
/// ```
@Slotted
public struct Chip<Icon: View, Label: View>: View {
    @Slot(.optional)      var icon: Icon
    @Slot(.text, .string) var label: Label

    public var body: some View {
        HStack(spacing: 6) {
            icon
            label
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.quaternary))
    }
}

// Note: use PreviewProvider rather than #Preview macro in library targets —
// the #Preview macro and @attached(extension) macros have a type-checking
// ordering conflict that prevents constrained extension inits from resolving.
struct Chip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            Chip(label: "Hello")
            Chip(icon: Image(systemName: "star.fill"), label: "Featured")
        }
        .padding()
    }
}
