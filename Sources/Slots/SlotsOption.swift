import SwiftUI

public struct SlotsOption: Sendable, Equatable {
    private let id: Int

    private init(id: Int) {
        self.id = id
    }

    /// Reorder generated init parameters so `@ViewBuilder` closures appear last,
    /// enabling trailing closure syntax.
    public static let viewBuilderTrailing = SlotsOption(id: 0)
}
