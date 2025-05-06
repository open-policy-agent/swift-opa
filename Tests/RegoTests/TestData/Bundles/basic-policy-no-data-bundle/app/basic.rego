package app.basic

# By default, deny requests.
default allow := false

allow if {
	some apple in data.apples
	input.variety == apple.variety
}
