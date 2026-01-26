# Swift-OPA

[![Swift 6.0.3+](https://img.shields.io/badge/Swift-6.0.3+-blue.svg)](https://developer.apple.com/swift/)

Swift-OPA is a Swift package for evaluating [OPA IR
Plans](https://www.openpolicyagent.org/docs/latest/ir/) compiled from
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/#what-is-rego)
policies.

Rego is a declarative language for expressing policy over structured data. A
common use of Rego is for defining authorization policy.
Swift-OPA allows for in-process evaluation of compiled Rego within a Swift-based service or application.

## Prerequisites

### A Rego Policy

For our example application, we'll use this simple policy:

**policy.rego**
```rego
package policy.main

default is_valid := false

# METADATA
# entrypoint: true
is_valid := true if {
    input.favorite_fruit == "apple"
}
```

The `entrypoint` annotation allows us to define in policy where plan evaluation should begin. This serves
both as documentation as well as it lets us skip providing the `--entrypoint` flag in the next step, where
we build a plan bundle.

### Building a Plan Bundle

In order to evaluate a plan bundle, we first have to build one! For that we'll use the `opa build` command with a
`target` set to `plan`:

```shell
opa build --bundle --target plan my_bundle_directory
```

This will provide us a `bundle.tar.gz` file in the directory in which the command is executed, or optionally where the
`--output` argument points to. Note that at this point, swift-opa
[can't parse](https://github.com/open-policy-agent/swift-opa/issues/28) `.tar.gz` files directly. For now, we'll have
to first extract its contents into a directory:

```shell
tar -xvf bundle.tar.gz
```

## Adding Swift-OPA as a Dependency

**Package.swift**
```swift
let package = Package(
    // required minimum versions for using swift-opa
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    // name, platforms, products, etc.
    dependencies: [
        .package(url: "https://github.com/open-policy-agent/swift-opa", branch: "main"),
        // other dependencies
    ],
    targets: [
        // or libraryTarget
        .executableTarget(name: "<target-name>", dependencies: [
            .product(name:"SwiftOPA", package: "swift-opa"),
            // other dependencies
        ]),
        // other targets
    ]
)
```

## Usage

The main entry point for policy evaluation is the `OPA.Engine`. An engine can evaluate policies packaged in one or more
`Bundles`. An `OPA.Engine` can be initialized with an on-disk bundle using its constructor: `init(bundlePaths:)`. Using
a simple `main.swift` file for the purpose of demonstration:

**main.swift**
```swift
import Rego
import Foundation

// Prepare does as much pre-processing as possible to get ready to evaluate queries.
// This only needs to be done once when loading the engine and after updating it.
func prepare() async throws -> OPA.Engine.PreparedQuery {
    let bundlePath = OPA.Engine.BundlePath(
        name: "policyBundle", url: URL(fileURLWithPath: "path/to/bundle"))

    var regoEngine = OPA.Engine(bundlePaths: [bundlePath])

    // Prepare query for the 'is_valid' rule in the 'policy.main' package
    return try await regoEngine.prepareForEvaluation(query: "data.policy.main.is_valid")
}

// This prepared query can be reused
let preparedQuery = try await prepare()
```

Policies often expect an `input` document to be passed in. This can be parsed from JSON data, for example:

```swift
import AST

// ...

let rawInput = #"{"favorite_fruit": "apple"}"#.data(using: .utf8)!
let inputDocument = try AST.RegoValue(jsonData: rawInput)
```

Evaluation is performed using the prepared query. We used `data.policy.main.is_valid` above, which makes sense given our
policy source. Putting it all together, we can now evaluate our query and interpret the results, in this case just
printing them:

```swift
let resultSet = try await preparedQuery.evaluate(input: inputDocument)

print(try resultSet.jsonString)
```

### Complete Example

For the copy-paste inclined.

**main.swift**
```swift
import AST
import Rego
import Foundation

// Prepare does as much pre-processing as possible to get ready to evaluate queries.
// This only needs to be done once when loading the engine and after updating it.
func prepare() async throws -> OPA.Engine.PreparedQuery {
    let bundlePath = OPA.Engine.BundlePath(
        name: "policyBundle", url: URL(fileURLWithPath: "path/to/bundle"))

    var regoEngine = OPA.Engine(bundlePaths: [bundlePath])

    // Prepare query for the 'is_valid' rule in the 'policy.main' package
    return try await regoEngine.prepareForEvaluation(query: "data.policy.main.is_valid")
}

// This prepared query can be reused
let preparedQuery = try await prepare()

let rawInput = #"{"favorite_fruit": "apple"}"#.data(using: .utf8)!
let inputDocument = try AST.RegoValue(jsonData: rawInput)

let resultSet = try await preparedQuery.evaluate(input: inputDocument)

print(try resultSet.jsonString)
```

### Capabilities and Builtins

- [Builtins](https://www.openpolicyagent.org/docs/policy-reference/builtins) are the standard and custom functions available to Rego (e.g. `count`, `concat`, etc.). The engine comes with the default OPA builtins enabled.
- You can optionally supply an OPA [`capabilities.json`](https://www.openpolicyagent.org/docs/deployments#capabilities) (from an OPA release) upon the `OPA.Engine` init via `capabilities: .path(...)`. During `prepareForEvaluation`, the engine checks that all builtins required by your compiled policies are present in the capabilities file (including matching signatures). If no capabilities are specified, validation is skipped and execution proceeds normally.
- The engine also checks that every required builtin by the compiled policy is present in the Swift implementation, matched by its name (default or custom builtin). This check runs independently of capabilities validation. Signature correctness is enforced by OPA’s capabilities (if specified); Swift builtin closures validate arguments only at runtime. 

### Adding Custom Builtins

One can also [register custom builtins](https://www.openpolicyagent.org/docs/extensions) when creating the `OPA.Engine`, in addition to the default OPA builtins provided by `swift-opa`.
Conflicts with default builtin names are validated during `prepareForEvaluation(query:)`. 
If capabilities are provided, the custom builtins are validated against the specified capabilities file.

```swift
import AST

let customBuiltins: [String: Builtin] = [
    "my.slugify": { ctx, args in
        // Example: expect a single string argument and return a slug
        guard args.count == 1, case let .string(s) = args[0] else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let slug = s.lowercased().replacingOccurrences(of: " ", with: "-")
        return .string(slug)
    }
]

var engine = OPA.Engine(
    bundlePaths: [bundlePath],
    // To enable builtin validation, provide a `capabilities.json`. Without it, builtins are not checked against capabilities.
    // capabilities: .path(capabilitiesURL),
    customBuiltins: customBuiltins
)

// Throws if a custom builtin name conflicts with a default or a builtin required by the compiled policy is not present.
// If capabilities are specified, this throws if a capabilities validation error against the builtins occurs.
let preparedQuery = try await engine.prepareForEvaluation(query: "<some_query>")
```

## Community Support

Feel free to open and issue if you encounter any problems using swift-opa, or have ideas on how to make it even better.
We are also happy to answer more general questions in the #swift-opa channel of the
[OPA Slack](https://slack.openpolicyagent.org/).
