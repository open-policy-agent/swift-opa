import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Generates a synchronous peer of the annotated `async throws` function.
///
/// The generated peer has the same name and parameters but:
/// - `async` is removed from the function signature
/// - All `await` keywords are stripped from call expressions
/// - Optional member-name substitutions are applied (see `replacing:with:`)
///
/// Swift's overload resolution automatically picks the correct variant:
/// - `try await fn(...)` dispatches to the original async version
/// - `try fn(...)` (no `await`) dispatches to the generated sync version
public struct SyncMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: MacroExpansionErrorMessage("@sync can only be applied to functions")
                )
            )
            return []
        }

        // Parse optional replacing:/with: arguments
        let substitution = parseSubstitution(from: node)

        let rewriter = AsyncToSyncRewriter(viewMode: .sourceAccurate, substitution: substitution)
        let syncDecl = rewriter.visit(funcDecl)
        return [syncDecl]
    }

    // Returns (from, to) if both `replacing:` and `with:` are present, otherwise nil.
    private static func parseSubstitution(from node: AttributeSyntax) -> (from: String, to: String)? {
        guard let args = node.arguments?.as(LabeledExprListSyntax.self) else { return nil }
        var replacing: String?
        var with: String?
        for arg in args {
            guard let label = arg.label?.text else { continue }
            guard let strLit = arg.expression.as(StringLiteralExprSyntax.self),
                let segment = strLit.segments.first?.as(StringSegmentSyntax.self)
            else { continue }
            let value = segment.content.text
            switch label {
            case "replacing": replacing = value
            case "with": with = value
            default: break
            }
        }
        guard let from = replacing, !from.isEmpty, let to = with, !to.isEmpty else { return nil }
        return (from: from, to: to)
    }
}

// MARK: - Rewriter

private final class AsyncToSyncRewriter: SyntaxRewriter {
    let substitution: (from: String, to: String)?

    init(viewMode: SyntaxTreeViewMode, substitution: (from: String, to: String)?) {
        self.substitution = substitution
        super.init(viewMode: viewMode)
    }

    // Strip `async` from function effect specifiers, remove `@sync` attribute
    // from the generated peer (to avoid recursive macro expansion), then recurse
    // into the body so the other overrides can strip `await`.
    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        var modified = node

        // Remove `async` from the effect specifiers
        if var effects = modified.signature.effectSpecifiers {
            effects.asyncSpecifier = nil
            modified.signature.effectSpecifiers = effects
        }

        // Remove @sync attribute so the generated peer doesn't trigger another expansion
        modified.attributes = modified.attributes.filter { element in
            guard case .attribute(let attr) = element else { return true }
            return attr.attributeName.trimmedDescription != "sync"
        }

        return super.visit(modified)
    }

    // Strip `await` from await expressions, keeping the inner expression.
    // Leading trivia from the `await` keyword is preserved on the result so
    // indentation / spacing is unchanged in macro expansion previews.
    override func visit(_ node: AwaitExprSyntax) -> ExprSyntax {
        // Visit the inner expression via the generic visit<T: SyntaxChildChoices> overload,
        // which correctly dispatches to any specialized `visit` override on the concrete type.
        var result = visit(node.expression)
        result.leadingTrivia = node.awaitKeyword.leadingTrivia
        return result
    }

    // Apply member-name substitution (e.g. "asyncLookup" → "syncLookup").
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        guard let sub = substitution, node.declName.baseName.text == sub.from else {
            return super.visit(node)
        }
        var modified = node
        modified.declName.baseName = .identifier(sub.to)
        return super.visit(modified)
    }

    // Filter sync-dispatch if/else blocks before recursing into the remaining items.
    //
    // For sync-dispatch if/else blocks of the form:
    //   if <expr>.syncSafeOffsets.contains(...) { <sync> } else { <async> }
    //   if <expr>.functionSyncSafe[...] { <sync> } else { <async> }
    // the generated sync peer always takes the sync branch, so the entire if/else is
    // replaced with just the if-branch body (visited to strip any residual `await`).
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

// MARK: - Helpers

/// Returns the body of the sync (if) branch when `item` is a sync-dispatch if/else of the form:
///
///   if block.syncSafe { <sync> } else { <async> }
///   if syncSafe { <sync> } else { <async> }
///   if (<expr> & 0x4000_0000) != 0 { <sync> } else { <async> }
///
/// In the generated sync peer these checks are always true, so only the if-branch is needed.
private func syncDispatchIfBody(_ item: CodeBlockItemSyntax) -> CodeBlockItemListSyntax? {
    guard case .expr(let expr) = item.item else { return nil }
    guard let ifExpr = expr.as(IfExprSyntax.self) else { return nil }
    guard ifExpr.elseBody != nil else { return nil }
    let cond = ifExpr.conditions.description
    guard cond.contains("syncSafe") || cond.contains("0x4000_0000") else {
        return nil
    }
    return ifExpr.body.statements
}
