#!/usr/bin/env bash
# Script to draft and edit Swift OPA GitHub releases. Assumes execution environment is Github Actions runner.

set -x

usage() {
    echo "github-release.sh  [--tag=<git tag>]"
    echo "    Default --tag is $TAG_NAME "
}

TAG_NAME=${TAG_NAME}

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

# Gather the release notes from the CHANGELOG for the latest version
RELEASE_NOTES="release-notes.md"

# The hub CLI expects the first line to be the title
echo -e "${TAG_NAME}\n" > "${RELEASE_NOTES}"

# Fill in the description
./build/latest-release-notes.sh --output="${RELEASE_NOTES}"

# Update or create a release on github
if gh release view "${TAG_NAME}" --repo open-policy-agent/swift-opa > /dev/null; then
    # Occurs when the tag is created via GitHub UI w/ a release
    gh release upload "${TAG_NAME}" --repo open-policy-agent/swift-opa
else
    # Create a draft release
    gh release create "${TAG_NAME}" -F ${RELEASE_NOTES} --draft --title "${TAG_NAME}" --repo open-policy-agent/swift-opa
fi
