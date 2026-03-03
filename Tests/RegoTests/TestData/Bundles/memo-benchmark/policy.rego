package benchmark.memo

# 10 check rules - each performs a simple comparison against input.
# These become separate IR functions that are memoizable (2-arg calls).
check_1 if input.value > 0

check_2 if input.value > 1

check_3 if input.value > 2

check_4 if input.value > 3

check_5 if input.value > 4

check_6 if input.value > 5

check_7 if input.value > 6

check_8 if input.value > 7

check_9 if input.value > 8

check_10 if input.value > 9

# 4 composite rules reference overlapping subsets of check rules.
# This creates ~20 check calls with ~10 memo cache hits per evaluation.
composite_a if {
	check_1
	check_2
	check_3
	check_4
	check_5
}

composite_b if {
	check_3
	check_4
	check_5
	check_6
	check_7
}

composite_c if {
	check_5
	check_6
	check_7
	check_8
	check_9
}

composite_d if {
	check_7
	check_8
	check_9
	check_10
	check_1
}

# Entrypoint that evaluates all composites
result if {
	composite_a
	composite_b
	composite_c
	composite_d
}
