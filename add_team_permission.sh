#!/bin/bash
set -euo pipefail

REPO_URL="${1:?Usage: $0 <repo_url> <team_slug> <permission>}"
TEAM_SLUG="${2:?Usage: $0 <repo_url> <team_slug> <permission>}"
PERMISSION="${3:?Usage: $0 <repo_url> <team_slug> <permission>  # pull / push / maintain / triage / admin}"

# https://github.com/owner/repo -> owner/repo
REPO_PATH=$(echo "$REPO_URL" | sed 's|https://github.com/||' | sed 's|/$||')
ORG=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)

gh api "/orgs/$ORG/teams/$TEAM_SLUG/repos/$ORG/$REPO" \
  -X PUT \
  -f permission="$PERMISSION" > /dev/null

echo "✓ $PERMISSION 権限を付与: $TEAM_SLUG -> $REPO_PATH"
