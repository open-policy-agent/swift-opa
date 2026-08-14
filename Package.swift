// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

let package = Package(
    name: "swift-opa",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
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
    traits: [
        // Enabled by default. Library-only consumers can opt out to drop optional
        // features and dependencies from the build.
        .default(enabledTraits: ["CLI", "YAML"]),
        Trait(
            name: "CLI",
            description: "Builds the swift-opa-cli executable and its dependencies."
        ),
        Trait(
            name: "YAML",
            description: "Builds the yaml.* builtins and their Yams dependency."
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.1"),
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
                .product(name: "Yams", package: "Yams", condition: .when(traits: ["YAML"])),
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
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser",
                    condition: .when(traits: ["CLI"])
                ),
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
