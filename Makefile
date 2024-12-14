fmt:
	@swift format format --configuration swift-format.config.json --parallel --recursive -i .
lint:
	@swift format lint --configuration swift-format.config.json --parallel --recursive .
test:
	@swift test

.PHONY: fmt lint
