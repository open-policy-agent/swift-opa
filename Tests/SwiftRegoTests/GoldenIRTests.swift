import Foundation
import Testing

@testable import SwiftRego

struct TestURL: CustomTestStringConvertible {
    var url: URL
    var testDescription: String { url.lastPathComponent }
}
func goldenFiles() -> [TestURL] {
    let files = Bundle.module.urls(
        forResourcesWithExtension: "json",
        subdirectory: "Fixtures"
    )!
    return files.map {TestURL(url: $0)}
}

//extension URL: CustomTestStringConvertible {
//    var testDescription: String { name }
//}

@Test("testParsingGolden", arguments: goldenFiles())
func testParsingGolden(input: TestURL) async throws {
    let data = try Data(contentsOf: input.url)
    let policy = try JSONDecoder().decode(Policy.self, from: data)
}
