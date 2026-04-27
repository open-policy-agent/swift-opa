import AST
import Foundation
import Testing

@testable import Rego

@Suite
struct TextTemplateTests {

    // MARK: - TextTemplate execute

    @Test func emptyTemplate() throws {
        let tmpl = try TextTemplate("")
        let result = try tmpl.execute(with: [:])
        #expect(result == "")
    }

    @Test func plainText() throws {
        let tmpl = try TextTemplate("hello world")
        let result = try tmpl.execute(with: [:])
        #expect(result == "hello world")
    }

    @Test func simpleFieldAccess() throws {
        let tmpl = try TextTemplate("{{.name}}")
        let result = try tmpl.execute(with: ["name": "Alice"])
        #expect(result == "Alice")
    }

    @Test func fieldWithSurroundingText() throws {
        let tmpl = try TextTemplate("Hello, {{.name}}!")
        let result = try tmpl.execute(with: ["name": "Alice"])
        #expect(result == "Hello, Alice!")
    }

    @Test func missingFieldProducesNoValue() throws {
        let tmpl = try TextTemplate("{{.missing}}")
        let result = try tmpl.execute(with: ["other": "value"])
        #expect(result == "<no value>")
    }

    @Test func nullFieldProducesNil() throws {
        let tmpl = try TextTemplate("{{.key}}")
        let result = try tmpl.execute(with: ["key": NSNull()])
        #expect(result == "<nil>")
    }

    @Test func mixedPresentNullAndMissing() throws {
        let tmpl = try TextTemplate("a={{.a}} b={{.b}} c={{.c}}")
        let result = try tmpl.execute(with: ["a": "ok", "b": NSNull()])
        #expect(result == "a=ok b=<nil> c=<no value>")
    }

    @Test func multipleMissingFields() throws {
        let tmpl = try TextTemplate("a {{.x}} b {{.y}} c")
        let result = try tmpl.execute(with: [:])
        #expect(result == "a <no value> b <no value> c")
    }

    @Test func integerField() throws {
        let tmpl = try TextTemplate("{{.count}}")
        let result = try tmpl.execute(with: ["count": Int64(42)])
        #expect(result == "42")
    }

    @Test func booleanField() throws {
        let tmpl = try TextTemplate("{{.flag}}")
        let result = try tmpl.execute(with: ["flag": true])
        #expect(result == "true")
    }

    @Test func rangeWithIndex() throws {
        let tmpl = try TextTemplate(
            "{{range $i, $v := .items}}{{if $i}},{{end}}{{$v}}{{end}}")
        let result = try tmpl.execute(with: ["items": ["a", "b", "c"]])
        #expect(result == "a,b,c")
    }

    @Test func rangeOverEmptyArray() throws {
        let tmpl = try TextTemplate("{{range $v := .items}}{{$v}}{{end}}")
        let result = try tmpl.execute(with: ["items": [Any]()])
        #expect(result == "")
    }

    @Test func ifTrueCondition() throws {
        let tmpl = try TextTemplate("{{if .show}}visible{{end}}")
        let result = try tmpl.execute(with: ["show": true])
        #expect(result == "visible")
    }

    @Test func ifFalseCondition() throws {
        let tmpl = try TextTemplate("{{if .show}}visible{{end}}")
        let result = try tmpl.execute(with: ["show": false])
        #expect(result == "")
    }

    @Test func ifElse() throws {
        let tmpl = try TextTemplate("{{if .show}}yes{{else}}no{{end}}")
        let result = try tmpl.execute(with: ["show": false])
        #expect(result == "no")
    }

    @Test func complianceComplexTemplate() throws {
        let tmpl = try TextTemplate(
            "{{range $i, $name := .hellonames}}{{if $i}},{{end}}hello {{$name}}{{end}}")
        let result = try tmpl.execute(with: ["hellonames": ["rohan", "john doe"]])
        #expect(result == "hello rohan,hello john doe")
    }

    // MARK: - templateStringify

    @Test func stringifyString() {
        #expect(templateStringify("hello") == "hello")
    }

    @Test func stringifyInt() {
        #expect(templateStringify(42) == "42")
    }

    @Test func stringifyInt64() {
        #expect(templateStringify(Int64(99)) == "99")
    }

    @Test func stringifyBool() {
        #expect(templateStringify(true) == "true")
        #expect(templateStringify(false) == "false")
    }

    @Test func stringifyOptional() {
        let s: String? = nil
        #expect(templateStringify(s as Any) == "<nil>")

        let i: Int? = nil
        #expect(templateStringify(i as Any) == "<nil>")

        let a: [Any]? = nil
        #expect(templateStringify(a as Any) == "<nil>")

        // .some values must NOT produce "<nil>"
        let present: String? = "hello"
        #expect(templateStringify(present as Any) == "hello")
    }

    @Test func stringifyNSNull() {
        #expect(templateStringify(NSNull()) == "<nil>")
    }

    @Test func stringifyArray() {
        let arr: [Any] = ["a", "b", "c"]
        #expect(templateStringify(arr) == "[a b c]")
    }

    @Test func stringifyMap() {
        let m: [String: Any] = ["b": 2, "a": 1]
        #expect(templateStringify(m) == "map[a:1] map[b:2]")
    }

    // MARK: - templateValue

    @Test func convertsRegoString() {
        let v = templateValue(from: .string("hello"))
        #expect(v as? String == "hello")
    }

    @Test func convertsRegoInt() {
        let v = templateValue(from: .number(RegoNumber(int: 42)))
        #expect(v as? Int64 == 42)
    }

    @Test func convertsRegoBool() {
        let v = templateValue(from: .boolean(true))
        #expect(v as? Bool == true)
    }

    @Test func convertsRegoNull() {
        let v = templateValue(from: .null)
        #expect(v is NSNull)
    }

    @Test func convertsRegoArray() {
        let v = templateValue(from: .array([.string("a"), .string("b")]))
        let arr = v as? [Any]
        #expect(arr?.count == 2)
        #expect(arr?[0] as? String == "a")
    }

    @Test func convertsRegoObject() {
        let v = templateValue(from: .object([.string("k"): .string("v")]))
        let m = v as? [String: Any]
        #expect(m?["k"] as? String == "v")
    }

    // MARK: - isTruthy

    @Test func truthyValues() {
        #expect(TextTemplate.isTruthy(true))
        #expect(TextTemplate.isTruthy(1))
        #expect(TextTemplate.isTruthy(Int64(1)))
        #expect(TextTemplate.isTruthy("non-empty"))
        #expect(TextTemplate.isTruthy(["x"] as [Any]))
        #expect(TextTemplate.isTruthy(["k": "v"] as [String: Any]))
    }

    @Test func falsyValues() {
        #expect(!TextTemplate.isTruthy(false))
        #expect(!TextTemplate.isTruthy(0))
        #expect(!TextTemplate.isTruthy(Int64(0)))
        #expect(!TextTemplate.isTruthy(""))
        #expect(!TextTemplate.isTruthy(NSNull()))
        #expect(!TextTemplate.isTruthy([Any]()))
        #expect(!TextTemplate.isTruthy([String: Any]()))
        #expect(!TextTemplate.isTruthy(nil))
    }
}
