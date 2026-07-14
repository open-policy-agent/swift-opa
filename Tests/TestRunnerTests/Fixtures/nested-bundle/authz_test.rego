package authz_test

import data.authz

test_admin_allowed if { authz.allow with input as {"role": "admin"} }
test_anon_denied if { not authz.allow with input as {"role": "guest"} }
