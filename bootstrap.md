swift package init --type library --name SwiftRego
swift package add-target --type test --testing-library swift-testing SwiftRegoTests
swift format dump-configuration > swift-format.config.json
