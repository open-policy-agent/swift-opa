// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

let package = Package(
    name: "SwiftRego",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftRego",
            targets: ["SwiftRego"]),
        .executable(
            name: "swift-rego-cli",
            targets: ["CLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"4.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftRego",
            dependencies: ["AST", "IR", "Runtime", "Rego"]
        ),
        .target(name: "AST"),
        .target(name: "IR"),
        .target(
            name: "Rego",
            dependencies: [
                "AST",
                "IR",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ]
        ),
        .target(
            name: "Runtime",
            dependencies: ["AST"]),
        // Internal module tests
        .testTarget(
            name: "ASTTests",
            dependencies: ["AST"]
        ),
        .testTarget(
            name: "IRTests",
            dependencies: ["IR"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "RegoTests",
            dependencies: ["Rego"],
            resources: [.copy("TestData")]
        ),
        // Public API surface tests
        .testTarget(
            name: "SwiftRegoTests",
            dependencies: ["SwiftRego"]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: [
                "Rego",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)

// Workaround to jemalloc build failures in Xcode - we'll need to explicitly
// enable benchmarks with OPA_BENCHMARK=enabled from CLI to use.
if ProcessInfo.processInfo.environment["OPA_BENCHMARK"] != nil {
    package.dependencies += [
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0"))
    ]
    package.targets += [
        .executableTarget(
            name: "RegoBenchmarks",
            dependencies: [
                "AST",
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/RegoBenchmarks",
            resources: [.copy("TestData")],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
}
