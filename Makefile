BINDIR ?= $(HOME)/bin
OPA_BASE_CAPS_VERSION ?= v1.13.1

.PHONY: all
all: fmt lint test generate build

.PHONY: fmt
fmt:
	swift format format --parallel --recursive -i .

.PHONY: lint
lint:
	swift format lint --strict --parallel --recursive .

.PHONY: test
test:
	mkdir -p .build/test-results
	swift test --xunit-output .build/test-results/junit.xml

.PHONY: test-compliance
test-compliance:
	$(MAKE) -C ComplianceSuite test-compliance

# End-to-end interop tests against the golang `opa` binary. These are gated behind
# the SWIFT_OPA_E2E_TESTS env var and only run when `opa` is on PATH.
.PHONY: test-e2e
test-e2e:
	@if command -v opa >/dev/null 2>&1; then \
		echo "opa detected on PATH; enabling E2E interop tests"; \
		SWIFT_OPA_E2E_TESTS=1 swift test --filter OPAInteropTests; \
	else \
		echo "opa not found on PATH; skipping E2E interop tests"; \
	fi

.PHONY: perf
perf:
	cd Benchmarks && swift package benchmark

.PHONY: build
build:
	swift build

# Minimum viable build: all package traits disabled.
.PHONY: build-minimal
build-minimal:
	swift build --disable-default-traits

.PHONY: build-release
build-release:
	swift build -c release

# CI-specific targets. `build-ci` builds the code and tests in one pass, and
# `test-ci` (which depends on it) runs with `--skip-build`. Test artifacts are
# written outside `.build` so they don't pollute the cached build directory.
.PHONY: build-ci
build-ci:
	swift build --build-tests

.PHONY: test-ci
test-ci: build-ci
	mkdir -p test-results
	swift test --skip-build --xunit-output test-results/junit.xml

.PHONY: ensure-bindir
ensure-bindir:
ifeq ($(shell test -d "$(BINDIR)"; echo $$?),1)
	$(error BINDIR "$(BINDIR)" does not exist.)
endif

.PHONY: install-release
install-release: build-release ensure-bindir
	install $(shell swift build --show-bin-path -c release)/swift-opa-cli $(BINDIR)/

SYNC_SOURCES = Sources/Rego/VM.swift Sources/Rego/VM+Instructions.swift \
               Sources/Rego/Engine.swift Sources/Rego/IREvaluator.swift
SYNC_OUTPUT  = Sources/Rego/Generated/SyncPeers.swift

.PHONY: generate
generate:
	swift run --package-path tools/SyncGen SyncGen \
	    $(SYNC_SOURCES) --output $(SYNC_OUTPUT)
	swift format format -i $(SYNC_OUTPUT)
	curl -o opa-capabilities.json https://raw.githubusercontent.com/open-policy-agent/opa/refs/tags/$(OPA_BASE_CAPS_VERSION)/capabilities.json
	swift run swift-opa-cli capabilities opa-capabilities.json > capabilities.json

.PHONY: clean
clean:
	rm -rf .build

.PHONY: generate-compliance-tests
generate-compliance-tests:
	cd tools/generate-compliance-tests && go run main.go ../../ComplianceSuite/Tests/RegoComplianceTests/TestData/v1
