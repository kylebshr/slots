import SwiftSyntax
import SwiftSyntaxMacros

/// Peer macro on stored properties — acts as a marker carrying options.
/// The expansion work is done by `SlotMacro` which reads these annotations.
public struct SlotPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}
