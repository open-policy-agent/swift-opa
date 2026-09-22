# Notable rationale of Swift OPA

*This file tracks the reasoning behind some of the design and implementation decisions we've made across the project's lifetime.*


## Dependencies

### Why are almost all external dependencies gated behind package traits?

Some of our earliest users wanted *just* the Rego IR VM, and nothing more.
To keep those folks happy while allowing us to offloag some of the development and maintenance work for more advanced features, we've adopted an approach of gating new external package dependencies behind package traits.


## Project structure

### Why do we use a custom macro (`tools/SyncGen`) in parts of the VM?

Performance. The only reason the VM core started `async` was because some builtins (like `http.send`) are, by nature, asynchronous.
However, all builtins in the project today have synchronous implementations.

Async is not free in Swift, and so in #136 we created sync and async variants of almost all major parts of the VM core, and added a static analysis pass to the VM for evaluating "sync-safety" in Rego IR policies.
The sync-safety checks allow the VM core to dispatch into `async` paths *only* for the policy parts that use `async` builtins, and keeps evaluation on the more efficient sync paths the rest of the time.

To make the sync/async variants maintainable, we added a codegen macro that creates sync variants of all of the existing `async` VM machinery, so we only have to write the `async` side of the VM.
This is what the custom macro package under `tools/SyncGen` is for-- it creates synchronous copies of annotated funcs, to make the VM's internals easier to maintain over time.

To ensure that contributors don't accidentally modify something in the VM core and forget to run the macro, we run the macro manually in CI and fail the build if a diff is detected.

#### Why codegen and not compile-time macros?

We want downstream users of the library to not need weird dependencies just to build the project.
Codegen at development time is ugly, but achieves this goal.

Compile-time macros would require library users to pull in `swift-syntax`.
Swift Syntax releases a new major version with every Swift release, which means with every Swift release we have to update its version range in our `Package.swift` and ensure it works across all the Swift Syntax versions.
For an infrequently-used development tool, we feel this is a reasonable hassle for *us* to deal with, but unreasonable for downstream users to have to grapple with.


## API Design
