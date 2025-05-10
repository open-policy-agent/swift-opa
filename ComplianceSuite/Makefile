OPA_COMPLIANCE_TESTS?=.*

.PHONY: all
all: fmt lint test-compliance

.PHONY: fmt
fmt:
	swift format format --parallel --recursive -i .

.PHONY: lint
lint:
	swift format lint --parallel --recursive .

.PHONY: test-compliance
test-compliance:
	mkdir -p .build/test-results
	OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test \
		--filter ComplianceTests.ComplianceTests \
		--xunit-output .build/test-results/junit.xml

.PHONY: test-failed
test-failed:
	@OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test --filter ComplianceTests.ComplianceTests \
		| rg '❌' | rg -v builtinNotFound \
		| gsed -nre 's/.*❌ (.*) ->.*/\1/p' \
		| sort | uniq

.PHONY: test-passed
test-passed:
	@OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test --filter ComplianceTests.ComplianceTests \
		| rg '✅' \
		| gsed -nre 's/.*✅ (.*) ->.*/\1/p' \
		| sort | uniq

.PHONY: clean
clean:
	rm -rf .build

.PHONY: index
index:
	@find Tests/RegoComplianceTests/TestData/v1 -name '*.json' \
		| sort \
		| xargs jq '{"file": input_filename, "note": [.cases[].note]}' \
	   	| sed 's#Tests/RegoComplianceTests/##p' \
		| jq -s . > Tests/RegoComplianceTests/TestData/index.json
