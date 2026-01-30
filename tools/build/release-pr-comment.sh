#!/usr/bin/env bash
# Script to create or update a PR comment with a unique marker
# Usage: release-pr-comment.sh <repo> <pr_number> [marker]

set -e  # Exit on any error

# Check arguments
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <repo> <pr_number> [marker]"
    echo "   or: echo 'comment body' | $0 <repo> <pr_number> [marker]"
    echo "   or: COMMENT_BODY='comment body' $0 <repo> <pr_number> [marker]"
    echo ""
    echo "Arguments:"
    echo "  repo           Repository in format 'owner/repo'"
    echo "  pr_number      Pull request number"
    echo "  marker         Unique HTML comment marker (default: '<!-- auto-comment -->')"
    echo ""
    echo "Comment body source (in order of precedence):"
    echo "  1. COMMENT_BODY environment variable"
    echo "  2. stdin (if not a terminal)"
    echo ""
    echo "Environment variables:"
    echo "  COMMENT_BODY   Comment body text (optional)"
    echo "  GH_TOKEN       GitHub token for authentication"
    echo ""
    echo "The script will update existing comments with the same marker or create a new one."
    exit 1
fi

REPO="$1"
PR_NUMBER="$2"
MARKER="${3:-<!-- auto-comment -->}"

echo "DEBUG: $COMMENT_BODY"

# Get comment body from environment variable or stdin
if [ -n "$COMMENT_BODY" ]; then
    echo "Using comment body from COMMENT_BODY environment variable" >&2
elif [ ! -t 0 ]; then
    # stdin is not a terminal (has data piped to it)
    echo "Reading comment body from stdin" >&2
    COMMENT_BODY=$(cat)
else
    echo "Error: No comment body provided. Set COMMENT_BODY environment variable or pipe content to stdin." >&2
    exit 1
fi

# Check if comment body is empty
if [ -z "$COMMENT_BODY" ]; then
    echo "Error: Comment body is empty" >&2
    exit 1
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI is not available" >&2
    exit 2
fi

# Check if GH_TOKEN is set (gh CLI will handle the actual auth)
if [ -z "$GH_TOKEN" ]; then
    echo "Warning: GH_TOKEN environment variable not set" >&2
fi

# Add marker and timestamp to comment body
TIMESTAMPED_BODY="$MARKER
$COMMENT_BODY

_Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')_"

# Look for existing comment with our marker
echo "Checking for existing comment with marker..." >&2
EXISTING_COMMENT=$(gh api repos/$REPO/issues/$PR_NUMBER/comments \
    --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" | head -1) || {
    echo "Error: Failed to fetch existing comments" >&2
    exit 2
}

if [ -n "$EXISTING_COMMENT" ]; then
    echo "Updating existing comment ID: $EXISTING_COMMENT" >&2
    gh api repos/$REPO/issues/comments/$EXISTING_COMMENT \
        --method PATCH \
        --field body="$TIMESTAMPED_BODY" || {
        echo "Error: Failed to update comment" >&2
        exit 2
    }
    echo "Comment updated successfully" >&2
else
    echo "Creating new comment" >&2
    gh api repos/$REPO/issues/$PR_NUMBER/comments \
        --method POST \
        --field body="$TIMESTAMPED_BODY" || {
        echo "Error: Failed to create comment" >&2
        exit 2
    }
    echo "Comment created successfully" >&2
fi