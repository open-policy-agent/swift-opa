package example_test

import data.example

test_pass if {
	true
}

test_allow_admin if {
	example.allow with input as {"role": "admin"}
}

test_fail if {
	false
}

todo_test_skip if {
	true
}
