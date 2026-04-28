import AST
import Foundation

// MARK: - Go text/template engine (subset)

// Implements a subset of Go's text/template package used by OPA's strings.render_template.
// Reference: https://pkg.go.dev/text/template
// OPA implementation: https://github.com/open-policy-agent/opa/blob/main/v1/topdown/template.go

func templateValue(from v: AST.RegoValue) -> Any {
    switch v {
    case .string(let s): return s
    case .number(let n):
        if let i = n.int64Value { return i }
        return n.decimalValue
    case .boolean(let b): return b
    case .null: return NSNull()
    case .array(let arr): return arr.map { templateValue(from: $0) }
    case .object(let obj):
        var m: [String: Any] = [:]
        for (k, v) in obj {
            if case .string(let key) = k {
                m[key] = templateValue(from: v)
            }
        }
        return m
    case .set(let s): return s.sorted().map { templateValue(from: $0) }
    case .undefined: return NSNull()
    }
}

func templateStringify(_ value: Any) -> String {
    // Bool must be checked before Int/Int64 because on Darwin,
    // Bool bridges to NSNumber and (true as Any) is Int returns true.
    switch value {
    case let b as Bool: return b ? "true" : "false"
    case let s as String: return s
    case let i as Int: return "\(i)"
    case let i as Int64: return "\(i)"
    case let d as Decimal:
        if let i = d.safeInt64Value {
            return "\(i)"
        }
        return "\(d)"
    case is NSNull: return "<nil>"
    case let arr as [Any]: return "[\(arr.map { templateStringify($0) }.joined(separator: " "))]"
    case let m as [String: Any]:
        let pairs = m.sorted { $0.key < $1.key }.map { "map[\($0.key):\(templateStringify($0.value))]" }
        return pairs.joined(separator: " ")
    default:
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional && mirror.children.isEmpty { return "<nil>" }
        return "\(value)"
    }
}

enum TemplateNode {
    case text(String)
    case field(String)
    case variable(String)
    case ifBlock(condition: TemplateExpr, body: [TemplateNode], elseBody: [TemplateNode])
    case rangeBlock(
        indexVar: String?, valueVar: String?, over: TemplateExpr, body: [TemplateNode], elseBody: [TemplateNode])
}

enum TemplateExpr {
    case dot
    case field(String)
    case variable(String)
}

struct TextTemplate {
    let nodes: [TemplateNode]

    init(_ template: String) throws {
        self.nodes = try TextTemplate.parse(template)
    }

    func execute(with data: [String: Any]) throws -> String {
        var scope = TemplateScope(data: data)
        return try TextTemplate.executeNodes(nodes, scope: &scope)
    }

    private static func executeNodes(_ nodes: [TemplateNode], scope: inout TemplateScope) throws
        -> String
    {
        var result = ""
        for node in nodes {
            switch node {
            case .text(let s):
                result += s
            case .field(let name):
                if let val = scope.lookupField(name) {
                    result += templateStringify(val)
                } else {
                    result += "<no value>"
                }
            case .variable(let name):
                if let val = scope.lookupVar(name) {
                    result += templateStringify(val)
                } else {
                    result += "<no value>"
                }
            case .ifBlock(let condition, let body, let elseBody):
                let condVal = scope.evalExpr(condition)
                if isTruthy(condVal) {
                    result += try executeNodes(body, scope: &scope)
                } else {
                    result += try executeNodes(elseBody, scope: &scope)
                }
            case .rangeBlock(let indexVar, let valueVar, let over, let body, let elseBody):
                let collection = scope.evalExpr(over)
                if let arr = collection as? [Any], !arr.isEmpty {
                    for (i, elem) in arr.enumerated() {
                        scope.pushScope()
                        if let iv = indexVar { scope.setVar(iv, value: i) }
                        if let vv = valueVar { scope.setVar(vv, value: elem) }
                        result += try executeNodes(body, scope: &scope)
                        scope.popScope()
                    }
                } else {
                    result += try executeNodes(elseBody, scope: &scope)
                }
            }
        }
        return result
    }

    static func isTruthy(_ value: Any?) -> Bool {
        guard let value = value else { return false }
        // Bool must be checked before Int/Int64 — on Darwin, Bool bridges
        // to NSNumber so (true as Any) is Int returns true.
        switch value {
        case let b as Bool: return b
        case let i as Int: return i != 0
        case let i as Int64: return i != 0
        case let d as Decimal: return d != 0
        case let s as String: return !s.isEmpty
        case is NSNull: return false
        case let arr as [Any]: return !arr.isEmpty
        case let m as [String: Any]: return !m.isEmpty
        default: return true
        }
    }

    // MARK: - Parser

    private static func parse(_ template: String) throws -> [TemplateNode] {
        let tokens = tokenize(template)
        var idx = 0
        let (nodes, _) = try parseNodes(tokens, &idx, until: nil)
        return nodes
    }

    private static func parseNodes(
        _ tokens: [Token], _ idx: inout Int, until terminators: Set<String>?
    ) throws -> (nodes: [TemplateNode], stoppedAt: String?) {
        var nodes: [TemplateNode] = []
        while idx < tokens.count {
            switch tokens[idx] {
            case .text(let s):
                nodes.append(.text(s))
                idx += 1
            case .action(let action):
                let trimmed = action.trimmingCharacters(in: .whitespaces)
                if let terms = terminators, terms.contains(trimmed) {
                    idx += 1
                    return (nodes, trimmed)
                }
                idx += 1
                if let node = try parseAction(trimmed, tokens, &idx) {
                    nodes.append(node)
                }
            }
        }
        if let terms = terminators {
            throw TemplateError.unexpectedEOF(expected: terms.first ?? "end")
        }
        return (nodes, nil)
    }

    private static func parseAction(
        _ action: String, _ tokens: [Token], _ idx: inout Int
    ) throws -> TemplateNode? {
        if action.hasPrefix("if ") || action == "if" {
            let condStr = action == "if" ? "" : String(action.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let condition = parseExpr(condStr)
            let (body, stoppedAt) = try parseNodes(tokens, &idx, until: ["end", "else"])
            var elseBody: [TemplateNode] = []
            if stoppedAt == "else" {
                (elseBody, _) = try parseNodes(tokens, &idx, until: ["end"])
            }
            return .ifBlock(condition: condition, body: body, elseBody: elseBody)
        }

        if action.hasPrefix("range ") {
            let rangeStr = String(action.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            let (indexVar, valueVar, overExpr) = parseRangeDecl(rangeStr)
            let (body, stoppedAt) = try parseNodes(tokens, &idx, until: ["end", "else"])
            var elseBody: [TemplateNode] = []
            if stoppedAt == "else" {
                (elseBody, _) = try parseNodes(tokens, &idx, until: ["end"])
            }
            return .rangeBlock(
                indexVar: indexVar, valueVar: valueVar, over: overExpr,
                body: body, elseBody: elseBody)
        }

        if action.hasPrefix(".") {
            let field = String(action.dropFirst())
            return .field(field)
        }

        if action.hasPrefix("$") {
            return .variable(action)
        }

        throw TemplateError.unknownAction(action)
    }

    private static func parseExpr(_ s: String) -> TemplateExpr {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed == "." {
            return .dot
        }
        if trimmed.hasPrefix(".") {
            return .field(String(trimmed.dropFirst()))
        }
        if trimmed.hasPrefix("$") {
            return .variable(trimmed)
        }
        return .variable(trimmed)
    }

    private static func parseRangeDecl(_ s: String) -> (indexVar: String?, valueVar: String?, over: TemplateExpr) {
        if let assignIdx = s.range(of: ":=") {
            let varsPart = s[s.startIndex..<assignIdx.lowerBound].trimmingCharacters(in: .whitespaces)
            let exprPart = s[assignIdx.upperBound...].trimmingCharacters(in: .whitespaces)
            let expr = parseExpr(exprPart)

            let varNames = varsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if varNames.count == 2 {
                return (indexVar: varNames[0], valueVar: varNames[1], over: expr)
            } else if varNames.count == 1 {
                return (indexVar: nil, valueVar: varNames[0], over: expr)
            }
            return (indexVar: nil, valueVar: nil, over: expr)
        }
        return (indexVar: nil, valueVar: nil, over: parseExpr(s))
    }

    // MARK: - Tokenizer

    private enum Token {
        case text(String)
        case action(String)
    }

    private static func tokenize(_ template: String) -> [Token] {
        var tokens: [Token] = []
        var remaining = template[...]

        while !remaining.isEmpty {
            guard let openRange = remaining.range(of: "{{") else {
                tokens.append(.text(String(remaining)))
                break
            }
            let textBefore = remaining[remaining.startIndex..<openRange.lowerBound]
            if !textBefore.isEmpty {
                tokens.append(.text(String(textBefore)))
            }
            remaining = remaining[openRange.upperBound...]

            guard let closeRange = remaining.range(of: "}}") else {
                tokens.append(.text(String(remaining)))
                break
            }
            var actionContent = String(remaining[remaining.startIndex..<closeRange.lowerBound])
            if actionContent.hasPrefix("-") {
                actionContent = String(actionContent.dropFirst())
                if let lastIdx = tokens.indices.last, case .text(let t) = tokens[lastIdx] {
                    tokens[lastIdx] = .text(
                        String(t.reversed().drop(while: { $0.isWhitespace || $0.isNewline }).reversed()))
                }
            }
            if actionContent.hasSuffix("-") {
                actionContent = String(actionContent.dropLast())
            }
            tokens.append(.action(actionContent))
            remaining = remaining[closeRange.upperBound...]
        }
        return tokens
    }
}

struct TemplateScope {
    private var data: [String: Any]
    private var varStack: [[String: Any]]

    init(data: [String: Any]) {
        self.data = data
        self.varStack = [[:]]
    }

    func lookupField(_ name: String) -> Any? {
        return data[name]
    }

    func lookupVar(_ name: String) -> Any? {
        for scope in varStack.reversed() {
            if let val = scope[name] { return val }
        }
        return nil
    }

    func evalExpr(_ expr: TemplateExpr) -> Any? {
        switch expr {
        case .dot: return data
        case .field(let name): return lookupField(name)
        case .variable(let name): return lookupVar(name)
        }
    }

    mutating func pushScope() {
        varStack.append([:])
    }

    mutating func popScope() {
        if varStack.count > 1 { varStack.removeLast() }
    }

    mutating func setVar(_ name: String, value: Any) {
        varStack[varStack.count - 1][name] = value
    }
}

enum TemplateError: Error {
    case unexpectedEOF(expected: String)
    case unknownAction(String)
}
