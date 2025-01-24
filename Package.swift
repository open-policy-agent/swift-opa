// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRego",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftRego",
            targets: ["SwiftRego"])
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
            dependencies: ["AST", "IR"]),
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
            name: "EngineTests",
            dependencies: ["Rego"],
            resources: [.copy("TestData")]
        ),
        // Public API surface tests
        .testTarget(
            name: "SwiftRegoTests",
            dependencies: ["SwiftRego"]
        ),
    ]
)
