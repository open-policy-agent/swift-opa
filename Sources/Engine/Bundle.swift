import AST
import Foundation

struct Bundle {
    let manifest: Manifest
    let planFiles: [BundleFile]
    let data: AST.RegoValue
}

struct Manifest: Equatable, Sendable {
    let revision: String
    let roots: [String]
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

        let revision = jsonDict["revision"] as? String ?? ""

        let roots = jsonDict["roots"] as? [String] ?? [""]

        let regoVersionProp = jsonDict["rego_version"] as? Int ?? 1
        let regoVersion: Version =
            switch regoVersionProp {
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
            self.init(revision: revision, roots: roots, regoVersion: regoVersion, metadata: [:])
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
        
        self.init(revision: revision, roots: roots, regoVersion: regoVersion, metadata: metadataDict)
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
