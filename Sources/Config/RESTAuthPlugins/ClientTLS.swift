import Foundation

// MARK: - Client TLS Authentication Plugin
// From: v1/plugins/rest/auth.go

/// Authentication via client certificate on a TLS connection
public struct ClientTLSAuthPlugin: Codable, Equatable {
    public let cert: String
    public let privateKey: String
    public let privateKeyPassphrase: String?
    /// Deprecated: Use `services[_].tls.ca_cert` instead
    public let caCert: String?
    /// Deprecated: Use `services[_].tls.system_ca_required` instead
    public let systemCARequired: Bool?

    public init(
        cert: String,
        privateKey: String,
        privateKeyPassphrase: String? = nil,
        caCert: String? = nil,
        systemCARequired: Bool? = nil
    ) {
        self.cert = cert
        self.privateKey = privateKey
        self.privateKeyPassphrase = privateKeyPassphrase
        self.caCert = caCert
        self.systemCARequired = systemCARequired
    }

    private enum CodingKeys: String, CodingKey {
        case cert
        case privateKey = "private_key"
        case privateKeyPassphrase = "private_key_passphrase"
        case caCert = "ca_cert"
        case systemCARequired = "system_ca_required"
    }
}
