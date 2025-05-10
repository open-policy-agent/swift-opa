# SwiftOPA Compliance Tests

## Running the Tests

To run the tests, execute the following command:

```shell
make test-compliance
```

## Filtering

To run a subset of the tests, provide a filter using the OPA_COMPLIANCE_TESTS environment variable.
A filter expression is composed of two parts, the file filter pattern and the 'note' filter pattern:

```
OPA_COMPLIANCE_TESTS=[file-filter-regex]:[note-filter-regex]
```

Examples:

```shell
# matches objectget/test-objectget-path.json: objectget/get_intermediate_array
OPA_COMPLIANCE_TESTS='objectget/test-objectget-path.json: .*array' make test-compliance

# matches all cases in files matching `.*objectget.*.json`
OPA_COMPLIANCE_TESTS='objectget' make test-compliance

# matches any case matching `.*rewrite.*` across all files
OPA_COMPLIANCE_TESTS=':rewrite' make test-compliance
```

## Adding compliance tests

Compliance test cases are generated using `opa-compliance-test`. This tool converts the [OPA Compliance Suite](https://github.com/open-policy-agent/opa/tree/main/v1/test/cases/testdata/v1) to a format usable here.

When adding additional compliance tests, it is important to re-index the full suite. This index is used by the test harness to discover which tests appear in which files. To re-index, simple run:

```shell
make index
```


## Xcode with Tests and SwiftOPA

1. Close other Xcode windows.
2. Create a new Xcode workspace (File > New > Workspace), point at the parent directory where you have the repositories cloned.
3. Add the `swift-opa` and `swift-opa-compliance-tests` directories to the workspace (give it a minute to index things...)
4. Create a new test plan (View > Test Plans > New Test Plan). Point it at the RegoComplianceTests target, set the `compliance` tag, and configure the `OPA_COMPLIANCE_TESTS` environment variable to specify the file you want to run.
5. Setup breakpoints as needed in `swift-opa`, run the tests, rinse and repeat.
