# Open Policy Kit (Swift Rego)

Swift Rego is a Swift package for evaluating [OPA IR
Plans](https://www.openpolicyagent.org/docs/latest/ir/) compiled from
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/#what-is-rego)
declarative policy.

Rego is a declarative language for expressing policy over structured data. A
common use of Rego is for defining authorization policy.
Swift Rego allows for in-process evaluation of compiled Rego within a Swift-based service or application.

## Adding Swift-Rego as a Dependency

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/open-policy-agent/swift-rego"),
    ],
    targets: [
        .[executable|library]Target(name: "<target-name>", dependencies: [
            // other dependencies
            .product(name:"SwiftRego", package: "swift-rego"),
        ]),
        // other targets
    ]
)
```

## Usage

The main entry point for policy evaluation is the `Engine`. An engine can evaluate policies packaged in one or more `Bundles`.
An `Engine` can be initialized with an on-disk bundle using its constructor: `init(withBundlePaths:)`:

```swift
import Rego

...

let path = "some/local/path"
let bundlePath = Rego.Engine.BundlePath(name: "policyBundle", url: URL(fileURLWithPath: path)
var regoEngine = try Rego.Engine(withBundlePaths: [bundlePath])

// Prepare does as much pre-processing as possible to get ready to evaluate queries.
// This only needs to be done once when loading the engine and after updating it.
// PreparedQuery's can be re-used.
let preparedQuery = try await regoEngine.prepareForEval(query: self.evalOptions.query)
```

Policies often expect an `input` document to be passed in. This can be parsed from JSON data:

```
import AST

let inputDocument = try AST.RegoValue(fromJson: data)
```

Evaluation is performed by providing a query. For example, given the following policy:

```rego
package policy.main

default is_valid := false
is_valid := true if {
    ...
}
```

... we could query `data.policy.main.is_valid`.


Putting it all together, we can evaluate our query:

```
let resultSet = try await preparedQuery.evaluate(
    query: queryString,
    input: inputDocument
)
```
