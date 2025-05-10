// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

let swiftOpaDependencyPath = ProcessInfo.processInfo.environment["SWIFT_OPA_DEPENDENCY_PATH"] ?? "../"

let package = Package(
    name: "RegoCompliance",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RegoCompliance",
            targets: ["RegoCompliance"])
    ],
    dependencies: [
        .package(path: swiftOpaDependencyPath)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RegoCompliance",
            dependencies: [
                .product(name: "SwiftOPA", package: "swift-opa")
            ]
        ),
        .testTarget(
            name: "RegoComplianceTests",
            dependencies: [
                "RegoCompliance"
            ],
            resources: [.copy("TestData")]
        ),
    ]
)
