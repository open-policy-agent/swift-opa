package authz

default allow := false
allow if { input.role == "admin" }
