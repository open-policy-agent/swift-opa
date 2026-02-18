// This file contains struct definitions for parsing the
// `services` section of an OPA configuration file.
// See: https://www.openpolicyagent.org/docs/configuration#services
import Foundation

// MARK: - REST Client Configuration
// From: v1/plugins/rest/rest.go

/// Configuration for a REST client service
public struct RestClientServiceConfig: Codable, Equatable {
    public let name: String
    public let url: URL
    public let headers: [String: String]?
    public let allowInsecureTLS: Bool?
    public let responseHeaderTimeoutSeconds: Int64?
    public let tls: ServerTLSConfig?
    public let credentials: Credentials?
    public let type: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case url
        case headers
        case allowInsecureTLS = "allow_insecure_tls"
        case responseHeaderTimeoutSeconds = "response_header_timeout_seconds"
        case tls
        case credentials
        case type
    }

    public init(
        name: String,
        url: URL,
        headers: [String: String]? = nil,
        allowInsecureTLS: Bool? = nil,
        responseHeaderTimeoutSeconds: Int64? = nil,
        tls: ServerTLSConfig? = nil,
        credentials: Credentials? = nil,
        type: String? = nil
    ) {
        self.name = name
        self.url = url
        self.headers = headers
        self.allowInsecureTLS = allowInsecureTLS
        self.responseHeaderTimeoutSeconds = responseHeaderTimeoutSeconds
        self.tls = tls
        self.credentials = credentials
        self.type = type
    }

    // MARK: - Credentials (tagged union)

    /// Credentials represents the default set of REST client credential
    /// options supported by OPA for fetching bundles from remote sources.
    ///
    /// If a custom plugin name is provided, there won't be any associated
    /// config keys in this section-- any configuration will appear under the
    /// `plugins` section.
    public enum Credentials: Codable, Equatable {
        case bearer(BearerAuthPlugin)
        case oauth2([String: AnyCodable])
        case clientTLS(ClientTLSAuthPlugin)
        case s3Signing([String: AnyCodable])
        case gcpMetadata(GCPMetadataAuthPlugin)
        case azureManagedIdentity(AzureManagedIdentitiesAuthPlugin)
        case custom(String)

        private enum CodingKeys: String, CodingKey {
            case bearer
            case oauth2
            case clientTLS = "client_tls"
            case s3Signing = "s3_signing"
            case gcpMetadata = "gcp_metadata"
            case azureManagedIdentity = "azure_managed_identity"
            case custom = "plugin"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Check if plugin field is present.
            if let pluginName = try container.decodeIfPresent(String.self, forKey: .custom) {
                self = .custom(pluginName)
            } else {
                // Fall back to trying each credential type.
                let attemptedCredentialTypes: [Credentials?] = [
                    try? container.decodeIfPresent(BearerAuthPlugin.self, forKey: .bearer).map { .bearer($0) },
                    try? container.decodeIfPresent([String: AnyCodable].self, forKey: .oauth2).map { .oauth2($0) },
                    try? container.decodeIfPresent(ClientTLSAuthPlugin.self, forKey: .clientTLS).map { .clientTLS($0) },
                    try? container.decodeIfPresent([String: AnyCodable].self, forKey: .s3Signing).map {
                        .s3Signing($0)
                    },
                    try? container.decodeIfPresent(GCPMetadataAuthPlugin.self, forKey: .gcpMetadata).map {
                        .gcpMetadata($0)
                    },
                    try? container.decodeIfPresent(AzureManagedIdentitiesAuthPlugin.self, forKey: .azureManagedIdentity)
                        .map {
                            .azureManagedIdentity($0)
                        },
                ]

                let foundCredentials = attemptedCredentialTypes.compactMap { $0 }

                guard foundCredentials.count == 1 else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: container.codingPath,
                            debugDescription: foundCredentials.isEmpty
                                ? "No valid credential type found"
                                : "Expected exactly one credential type, but found \(foundCredentials.count)"
                        )
                    )
                }

                self = foundCredentials[0]
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .bearer(let plugin):
                try container.encode(plugin, forKey: .bearer)
            case .oauth2(let config):
                try container.encode(config, forKey: .oauth2)
            case .clientTLS(let plugin):
                try container.encode(plugin, forKey: .clientTLS)
            case .s3Signing(let config):
                try container.encode(config, forKey: .s3Signing)
            case .gcpMetadata(let config):
                try container.encode(config, forKey: .gcpMetadata)
            case .azureManagedIdentity(let config):
                try container.encode(config, forKey: .azureManagedIdentity)
            case .custom(let plugin):
                try container.encode(plugin, forKey: .custom)
            }
        }
    }
}

// MARK: - Server TLS Configuration
// From: v1/plugins/rest/auth.go

public struct ServerTLSConfig: Codable, Equatable {
    public let caCert: String?
    public let systemCARequired: Bool?

    public init(
        caCert: String? = nil,
        systemCARequired: Bool? = nil
    ) {
        self.caCert = caCert
        self.systemCARequired = systemCARequired
    }

    private enum CodingKeys: String, CodingKey {
        case caCert = "ca_cert"
        case systemCARequired = "system_ca_required"
    }
}

// MARK: - AnyCodable Helper

/// A type-erased Codable value.
/// We should be able to remove this once we finish plumbing in Config types.
public struct AnyCodable: Codable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch lhs.value {
        case let bool as Bool:
            return bool == (rhs.value as? Bool)
        case let int as Int:
            return int == (rhs.value as? Int)
        case let double as Double:
            return double == (rhs.value as? Double)
        case let string as String:
            return string == (rhs.value as? String)
        case let array as [Any]:
            guard let rhsArray = rhs.value as? [Any] else { return false }
            return array.count == rhsArray.count
                && zip(array, rhsArray).allSatisfy {
                    AnyCodable($0) == AnyCodable($1)
                }
        case let dict as [String: Any]:
            guard let rhsDict = rhs.value as? [String: Any] else { return false }
            guard dict.keys.count == rhsDict.keys.count else { return false }
            return dict.keys.allSatisfy { key in
                guard let lhsValue = dict[key], let rhsValue = rhsDict[key] else { return false }
                return AnyCodable(lhsValue) == AnyCodable(rhsValue)
            }
        case is NSNull:
            return rhs.value is NSNull
        default:
            return false
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues(\.value)
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
