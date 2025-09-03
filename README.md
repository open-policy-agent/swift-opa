# Swift-OPA

Swift-OPA is a Swift package for evaluating [OPA IR
Plans](https://www.openpolicyagent.org/docs/latest/ir/) compiled from
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/#what-is-rego)
policies.

Rego is a declarative language for expressing policy over structured data. A
common use of Rego is for defining authorization policy.
Swift-OPA allows for in-process evaluation of compiled Rego within a Swift-based service or application.

## Adding Swift-OPA as a Dependency

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/open-policy-agent/swift-opa", branch: "main"),
    ],
    targets: [
        .[executable|library]Target(name: "<target-name>", dependencies: [
            // other dependencies
            .product(name:"SwiftOPA", package: "swift-opa"),
        ]),
        // other targets
    ]
)
```

## Usage

The main entry point for policy evaluation is the `OPA.Engine`. An engine can evaluate policies packaged in one or more `Bundles`.
An `OPA.Engine` can be initialized with an on-disk bundle using its constructor: `init(bundlePaths:)`:

```swift
import Rego
import Foundation

// ...

let path = "some/local/path"
let bundlePath = OPA.Engine.BundlePath(name: "policyBundle", url: URL(fileURLWithPath: path))
var regoEngine = OPA.Engine(bundlePaths: [bundlePath])

// Prepare does as much pre-processing as possible to get ready to evaluate queries.
// This only needs to be done once when loading the engine and after updating it.
// PreparedQuery's can be re-used.
let rawQuery = "data.policy.main.is_valid"
let preparedQuery = try await regoEngine.prepareForEvaluation(query: rawQuery)
```

Policies often expect an `input` document to be passed in. This can be parsed from JSON data, for example:

```swift
import AST

// ...

let rawInput = #"{"favorite_fruit": "apple"}"#.data(using: .utf8)!
let inputDocument = try AST.RegoValue(jsonData: rawInput)
```

Evaluation is performed with the prepared query. We used `data.policy.main.is_valid` above, which makes sense given our policy source:

```rego
package policy.main

default is_valid := false
is_valid := true if {
    input.favorite_fruit == "apple"
}
```

Putting it all together, we can evaluate our query and interpret the results, in this case just printing them:

```swift
let resultSet = try await preparedQuery.evaluate(
    input: inputDocument
)

print(try resultSet.jsonString)
```
