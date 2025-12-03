package benchmark.iteration

# Simple array iteration benchmark
# Iterates over input array and checks if any items match a threshold

default has_matching := false

# Check if any item matches
has_matching if {
    some x in input.items
    x > input.threshold
}
