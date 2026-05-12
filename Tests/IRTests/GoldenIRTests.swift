import Foundation
import Testing

@testable import IR

// TestURL wraps our test arguments to make their descriptions pretty
struct TestURL {
    var url: URL
}
extension TestURL: CustomTestStringConvertible {
    var testDescription: String { url.lastPathComponent }
}

func goldenFiles() -> [TestURL] {
    let files = Bundle.module.urls(
        forResourcesWithExtension: "json",
        subdirectory: "Fixtures"
    )!
    return files.map { TestURL(url: $0 as URL) }
}

@Test("testParsingGolden", arguments: goldenFiles())
func testParsingGolden(input: TestURL) async throws {
    let data = try Data(contentsOf: input.url)
    let _ = try JSONDecoder().decode(Policy.self, from: data)
}

// Round-trip each golden fixture through the full serdes flow:
// JSON -> Policy -> JSON -> Policy, asserting that the re-decoded
// policy matches the first one. The JSON bytes themselves are not
// required to match (key order, whitespace, and optional/default
// fields can differ), but the model must survive the trip.
@Test("testRoundtripGolden", arguments: goldenFiles())
func testRoundtripGolden(input: TestURL) async throws {
    let data = try Data(contentsOf: input.url)
    let first = try JSONDecoder().decode(Policy.self, from: data)
    let encoded = try JSONEncoder().encode(first)
    let second = try JSONDecoder().decode(Policy.self, from: encoded)
    #expect(first == second)
}
