import SwiftSyntax

// Transforms an async function into its synchronous peer:
//   - removes `async` from the signature
//   - strips `await` from call expressions
//   - replaces sync-dispatch if/else blocks with the sync branch body
//   - strips the // @sync comment from leading trivia
final class AsyncToSyncRewriter: SyntaxRewriter {
    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        var modified = node
        if var effects = modified.signature.effectSpecifiers {
            effects.asyncSpecifier = nil
            modified.signature.effectSpecifiers = effects
        }
        modified.leadingTrivia = stripSyncComment(modified.leadingTrivia)
        return super.visit(modified)
    }

    override func visit(_ node: AwaitExprSyntax) -> ExprSyntax {
        var result = visit(node.expression)
        result.leadingTrivia = node.awaitKeyword.leadingTrivia
        return result
    }

    override func visit(_ node: CodeBlockItemListSyntax) -> CodeBlockItemListSyntax {
        var items: [CodeBlockItemSyntax] = []
        for item in node {
            if let syncBody = syncDispatchIfBody(item) {
                items.append(contentsOf: syncBody.map { visit($0) })
                continue
            }
            items.append(visit(item))
        }
        return CodeBlockItemListSyntax(items)
    }
}

// Strips the // @sync line comment (and the newline immediately after it) from trivia.
func stripSyncComment(_ trivia: Trivia) -> Trivia {
    var pieces: [TriviaPiece] = []
    var skipNext = false
    for piece in trivia {
        if skipNext {
            if case .newlines = piece {
                skipNext = false
                continue
            }
            skipNext = false
        }
        if case .lineComment(let text) = piece, text.trimmingCharacters(in: .whitespaces) == "// @sync" {
            skipNext = true
            continue
        }
        pieces.append(piece)
    }
    return Trivia(pieces: pieces)
}

// Returns the if-branch body when `item` is a sync-dispatch if/else whose condition
// matches one of the known sync-safety checks. Handles both .expr(IfExprSyntax) and
// .stmt(ExpressionStmtSyntax{IfExprSyntax}) — the latter is how swift-syntax 600.0.x
// represents if/else statements in function bodies.
func syncDispatchIfBody(_ item: CodeBlockItemSyntax) -> CodeBlockItemListSyntax? {
    // In swift-syntax 600.0.x, if/else as a statement is .stmt(ExpressionStmtSyntax{IfExprSyntax})
    let ifExpr: IfExprSyntax?
    switch item.item {
    case .expr(let e):
        ifExpr = e.as(IfExprSyntax.self)
    case .stmt(let s):
        ifExpr = s.as(ExpressionStmtSyntax.self).flatMap { $0.expression.as(IfExprSyntax.self) }
    default:
        return nil
    }
    guard let ifExpr, ifExpr.elseBody != nil else { return nil }
    let isSyncDispatch = ifExpr.conditions.contains { element in
        let text = element.trimmedDescription
        return text.hasSuffix(".syncSafe")
            || text.hasPrefix("instrSyncSafeBit(")
            || text.hasPrefix("blockSyncSafeBit(")
            || text.contains("syncSafeBuiltin(")
    }
    guard isSyncDispatch else { return nil }
    return ifExpr.body.statements
}
