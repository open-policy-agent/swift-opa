import AST
import Foundation

struct Bundle: Equatable, Sendable {
    var manifest: Manifest = Manifest()
    var planFiles: [BundleFile] = []
    var regoFiles: [BundleFile] = []
    var data: AST.RegoValue = .object([:])
}

struct Manifest: Equatable, Sendable {
    var revision: String = ""
    var roots: [String] = [""]
    var regoVersion: Version = .regoV1
    var metadata: [String: AST.RegoValue] = [:]

    enum Version: Int {
        case regoV0 = 0
        case regoV1 = 1
    }
}

extension Manifest {
    init(from jsonData: Data) throws {
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let jsonDict = jsonObject as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON format"))
        }

        let revision = jsonDict["revision"] as? String ?? ""
        self.revision = revision

        var roots = jsonDict["roots"] as? [String] ?? [""]
        if roots.isEmpty {
            roots = [""]
        }
        self.roots = roots

        let regoVersionInt = jsonDict["rego_version"] as? Int ?? 1
        self.regoVersion =
            switch regoVersionInt {
            case 0:
                .regoV0
            case 1:
                .regoV1
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [], debugDescription: "Unsupported Rego version"))
            }

        guard let metadataAny = jsonDict["metadata"] else {
            // No metadata, use default
            self.metadata = [:]
            return
        }

        // Parse metadata
        let metadataValue = try AST.RegoValue(from: metadataAny)
        guard case .object(let metadataDict) = metadataValue else {
            throw DecodingError.typeMismatch(
                [String: AST.RegoValue].self,
                DecodingError.Context(
                    codingPath: [CodingKeys.metadata], debugDescription: "Invalid metadata value"))
        }
        self.metadata = metadataDict
    }

    enum CodingKeys: String, CodingKey {
        case revision = "revision"
        case roots = "roots"
        case regoVersion = "rego_version"
        case metadata = "metadata"
    }
}

struct BundleFile: Sendable, Hashable {
    let url: URL
    let data: Data
}
