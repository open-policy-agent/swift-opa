import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Comparison")
struct ComparisonTests {

    static let greaterThanTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "gt",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "gt",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "gt",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "gt",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "gt",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "gt",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "gt",
            args: [.null, .null],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "gt",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "gt",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "gt",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "gt",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "gt",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "gt",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "gt",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "gt",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "gt",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "gt",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "gt",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "gt",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "gt",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "gt",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let greaterThanEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "gte",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "gte",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "gte",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "gte",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "gte",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "gte",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "gte",
            args: [.null, .null],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "gte",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "gte",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "gte",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "gte",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "gte",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "gte",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "gte",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "gte",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "gte",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "gte",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "gte",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "gte",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "gte",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "gte",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let lessThanTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "lt",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "lt",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "lt",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "lt",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "lt",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "lt",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "lt",
            args: [.null, .null],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "lt",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "lt",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "lt",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "lt",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "lt",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "lt",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "lt",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "lt",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "lt",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "lt",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "lt",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "lt",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lt",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lt",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let lessThanEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true",
            name: "lte",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array false",
            name: "lte",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "lte",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true",
            name: "lte",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false",
            name: "lte",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "lte",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "lte",
            args: [.null, .null],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number true",
            name: "lte",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number false",
            name: "lte",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "lte",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object true",
            name: "lte",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object false",
            name: "lte",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "lte",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set true",
            name: "lte",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set false",
            name: "lte",
            args: [.set([.number(1)]), .array([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "lte",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string true",
            name: "lte",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string false",
            name: "lte",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "lte",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lte",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lte",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let notEqTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array true lt",
            name: "neq",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array true gt",
            name: "neq",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "neq",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true lt",
            name: "neq",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean true gt",
            name: "neq",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "neq",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "neq",
            args: [.null, .null],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number true lt",
            name: "neq",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number true gt",
            name: "neq",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "neq",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object true lt",
            name: "neq",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object true gt",
            name: "neq",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "neq",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set true lt",
            name: "neq",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set true gt",
            name: "neq",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "neq",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string true lt",
            name: "neq",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string true gt",
            name: "neq",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "neq",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "neq",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "neq",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static let equalTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "same type array false lt",
            name: "equal",
            args: [.array([.number(1)]), .array([.number(1), .number(1)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array false gt",
            name: "equal",
            args: [.array([.number(1)]), .array([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type array equals",
            name: "equal",
            args: [.array([.number(1)]), .array([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false lt",
            name: "equal",
            args: [.boolean(false), .boolean(true)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean false gt",
            name: "equal",
            args: [.boolean(true), .boolean(false)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type boolean equals",
            name: "equal",
            args: [.boolean(true), .boolean(true)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type null",
            name: "equal",
            args: [.null, .null],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type number false lt",
            name: "equal",
            args: [.number(0), .number(1)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number false gt",
            name: "equal",
            args: [.number(1), .number(0)],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type number equals",
            name: "equal",
            args: [.number(1), .number(1)],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type object false lt",
            name: "equal",
            args: [
                .object([.string("a"): .number(1)]), .object([.string("a"): .number(1), .string("b"): .number(1)]),
            ],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object false gt",
            name: "equal",
            args: [.object([.string("a"): .number(1)]), .object([:])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type object equals",
            name: "equal",
            args: [.object([.string("a"): .number(1)]), .object([.string("a"): .number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type set false lt",
            name: "equal",
            args: [.set([.number(1)]), .set([.number(1), .number(2)])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set false gt",
            name: "equal",
            args: [.set([.number(1)]), .set([])],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type set equals",
            name: "equal",
            args: [.set([.number(1)]), .set([.number(1)])],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "same type string false lt",
            name: "equal",
            args: [.string("abc"), .string("zzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string false gt",
            name: "equal",
            args: [.string("zzz"), .string("abc")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "same type string equals",
            name: "equal",
            args: [.string("zzz"), .string("zzz")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "equal",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "equal",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            greaterThanTests,
            greaterThanEqTests,
            lessThanTests,
            lessThanEqTests,
            notEqTests,
            equalTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
