# Change Log

All notable changes to this project will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

## 0.0.2

This release contains bugfixes, performance improvements for the IR evaluator, and several new builtins!

## Performance improvements

The IR evaluator is now more efficient when creating aggregate Rego values. (#101, authored by @koponen)
In particular, `ArrayAppend`, `ObjectInsert`/`ObjectInsertOnce`, and `SetAdd` IR instructions run around 7-11% faster and allocate less memory in our benchmarks.

We also now use a new `RegoNumber` type internally which allows the interpreter to swap out the representations of numeric types for better performance. (#51, authored by @koponen)
Previously we used `NSNumber` everywhere, and this had a noticeable negative performance impact for some benchmarks.
Using the `RegoNumber` type, we have seen improvements across all benchmarks, ranging from 1-35% speedups.
Most testcases involving numeric literals see an 18% or greater speedup.

### `walk` builtin (#93)

The [`walk` builtin](https://www.openpolicyagent.org/docs/policy-reference/builtins/graph#builtin-graph-walk) is now supported in Swift OPA.
`walk` transforms any Rego aggregate datatype into a list of `[path, value]` tuples.
It is often used to work around cases where one might use recursion in other programming languages.

Here is an example that sums the leaf nodes on a nested object using `walk`:

`policy.rego`:
```rego
package walk_example

# Sum up all "var": <number> leaves in the tree
var_leaves contains val if {
	some path, val
	walk(input, [path, val])

	# The last element of the path must be the key "var"
	path[count(path) - 1] == "var"

	# Ensure the value is a number
	is_number(val)
}

total := sum(var_leaves)
```

`input.json`:
```json
{
  "a": { "b": { "c": { "var": 2 } } },
  "d": { "e": { "var": 1 } },
  "f": { "var": 3 },
  "g": { "var": "foo" }
}
```

Results:
```json
{
    "total": 6,
    "var_leaves": [
        1,
        2,
        3
    ]
}
```

Authored by @philipaconrad

### `json` encoding builtins (#98)

Swift OPA has recently added support for the following `json` builtins:

 - [`json.is_valid`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-jsonis_valid)
 - [`json.marshal`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-jsonmarshal)
 - [`json.unmarshal`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-jsonunmarshal)

These builtins make working with JSON data much more convenient.

Authored by @philipaconrad

### `time.add_date` builtin (#117)

The `time.add_date` builtin returns the nanoseconds since the epoch after adding years, months, and days to a given nanoseconds timestamp.

Example policy:
```
package time_add_example

ts_ns_1980 := 315532800000000000                            # Tue Jan 01 00:00:00 1980 UTC
ts_ns_nov_12_1990 := time.add_date(ts_ns_1980, 10, 10, 11)  # Wed Nov 12 00:00:00 1990 UTC
```

Authored by @DFrenkel

### Miscellaneous

 - AST/RegoValue+Codable: Change decoding order for strings. (#97) authored by @philipaconrad
 - deps: Bump swift-crypto to pick up newer APIs. (#108) authored by @philipaconrad
 - ComplianceTests: Override package name for local Swift OPA dep. (#111) authored by @philipaconrad
 - ComplianceTests: Add make command to generate new compliance tests (#90) authored by @sspaink
 - gh: Add PR template. (#96) authored by @philipaconrad
 - ci: Harden CI + Add zizmor static analysis for GH Actions (#99) authored by @philipaconrad
 - ci: Add dependabot.yml config for GH Actions and Go version bumps. (#94) authored by @philipaconrad
 - ci: add Linux test runs (#92) authored by @srenatus
 - ci: Fix missing checkout step for post-tag workflow. (#88) authored by @philipaconrad
 - ci: Fix issue in release detection script. (#87) authored by @philipaconrad


## 0.0.1

This release is a release engineering experiment, designed to test out our Github Release automation workflows.

In future release notes, we will discuss significant change to the project since the last release.
Thank you for reading!

