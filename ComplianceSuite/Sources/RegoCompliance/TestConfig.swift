import Foundation

struct ComplianceTestConfig: Codable {
    let knownIssues: [KnownIssue]

    enum CodingKeys: String, CodingKey {
        case knownIssues = "known-issues"
    }
}

public struct KnownIssue: Codable {
    public let tests: String
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case tests
        case reason
    }
}
