package example

default allow := false

allow if {
	input.role == "admin"
}
