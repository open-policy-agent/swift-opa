package authz.rbac_test

import data.authz.rbac

test_read_allowed if { rbac.allow with input as {"perm": "read"} }
test_write_denied if { not rbac.allow with input as {"perm": "write"} }
