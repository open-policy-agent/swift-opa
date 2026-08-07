# TestRunner test fixtures

Each subdirectory is a compiled Rego **plan bundle** (`opa build -t plan` output),
committed with its `.rego` sources so the fixtures are easy to inspect and regenerate.
The `.rego` files are not needed at runtime (swift-opa executes `plan.json`). They are
kept for debugging and to document what each plan was compiled from.

`test_*` rules only appear in `plan.json` as funcs when they are reachable from the
build's entrypoints. The commands below choose entrypoints accordingly.

## `example-bundle/`

```sh
cd example-bundle
opa build -b . -t plan -e example_test -o ../b.tar.gz && tar -xzf ../b.tar.gz
```

## `nested-bundle/`

```sh
cd nested-bundle
opa build -b . -t plan -e authz/allow -e authz/rbac/allow -o ../b.tar.gz && tar -xzf ../b.tar.gz
```
