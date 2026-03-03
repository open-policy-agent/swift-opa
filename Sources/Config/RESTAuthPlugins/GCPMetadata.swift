import Foundation

// MARK: - GCP Metadata Authentication Plugin
// From: v1/plugins/rest/gcp.go

private let defaultGCPMetadataEndpoint = "http://metadata.google.internal"
private let defaultAccessTokenPath = "/computeMetadata/v1/instance/service-accounts/default/token"
private let defaultIdentityTokenPath = "/computeMetadata/v1/instance/service-accounts/default/identity"

/// Represents authentication via GCP metadata service
public struct GCPMetadataAuthPlugin: Codable, Equatable {
    let accessTokenPath: String
    let audience: String?
    let endpoint: String
    let identityTokenPath: String
    let scopes: [String]

    enum CodingKeys: String, CodingKey {
        case accessTokenPath = "access_token_path"
        case audience
        case endpoint
        case identityTokenPath = "identity_token_path"
        case scopes
    }

    // Note: The default values set here are derived from the `NewClient()`
    // method for this type over in OPA. This behavior may be refactored in
    // in the future when we decide where config validation should be happening.
    public init(
        accessTokenPath: String? = nil,
        audience: String? = nil,
        endpoint: String?,
        identityTokenPath: String? = nil,
        scopes: [String] = []
    ) {
        self.accessTokenPath = accessTokenPath ?? defaultAccessTokenPath
        self.audience = audience ?? ""
        self.endpoint = endpoint ?? defaultGCPMetadataEndpoint
        self.identityTokenPath = identityTokenPath ?? defaultIdentityTokenPath
        self.scopes = scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let accessTokenPath =
            try container.decodeIfPresent(String.self, forKey: .accessTokenPath)
        self.accessTokenPath = accessTokenPath ?? defaultAccessTokenPath

        self.audience = try container.decodeIfPresent(String.self, forKey: .audience)

        let endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint)
        self.endpoint = endpoint ?? defaultGCPMetadataEndpoint

        let identityTokenPath =
            try container.decodeIfPresent(String.self, forKey: .identityTokenPath)

        self.identityTokenPath = identityTokenPath ?? defaultIdentityTokenPath
        self.scopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []

        guard !(self.audience == nil && self.scopes.count == 0) else {
            throw DecodingError.dataCorruptedError(
                forKey: .audience,
                in: container,
                debugDescription: "audience or scopes is required when gcp metadata is enabled"
            )
        }

        guard !(self.audience != nil && self.scopes.count > 0) else {
            throw DecodingError.dataCorruptedError(
                forKey: .audience,
                in: container,
                debugDescription: "either audience or scopes can be set, not both, when gcp metadata is enabled"
            )
        }
    }
}
