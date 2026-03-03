import Foundation

// MARK: - Bearer Authentication Plugin
// From: v1/plugins/rest/auth.go

/// Authentication via a bearer token in the HTTP Authorization header
public struct BearerAuthPlugin: Codable, Equatable {
    public let token: String?
    public let tokenPath: String?
    public let scheme: String?

    public init(
        token: String? = nil,
        tokenPath: String? = nil,
        scheme: String? = nil
    ) {
        self.token = token
        self.tokenPath = tokenPath
        self.scheme = scheme
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case tokenPath = "token_path"
        case scheme
    }
}
