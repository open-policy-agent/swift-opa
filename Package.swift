// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

let package = Package(
    name: "swift-opa",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftOPA",
            targets: ["SwiftOPA"]),
        .executable(
            name: "swift-opa-cli",
            targets: ["CLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftOPA",
            dependencies: ["AST", "IR", "Bytecode", "Rego"]
        ),
        .target(name: "AST"),
        .target(
            name: "IR",
            dependencies: ["AST"]
        ),
        .target(
            name: "Bytecode",
            dependencies: ["AST", "IR"]
        ),
        .target(
            name: "Rego",
            dependencies: [
                "AST",
                "IR",
                "Bytecode",
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ]
        ),
        // Internal module tests
        .testTarget(
            name: "ASTTests",
            dependencies: ["AST"]
        ),
        .testTarget(
            name: "IRTests",
            dependencies: ["AST", "IR"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "BytecodeTests",
            dependencies: ["AST", "IR", "Bytecode"]
        ),
        .testTarget(
            name: "RegoTests",
            dependencies: ["Rego"],
            resources: [.copy("TestData")]
        ),
        // Public API surface tests
        .testTarget(
            name: "SwiftOPATests",
            dependencies: ["SwiftOPA"]
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

// If the `SWIFT_OPA_ALLOW_SWIFT_CRYPTO_BETA` environment variable is set
// swift-opa will accept swift-crypto beta releases as a dependency.
//
// Note: A beta release can only be used if other packages in the dependency tree
// that have a direct dependency on swift-crypto accept beta releases as well.
if ProcessInfo.processInfo.environment["SWIFT_OPA_ALLOW_SWIFT_CRYPTO_BETA"] == nil {
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"5.0.0")
    ]
} else {
    print("Accepting beta versions of swift-crypto!")
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0"..<"5.0.0-beta.max")
    ]
}
