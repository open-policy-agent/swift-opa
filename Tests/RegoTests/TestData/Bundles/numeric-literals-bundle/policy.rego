package benchmark.numeric

# Simulates a policy with lots of constants

default allow := false

# Score calculation with many numeric literals
score := s if {
	s := ((((((input.value * 100) + (input.bonus * 1.5)) + (input.multiplier * 2.3)) + 250.75) + 42) + 3.14159) + 999.999
}

# Allow if score is in valid ranges (many comparisons with literals)
allow if {
	score > 1000
	score < 10000
	input.value >= 0
	input.value <= 500
	input.bonus > 0.0
	input.bonus < 100.0
	input.multiplier >= 1.0
	input.multiplier <= 5.0
}
