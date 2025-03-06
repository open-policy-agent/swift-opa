OPA_COMPLIANCE_TESTS?=.*

.PHONY: all
all: fmt lint test-compliance

.PHONY: fmt
fmt:
	swift format format --parallel --recursive -i .

.PHONY: lint
lint:
	swift format lint --parallel --recursive .

.PHONY: test
test:
	mkdir -p .build/test-results
	swift test \
	--xunit-output .build/test-results/junit.xml

.PHONY: test-compliance
test-compliance:
	mkdir -p .build/test-results
	OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test \
		--filter ComplianceTests.ComplianceTests \
		--xunit-output .build/test-results/junit-compliance.xml

.PHONY: test-failed
test-failed:
	@OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test --filter ComplianceTests.ComplianceTests \
		| ./tools/failed.sh

.PHONY: test-passed
test-passed:
	@OPA_COMPLIANCE_TESTS="$(OPA_COMPLIANCE_TESTS)" \
		swift test --filter ComplianceTests.ComplianceTests \
		| ./tools/passed.sh

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
