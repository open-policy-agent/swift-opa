import Foundation

public struct Engine {
    // TODO bundles here on the engine or on the EvaluationContext?
    var bundles: [String: Bundle]

    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        return ResultSet()
    }
}
