import SwiftUI

public struct SlotsOption: Sendable, Equatable {
    private let id: Int

    private init(id: Int) {
        self.id = id
    }

    /// Reorder generated init parameters so `@ViewBuilder` closures appear last,
    /// enabling trailing closure syntax.
    public static let trailingViewBuilders = SlotsOption(id: 0)

    /// Generate `internal` inits instead of matching the struct's access level.
    ///
    /// Use this on a `public` struct whose stored properties have internal types or defaults,
    /// which a `public init` can't expose.
    public static let internalInit = SlotsOption(id: 1)
}
