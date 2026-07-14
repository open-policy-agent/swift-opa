package authz.rbac

default allow := false
allow if { input.perm == "read" }
