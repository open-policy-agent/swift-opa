import Foundation

protocol BundleLoader {
    func load() async throws -> Bundle
}

// InMemBundleLoader implements BundleLoader over an in-memory bundle representation
struct InMemBundleLoader: BundleLoader {
    let policy: Policy
    let data: types.ObjectType

    func load() async throws -> Bundle {
        return Bundle(policy: policy, data: data)
    }
}

extension InMemBundleLoader {
    init(policyFromJson policyData: Data, dataFromJson data: Data) throws {
        // TODO wrap errors
        self.policy = try JSONDecoder().decode(Policy.self, from: policyData)
        self.data = try JSONDecoder().decode(types.ObjectType.self, from: data)
    }
}

struct Bundle {
    let policy: Policy
    let data: types.ObjectType
}
