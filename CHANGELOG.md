# Change Log

All notable changes to this project will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

### Improved plan validation in Engine

The `Engine` now validates that plans are contained under the roots of their parent bundles.
We also now support loading user-provided raw IR policies alongside bundles.
The improved validation ensures that plan names are unique across all sources, and that user-supplied plans don't conflict with plans or paths under the roots of any bundles.

The new validation is done at `prepareForEvaluation` time, and will throw descriptive errors if anything is amiss.

### Improved store behavior

In previous versions, the `Engine` would wipe out the store on each call to `prepareForEvaluation`, and would write only bundle contents back into the store.
This was acceptable for bundle-centric workflows, but limited many other use cases OPA supports.

We now modify the store at `prepareForEvaluation` in a manner much closer to OPA's bundle activation flow.
First, all old bundle roots are erased.
Then, all new/retained bundle roots are written to, ensuring the live set of bundles will always have consistent state written to the store.
Any user-modified locations in the store that are outside of those paths will be unmodified.

### `OPA.Store` protocol gains `remove(at:)`

The `OPA.Store` protocol now requires `mutating func remove(at: StoreKeyPath) async throws`.
This method removes the value at the given path, including the leaf key from its parent object.
A non-existent path is a no-op.
Removing the root path resets the store to an empty object.

This new API moves us closer to supporting the range of store functionality that OPA provides.

Authored by @philipaconrad

## 0.0.5

This release contains bugfixes for multi-bundle use cases, performance improvements, and new builtin implementations!

### `strings.any_prefix_match`, `strings.any_suffix_match`, `strings.replace_n`, and `strings.render_template` functions (#135)

Swift OPA now supports several new `strings` builtins:
 - [`strings.any_prefix_match`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-stringsany_prefix_match)
 - [`strings.any_suffix_match`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-stringsany_suffix_match)
 - [`strings.replace_n`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-stringsreplace_n)
 - [`strings.render_template`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-stringsrender_template)

These builtins provide powerful new string match and formatting capabilities.

Authored by @DFrenkel

### Better support for multi-bundle data merge (#139)

The `Engine` now correctly merges together data trees from separate bundles, and properly supports separate data and policy bundles.
Before, it was possible for two bundles to overwrite each other's data sub-trees, and no validation was done at runtime to confirm that a bundle actually had its data contained properly under its declared roots.

Both issues were fixed by adding the needed validation checks and updated merge logic to `Engine.prepareForEvaluation`.

Authored by @philipaconrad

### Performance improvements (#141)

In this release, `Engine.prepareForEvaluation` now caches validation work done on the set of loaded bundles.
We validate both that bundles' data is fully contained under their declared roots, and that bundle roots do not conflict with each other.
The cache allows skipping redundant validation work when many queries need to be prepared on the same set of bundles.

Authored by @philipaconrad

### Miscellaneous

 - perf: fix benchmark bundle path and surface prepareForEvaluation errors (#133) authored by @koponen


## 0.0.4

This release contains an overhaul to the IR evaluator that should improve performance significantly for many workloads.

### New internal bytecode interpreter (#128)

Swift OPA's [Rego IR](https://www.openpolicyagent.org/docs/ir) evaluator no longer uses a recursive tree-walking IR evaluator, and instead performs an internal IR-to-bytecode conversion step, so that it can interpret bytecode directly.
The new core evaluation loop is much tighter as most validation checks are done at bytecode compilation time, and this results in far less branching and pointer chasing during evaluation.

The bytecode VM is up to 25% faster in benchmarks, with the biggest gains on iteration and call-heavy workloads.

This change is entirely internal to the evaluator, so users do not need to make any changes in order to take advantage of the performance improvements.

Authored by @koponen


## 0.0.3

This release contains bugfixes, performance improvements for the string builtins, and more!

### Performance improvements in `string` builtins (#112)

In this release [`strings.contains`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-contains), [`strings.endswith`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-endswith), and [`strings.startswith`](https://www.openpolicyagent.org/docs/policy-reference/builtins/strings#builtin-strings-startswith) builtins now use direct UTF-8 byte comparisons instead of Swift's default `String` methods.
This mirrors the behavior of OPA's Golang implementation, and offers a nice speedup for Rego policies using those builtins.

Authored by @arirubinstein

### New `time` builtins (#120, #127)

Swift OPA now supports all of the `time` builtins from OPA, including:
 - [`time.clock`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeclock)
 - [`time.date`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timedate)
 - [`time.diff`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timediff)
 - [`time.parse_duration_ns`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeparse_duration_ns)
 - [`time.parse_ns`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeparse_ns)
 - [`time.parse_rfc3339_ns`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeparse_rfc3339_ns)
 - [`time.format`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeformat)
 - [`time.weekday`](https://www.openpolicyagent.org/docs/policy-reference/builtins/time#builtin-time-timeweekday)

See the [OPA `time` docs](https://www.openpolicyagent.org/docs/policy-reference/builtins/time) for usage examples.

Authored by @DFrenkel

### Better support for multiple bundles (#110)

Swift OPA can now detect conflicts between multiple bundles correctly.
This resolves issues reported in #14 and #18.
The new algorithm is based on OPA's bundle roots overlap algorithm, and rolls in a few algorithmic improvements to efficiently handle large numbers of loaded bundles and roots.

The `Bundle` type now includes methods for validating that a bundle's `data` members are contained under the bundle's roots.

Authored by @philipaconrad

### Miscellaneous

- Rego/Bundle: Add public inits for Bundle, BundleFile, and Manifest. (#114) authored by @philipaconrad
- Rego/Manifest: Add Codable implementation. (#125) authored by @philipaconrad
- builtins: implement semver (#123) authored by @DFrenkel
- ci: Fix wrong path for release notes script. (#121) authored by @philipaconrad
- ci(perf): Refactor benchmarks to run in CI, and add memo benchmark (#113) authored by @arirubinstein


## 0.0.2

This release contains bugfixes, performance improvements for the IR evaluator, and several new builtins!

### Performance improvements (#101)

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

