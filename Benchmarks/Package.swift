// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-opa-benchmarks",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(name: "swift-opa", path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "RegoBenchmarks",
            dependencies: [
                .product(name: "SwiftOPA", package: "swift-opa"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)