#!/usr/bin/env bash
# Script to draft and edit Swift OPA GitHub releases. Assumes execution environment is Github Actions runner.

set -x
set -euo pipefail

usage() {
    echo "github-release.sh  [--tag=<git tag>]"
    echo "    Default --tag is $TAG_NAME "
}

TAG_NAME=${TAG_NAME:-}

for i in "$@"; do
    case $i in
    --tag=*)
        TAG_NAME="${i#*=}"
        shift
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

if [ -z "${TAG_NAME}" ]; then
    echo "error: no tag provided (set TAG_NAME or pass --tag=<git tag>)" >&2
    usage
    exit 1
fi

# Gather the release notes from the CHANGELOG for the latest version
RELEASE_NOTES="release-notes.md"

# The hub CLI expects the first line to be the title
echo -e "${TAG_NAME}\n" > "${RELEASE_NOTES}"

# Fill in the description
./tools/build/latest-release-notes.sh --output="${RELEASE_NOTES}"

# Guard against publishing an empty release: the notes must contain more than
# just the title line we seeded above.
if [ "$(grep -vc -e '^[[:space:]]*$' -e "^${TAG_NAME}\$" "${RELEASE_NOTES}")" -eq 0 ]; then
    echo "error: release notes for ${TAG_NAME} are empty (no CHANGELOG body extracted)" >&2
    exit 1
fi

# Release artifacts to attach to the GitHub release
CAPABILITIES_FILE="${CAPABILITIES_FILE:-capabilities.json}"

# Update or create a release on github
if gh release view "${TAG_NAME}" --repo open-policy-agent/swift-opa > /dev/null; then
    # Occurs when the tag is created via GitHub UI w/ a release
    gh release upload "${TAG_NAME}" "${CAPABILITIES_FILE}" --clobber --repo open-policy-agent/swift-opa
else
    # Create a draft release
    gh release create "${TAG_NAME}" "${CAPABILITIES_FILE}" -F ${RELEASE_NOTES} --draft --title "${TAG_NAME}" --repo open-policy-agent/swift-opa
fi
