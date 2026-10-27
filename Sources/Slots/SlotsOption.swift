import SwiftUI

public struct SlotsOption: Sendable, Equatable {
    private let id: Int

    private init(id: Int) {
        self.id = id
    }

    /// Sorted parameters with `@ViewBuilder` closures last are now the default.
    @available(*, deprecated, message: "@ViewBuilder parameters are last by default; remove this option")
    public static let trailingViewBuilders = SlotsOption(id: 0)

    /// Generate `internal` inits instead of matching the struct's access level.
    ///
    /// Use this on a `public` struct whose stored properties have internal types or defaults,
    /// which a `public init` can't expose.
    public static let internalInit = SlotsOption(id: 1)

    /// Keep generated init parameters in the order the properties are declared,
    /// instead of sorting value parameters first and `@ViewBuilder` closures last.
    public static let declarationOrder = SlotsOption(id: 2)
}
