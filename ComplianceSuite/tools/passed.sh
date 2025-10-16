#!/bin/bash
sed -n '/✅/ { s/.*✅ \(.*\) ->.*/\1/p; }' \
  | sort | uniq
