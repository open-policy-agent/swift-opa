import AST
import Foundation

struct Bundle {
    let manifest: Manifest
    let planFiles: [BundleFile]
    let data: AST.RegoValue
}

struct Manifest: Equatable, Sendable {
    let revision: String
    let roots: [String]?
    let regoVersion: Version
    let metadata: [String: AST.RegoValue]

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

        guard let revision = jsonDict["revision"] as? String else {
            throw DecodingError.keyNotFound(
                CodingKeys.revision,
                DecodingError.Context(
                    codingPath: [CodingKeys.revision],
                    debugDescription: "Missing required field 'revision'"))
        }
        self.revision = revision

        // TODO is roots optional??
        guard let roots = jsonDict["roots"] as? [String] else {
            throw DecodingError.keyNotFound(
                CodingKeys.roots,
                DecodingError.Context(
                    codingPath: [CodingKeys.roots],
                    debugDescription: "Missing required field 'roots'"))
        }
        self.roots = roots

        let regoVersion = jsonDict["rego_version"] as? Int ?? 1
        self.regoVersion =
            switch regoVersion {
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
            self.metadata = [:]
            return
        }

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

struct BundleFile: Sendable {
    let url: URL
    let data: Data
}
