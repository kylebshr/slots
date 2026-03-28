import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SlotPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SlotMacro.self,
        SlotPropertyMacro.self,
    ]
}
