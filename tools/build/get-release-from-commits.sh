#!/usr/bin/env bash
# Script to extract version from release commits for GH Actions checks.
# Note: Remember to include the "origin/" prefix for remote branches!
#  Otherwise, checks will be done against local branches of matching names.
# Usage: get-release-from-commits.sh <base_branch> <head_branch> [pattern]

set -x
set -e  # Exit on any error

# Check args.
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <base_branch> <head_branch> [pattern]"
    echo ""
    echo "Arguments:"
    echo "  base_branch    Base branch to compare against"
    echo "  head_branch    Head branch to check"
    echo "  pattern        Pattern to search for (default: '^Release [v]?[0-9.]+')"
    echo ""
    echo "Output: '<version>' if release commits found, '' otherwise"
    echo ""
    echo "Example (local branch): $0 origin/main user/feature"
    echo "Example (remote branch): $0 origin/main origin/user/feature"
    exit 1
fi

BASE_BRANCH="$1"
HEAD_BRANCH="$2"
PATTERN="${3:-^Release v?[0-9.]+}"

# Check if we're in a git repository.
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 2
fi

# Get commit messages from the range.
COMMITS=$(git log --oneline $BASE_BRANCH..$HEAD_BRANCH --pretty=format:"%s" 2>/dev/null) || {
    echo "Error: Failed to get commit messages. Check if branches exist." >&2
    exit 2
}

# If no commits, return empty.
if [ -z "$COMMITS" ]; then
    exit 0
fi

# Check for release pattern and extract version.
VERSION=$(echo "$COMMITS" | grep -E -i "$PATTERN" | head -n 1 | grep -E -o '[0-9.]+') || {
    echo "No matches found."
    exit 0
}

if [ -n "$VERSION" ]; then
    echo "$VERSION"
fi