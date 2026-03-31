import Slots
import SwiftUI

// MARK: - Custom type and view

public enum Priority: String, Sendable {
    case low, medium, high
}

public struct PriorityBadge: View {
    let priority: Priority

    public var body: some View {
        Text(priority.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch priority {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

// MARK: - Resolver: maps Priority → PriorityBadge for use as a slot option

public enum PriorityResolver: SlotResolver {
    public typealias Input = Priority
    public typealias Output = PriorityBadge
    public static func makeView(_ input: Priority) -> PriorityBadge {
        PriorityBadge(priority: input)
    }
}

// MARK: - Component using the custom option

@Slots public struct TaskRow<Title: View, Badge: View>: View {
    @Slot(.text) var title: Title
    @Slot(.custom(PriorityResolver.self)) var badge: Badge?

    public var body: some View {
        HStack {
            title
            Spacer()
            if let badge { badge }
        }
        .padding(.vertical, 4)
    }
}
