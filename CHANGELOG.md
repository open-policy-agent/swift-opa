# Change Log

All notable changes to this project will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

## 0.0.7

This release includes bugfixes for non-bundle IR policies and a bunch of new builtin functions.

### Bugfix for non-bundle IR policies (#168)

In the [`0.0.6`](https://github.com/open-policy-agent/swift-opa/releases/tag/0.0.6) release, we added internal machinery to the IR evaluator that determines whether a policy requires async support or not for evaluation, allowing faster evaluation of sync-only policies.
The sync-safety static analysis pass handled bundles correctly, but did not properly handle user-supplied raw IR policies.

This caused the sync-only variant of the `PreparedQuery.evaluate()` function to throw while trying to run tests in our compliance test suite.
The issue was not noticed at first, because of how our compliance test CI step accidentally hid failure cases.

The bug was fixed in #168 by adding the needed static analysis pass for user-supplied raw IR policies, and the CI job that should have caught the issue was also updated to better surface new compliance test failures (See the Miscellaneous section for the CI updates).

Authored by @DFrenkel

### `regex` builtins (#138)

Swift OPA now supports the `regex.*` family of builtins:

 - [`regex.is_valid`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexis_valid)
 - [`regex.match`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexmatch)
 - [`regex.replace`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexreplace)
 - [`regex.split`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexsplit)
 - [`regex.find_n`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexfind_n)
 - [`regex.find_all_string_submatch_n`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regexfind_all_string_submatch_n)
 - [`regex.template_match`](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex#builtin-regex-regextemplate_match)

> [!WARNING]
> Swift OPA's `regex.*` builtins are only planned to support [RE2](https://github.com/google/re2/wiki/Syntax) syntax in the long term. Any regex syntax outside of RE2 syntax is unsupported, and may be broken in a future release.

To enforce this, every pattern is validated against an RE2 compatibility scanner up-front. Patterns using backreferences (`\1`–`\9`), lookahead (`(?=...)`, `(?!...)`), lookbehind (`(?<=...)`, `(?<!...)`), or atomic groups (`(?>...)`) are rejected at compile time: `regex.is_valid` returns `false`, and the other builtins throw. The scanner will be tightened over time. See the README's "Regex syntax support" section for more details.

These builtins add powerful new string matching and transformation capabilties.

Authored by @DFrenkel

### `urlquery` builtins (#174)

Swift OPA now supports the `urlquery.*` family of builtins:

 - [`urlquery.encode`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-urlqueryencode)
 - [`urlquery.decode`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-urlquerydecode)
 - [`urlquery.encode_object`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-urlqueryencode_object)
 - [`urlquery.decode_object`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-urlquerydecode_object)

These builtins make working with URLs and URL query parameters much more pleasant in Rego policies.

Authored by @DFrenkel

### Miscellaneous

 - ci: Allow diffs PR check to surface new errors. (#171) authored by @philipaconrad
   - This change corrects our CI jobs so that future compliance test failures will show up as blocking failures in CI.
 - ci: Pin runner versions on older targets. Fix paths in diff PR check. (#175) authored by @philipaconrad
 - chore: Fix paths in release notes scripts. (#170) authored by @philipaconrad


## 0.0.6

This release includes extensive performance optimizations, stronger IR plan validation in the `Engine`, and a new builtin function!

### Performance optimizations

Thanks to some extensive work from @koponen across 12 smaller PRs, and 1 large PR (#136) over the last month and a half, Swift OPA now runs much more efficiently than before across all workloads.

The cumulative effects are a general improvement across all benchmarks since the `0.0.5` release, with some benchmarks seeing extreme improvements.
This results in wall clock time speedups of 7-33% (median: 11%), instruction count reductions of 6-35% (median: 12%), and malloc reductions of 19-85% (median: 38%) across the benchmark suite.
Some benchmarks in the numeric and array iteration sets saw much greater improvements, with one array benchmark seeing a malloc reduction of 98%!

The changes can broadly be split into two categories: micro-optimizations, and the larger sync optimization across the entire Engine and bytecode VM.

#### Micro-optimizations

Some changes, like #152, #153, and #154 each provide general 1-4% speedups and/or mallocs improvements across nearly all benchmarks.

Other changes have more targeted effects:
 - #153: 8%+ speedup on array iteration benchmarks
 - #155 20%+ speedup for array-heavy benchmarks
 - #156: 3% mallocs reduction for numeric literals
 - #157: 98%+ mallocs reduction for array iteration workloads, improvements for builtin-heavy workloads
 - #158: ~13% speedup for numeric literals
 - #159: Small mallocs reduction for array iteration
 - #160: 1-3% improvements for wall clock time and mallocs on dynamic call benchmarks
 - #161: 5-20% speedup for builtin-heavy benchmarks
 - #162: Small speedup for some object-related instructions

#### Sync / Async optimizations (#136)

Swift OPA now supports a synchronous evaluation path in the underlying VM, allowing policies that do not use async operations to skip Swift's async machinery during policy evaluation.
This change reduced wall clock time by 9-23% and heap allocations by up to 38% across all benchmarks.

The only externally visible change is that Swift OPA now supports a synchronous version of `PreparedQuery.evaluate`.
This allows performance critical use cases to get the maximum possible speed boost, and throws if async operations are required in the policies.
Most users can continue using the async version of `PreparedQuery.evaluate` and will still reap the main benefits of the optimization.

The optimization works by first scanning through the entire policy with a static analysis pass.
The static analysis pass annotates "sync-safety" bits into the bytecode at different scales, from the individual block scopes, up to the top-level policy structure.
At runtime, the VM then uses those annotated bits to dispatch between sync/async paths efficiently, and only diverts into the slower async paths for the specific parts of a policy that require async operations.

The new sync paths required duplicating most of the VM's internals to have synchronous equivalents.
Rather than rewrite it all by hand and risk having drift occur between the sync and async functions over time, we now use a development-time macro to detect `// @sync` comments annotating async functions, and then emit synchronous equivalents into a generated source file.
This codegen approach was chosen so that downstream users of the Swift OPA library do not need to have a dependency on [swift-syntax](https://github.com/swiftlang/swift-syntax), which changes with each language version.

The new codegen step is run with `make generate`, and our CI workflows now ensure that the generated sources are up-to-date as part of normal PR checks.
If you are working on Swift OPA, you should not need to invoke the macro specifically unless you are are working on the `Engine` or bytecode VM internals.

### Improved plan validation in Engine (#151)

The `Engine` now validates that plans are contained under the roots of their parent bundles.
We also now support loading user-provided raw IR policies alongside bundles.
The improved validation ensures that plan names are unique across all sources, and that user-supplied plans don't conflict with plans or paths under the roots of any bundles.

The new validation is done at `prepareForEvaluation` time, and will throw descriptive errors if anything is amiss.

### Improved store behavior (#151)

In previous versions, the `Engine` would wipe out the store on each call to `prepareForEvaluation`, and would write only bundle contents back into the store.
This was acceptable for bundle-centric workflows, but limited many other use cases OPA supports.

We now modify the store at `prepareForEvaluation` in a manner much closer to OPA's bundle activation flow.
First, all old bundle roots are erased.
Then, all new/retained bundle roots are written to, ensuring the live set of bundles will always have consistent state written to the store.
Any user-modified locations in the store that are outside of those paths will be unmodified.

### `OPA.Store` protocol gains `remove(at:)` (#151)

The `OPA.Store` protocol now requires `mutating func remove(at: StoreKeyPath) async throws`.
This method removes the value at the given path, including the leaf key from its parent object.
A non-existent path is a no-op.
Removing the root path resets the store to an empty object.

This new API moves us closer to supporting the range of store functionality that OPA provides.

Authored by @philipaconrad

### `json.marshal_with_options` builtin function (#150)

Swift OPA now implements the [`json.marshal_with_options`](https://www.openpolicyagent.org/docs/policy-reference/builtins/encoding#builtin-encoding-jsonmarshal_with_options) builtin function, rounding out the `json` family of encoding builtins.

Authored by @philipaconrad

### Miscellaneous

 - IR+StaticAnalysis: Add locals renumbering pass (#124) authored by @philipaconrad
 - IR: Fix Encodable implementation for Block and Operand. (#147) authored by @philipaconrad
 - IR: Repatriate the IR.Local type after move move to AST. (#149) authored by @philipaconrad
 - Engine: Add MiniPlanner for basic data queries. (#145, reverted in #146) authored and reverted by @philipaconrad
   - This change was moved over to the [Swift OPA SDK](https://github.com/open-policy-agent/swift-opa-sdk), in [swift-opa-sdk/pull/28](https://github.com/open-policy-agent/swift-opa-sdk/pull/28), as part of supporting OPA's [Discovery](https://www.openpolicyagent.org/docs/management-discovery) API.


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

