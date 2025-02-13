.PHONY: all
all: fmt lint test build

.PHONY: fmt
fmt:
	swift format format --configuration swift-format.config.json --parallel --recursive -i .

.PHONY: lint
lint:
	swift format lint --configuration swift-format.config.json --parallel --recursive .

.PHONY: test
test:
	swift test

.PHONY: build
build:
	swift build

.PHONY: clean
clean:
	rm -rf .build

.PHONY: bench
bench:
	OPA_BENCHMARK=enabled swift package benchmark
