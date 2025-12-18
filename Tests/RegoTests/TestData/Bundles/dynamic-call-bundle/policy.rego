package test

# Entrypoint that uses CallDynamicStmt pattern
# The variable x is bound from input, then used to dynamically reference a rule
result := y if {
	x := input.operation
	data.funcs[x] = y
}
