import AST
import Foundation

extension BuiltinFuncs {
    static func concat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let delimiter) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter", got: args[0].typeName, want: "string")
        }

        switch args[1] {
        case .array(let a):
            return try .string(
                a.map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(
                            arg: "collection element: \($0)", got: $0.typeName, want: "string")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        case .set(let s):
            return try .string(
                s.sorted().map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(
                            arg: "collection element: \($0)", got: $0.typeName, want: "string")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "collection", got: args[1].typeName, want: "array|set")
        }
    }

    static func contains(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack", got: args[0].typeName, want: "string")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle", got: args[1].typeName, want: "string")
        }

        // Special logic to mimic the Go strings.Contains() behavior for empty strings..
        if needle.isEmpty {
            return .boolean(true)
        }
        return .boolean(haystack.contains(needle))
    }

    static func endsWith(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let search) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "search", got: args[0].typeName, want: "string")
        }

        guard case .string(let base) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "base", got: args[1].typeName, want: "string")
        }

        return .boolean(search.hasSuffix(base))
    }

    static func indexOf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack", got: args[0].typeName, want: "string")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle", got: args[1].typeName, want: "string")
        }

        // Special case to behave like the Go version does
        guard !needle.isEmpty else {
            return .undefined
        }

        let range = haystack.range(of: needle)
        guard let range = range else {
            return .number(-1)
        }
        return .number(NSNumber(value: haystack.distance(from: haystack.startIndex, to: range.lowerBound)))
    }

    static func lower(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(x.lowercased())
    }

    // split returns an array containing elements of the input string split on a delimiter
    static func split(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard case .string(let delimiter) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter", got: args[1].typeName, want: "string")
        }

        // If sep is empty, Split splits after each UTF-8 sequence
        if delimiter.isEmpty {
            let chars: [AST.RegoValue] = x.map { .string(String($0)) }
            return .array(chars)
        }

        // Note String.split(separator:) behaves completely different and not how we need
        let parts = x.components(separatedBy: delimiter)
        return .array(parts.map { .string(String($0)) })
    }

    // trim returns value with all leading or trailing instances of the cutset characters removed.
    static func trim(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        guard case .string(let cutset) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "cutset", got: args[1].typeName, want: "string")
        }

        let trimmedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: cutset))
        return .string(trimmedValue)
    }

    static func upper(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        return .string(x.uppercased())
    }
}
