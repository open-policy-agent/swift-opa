#!/usr/bin/env bash

set -eu

BUNDLE_TARGET="$1"
ENTRYPOINT="$2"

TMP_DIR=$(mktemp -d)

echo "Using tmp dir: ${TMP_DIR}"

mkdir -p "${TMP_DIR}"

cd "${BUNDLE_TARGET}"

opa build \
    -b . \
    -e "${ENTRYPOINT}" \
    -t plan \
    -o "${TMP_DIR}/bundle.tar.gz"

echo "Saving to $(pwd)/plan.json"
tar -xf "${TMP_DIR}/bundle.tar.gz" /plan.json
mv plan.json "${TMP_DIR}/plan.json"
cat "${TMP_DIR}/plan.json" | jq -S > plan.json
