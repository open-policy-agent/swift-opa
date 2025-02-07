import Benchmark
import Foundation
import AST

struct InMemFile: Sendable, Hashable, Comparable {
    static func < (lhs: InMemFile, rhs: InMemFile) -> Bool {
        return lhs.url.path < rhs.url.path
    }
    
    let url: URL
    let data: Data
}

func loadJsonFixtures() throws -> [InMemFile] {
    let files = Bundle.module.urls(
        forResourcesWithExtension: "json",
        subdirectory: "TestData"
    )!
    
    var out: [InMemFile] = []
    for url in files {
        let d = try Data(contentsOf: url)
        out.append(InMemFile(url: url, data: d))
    }
    return out
}

private enum SetupError: Error {
    case failedToLoadFixtures
}

nonisolated(unsafe) let benchmarks = {
    let fixtures = try! loadJsonFixtures()
    for f in fixtures.sorted() {
        Benchmark("Codable deserialize \(f.url.lastPathComponent)") { benchmark, setupState in
            for _ in benchmark.scaledIterations {
                blackHole(
                    try JSONDecoder().decode(AST.RegoValue.self, from: setupState.data)
                )
            }
        } setup: {
            return f
        }
        
        Benchmark("JSONSerialize deserialize \(f.url.lastPathComponent)") { benchmark, setupState in
            for _ in benchmark.scaledIterations {
                blackHole(
                    try AST.RegoValue(fromJson: setupState.data)
                )
            }
        } setup: {
            return f
        }
    }
    
    // Add additional benchmarks here
}
