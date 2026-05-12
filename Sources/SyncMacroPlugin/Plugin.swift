import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct VMSyncMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SyncMacro.self
    ]
}
