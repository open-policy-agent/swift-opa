import AST
import Foundation

extension BuiltinFuncs {
    // regex.match(pattern, value) - returns true if value matches the RE2 pattern
    // OPA docs: https://www.openpolicyagent.org/docs/latest/policy-reference/#regex
    static func regexMatch(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }

        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            throw BuiltinError.evalError(msg: "regex.match: invalid pattern: \(error.localizedDescription)")
        }

        let range = NSRange(value.startIndex..., in: value)
        let matched = regex.firstMatch(in: value, range: range) != nil
        return .boolean(matched)
    }

    // regex.is_valid(pattern) - returns true if the pattern is a valid regex
    static func regexIsValid(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }

        do {
            _ = try NSRegularExpression(pattern: pattern)
            return .boolean(true)
        } catch {
            return .boolean(false)
        }
    }

    // regex.find_all_string_submatch_n(pattern, value, n) - returns all matches with subgroups
    // swiftlint:disable:next function_body_length
    static func regexFindAllStringSubmatchN(
        ctx: BuiltinContext, args: [AST.RegoValue]
    ) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .string(let pattern) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "pattern", got: args[0].typeName, want: "string")
        }

        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }

        guard case .number(let num) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "n", got: args[2].typeName, want: "number")
        }
        let n = num.intValue

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            throw BuiltinError.evalError(
                msg: "regex.find_all_string_submatch_n: invalid pattern: \(error.localizedDescription)"
            )
        }

        let range = NSRange(value.startIndex..., in: value)
        let matches = regex.matches(in: value, range: range)

        let limit = n < 0 ? matches.count : Swift.min(n, matches.count)
        var result: [AST.RegoValue] = []

        for match in matches.prefix(limit) {
            var groups: [AST.RegoValue] = []
            for rangeIdx in 0..<match.numberOfRanges {
                let matchRange = match.range(at: rangeIdx)
                if matchRange.location != NSNotFound, let swiftRange = Range(matchRange, in: value) {
                    groups.append(.string(String(value[swiftRange])))
                } else {
                    groups.append(.string(""))
                }
            }
            result.append(.array(groups))
        }

        return .array(result)
    }
}
