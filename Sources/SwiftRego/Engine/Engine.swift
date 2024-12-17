import Foundation

struct Engine {

    // TODO when is the right time for this loading to happen?
    func load(withBundleLoader bundleLoader: BundleLoader) async throws {

    }

    func evaluate(withContext ctx: EvaluationContext = EvaluationContext()) async throws
        -> ResultSet
    {
        return ResultSet()
    }

    //    func
}
