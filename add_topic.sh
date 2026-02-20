#!/bin/bash
set -euo pipefail

REPO_URL="${1:?Usage: $0 <repo_url> <topic_name>}"
TOPIC="${2:?Usage: $0 <repo_url> <topic_name>}"

# https://github.com/owner/repo -> owner/repo
REPO_PATH=$(echo "$REPO_URL" | sed 's|https://github.com/||' | sed 's|/$||')

# 現在のトピックを取得
CURRENT=$(gh api "/repos/$REPO_PATH/topics" \
  -H "Accept: application/vnd.github.mercy-preview+json" \
  --jq '.names')

# 新トピックを追加 + unique で重複排除
UPDATED=$(echo "$CURRENT" | jq --arg topic "$TOPIC" '. + [$topic] | unique')

# PUT で更新
echo "{\"names\": $UPDATED}" | gh api "/repos/$REPO_PATH/topics" \
  -X PUT \
  -H "Accept: application/vnd.github.mercy-preview+json" \
  --input - > /dev/null

echo "✓ '$TOPIC' -> $REPO_PATH (topics: $(echo "$UPDATED" | jq -r 'join(", ")'))"
