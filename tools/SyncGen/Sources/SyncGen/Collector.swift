import SwiftSyntax

struct GeneratedPeer {
    let typePath: String
    let function: FunctionDeclSyntax
}

final class SyncFunctionCollector: SyntaxVisitor {
    var peers: [GeneratedPeer] = []
    private var typeStack: [String] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.extendedType.trimmedDescription)
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: StructDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: ClassDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: EnumDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.name.text)
        return .visitChildren
    }
    override func visitPost(_ node: ActorDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasSyncComment(node.leadingTrivia) else {
            return .skipChildren
        }
        let rewriter = AsyncToSyncRewriter(viewMode: .sourceAccurate)
        guard let syncFunc = rewriter.visit(node).as(FunctionDeclSyntax.self) else {
            return .skipChildren
        }
        peers.append(GeneratedPeer(typePath: typeStack.joined(separator: "."), function: syncFunc))
        return .skipChildren
    }
}

// Returns true if a `// @sync` line comment is present in the given trivia.
func hasSyncComment(_ trivia: Trivia) -> Bool {
    for piece in trivia {
        if case .lineComment(let text) = piece, text.trimmingCharacters(in: .whitespaces) == "// @sync" {
            return true
        }
    }
    return false
}
