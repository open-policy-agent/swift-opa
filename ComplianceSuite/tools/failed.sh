#!/bin/bash
sed -n '/❌/ { /builtinUndefinedError/! s/.*❌ \(.*\) ->.*/\1/p; }' \
  | sort | uniq
