#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

# --- ヘルパー関数 ---

setup() {
  MOCK_BIN="$(mktemp -d /tmp/gh-helper-test-XXXXXX)"
  GH_CALLS="$MOCK_BIN/gh_calls"
  touch "$GH_CALLS"
  export GH_CALLS

  cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo "$@" >> "$GH_CALLS"

# --jq フラグを検出して実際の jq でフィルタリング
JQ_FILTER=""
ARGS=("$@")
for i in "${!ARGS[@]}"; do
  if [[ "${ARGS[$i]}" == "--jq" ]]; then
    JQ_FILTER="${ARGS[$((i+1))]}"
  fi
done

RAW_OUTPUT="${GH_MOCK_OUTPUT:-}"
if [[ -n "$RAW_OUTPUT" ]]; then
  if [[ -n "$JQ_FILTER" ]]; then
    echo "$RAW_OUTPUT" | jq -r "$JQ_FILTER"
  else
    echo "$RAW_OUTPUT"
  fi
fi

exit "${GH_MOCK_EXIT:-0}"
MOCK
  chmod +x "$MOCK_BIN/gh"
  export PATH="$MOCK_BIN:$PATH"
  export MOCK_BIN
}

teardown() {
  rm -rf "$MOCK_BIN"
  unset MOCK_BIN GH_CALLS GH_MOCK_OUTPUT GH_MOCK_EXIT
}

# テスト実行: run <description> <expected_exit> <expected_output_pattern> -- <cmd...>
assert() {
  local desc="$1"
  local expected_exit="$2"
  local expected_pattern="$3"
  shift 3
  # "--" を読み飛ばす
  [[ "$1" == "--" ]] && shift

  local actual_output actual_exit
  actual_output="$("$@" 2>&1)"
  actual_exit=$?

  local ok=true

  # 終了コード検証
  if [[ "$expected_exit" == "nonzero" ]]; then
    [[ "$actual_exit" -ne 0 ]] || ok=false
  else
    [[ "$actual_exit" -eq "$expected_exit" ]] || ok=false
  fi

  # 出力パターン検証
  if [[ -n "$expected_pattern" ]]; then
    echo "$actual_output" | grep -qF "$expected_pattern" || ok=false
  fi

  if $ok; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    exit=$actual_exit, pattern='$expected_pattern'"
    echo "    output: $actual_output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local desc="$1"
  local file="$2"
  local pattern="$3"

  if grep -qF "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    pattern '$pattern' not found in $file"
    echo "    file contents: $(cat "$file" 2>/dev/null)"
    FAIL=$((FAIL + 1))
  fi
}

# --- add_topic.sh のテスト ---

echo "=== add_topic.sh ==="

setup
assert "引数なし → 非ゼロ終了 + Usage:" nonzero "Usage:" -- \
  bash "$SCRIPT_DIR/add_topic.sh"
teardown

setup
assert "引数1個 → 非ゼロ終了 + Usage:" nonzero "Usage:" -- \
  bash "$SCRIPT_DIR/add_topic.sh" "https://github.com/owner/repo"
teardown

setup
export GH_MOCK_OUTPUT='{"names":[]}'
assert "URL パース: /repos/myorg/myrepo/topics が呼ばれる" 0 "" -- \
  bash "$SCRIPT_DIR/add_topic.sh" "https://github.com/myorg/myrepo" "java"
assert_file_contains "URL パース: エンドポイント確認" "$GH_CALLS" "/repos/myorg/myrepo/topics"
teardown

setup
export GH_MOCK_OUTPUT='{"names":[]}'
assert "末尾スラッシュ除去: 正常終了" 0 "" -- \
  bash "$SCRIPT_DIR/add_topic.sh" "https://github.com/myorg/myrepo/" "java"
assert_file_contains "末尾スラッシュ除去: エンドポイント確認" "$GH_CALLS" "/repos/myorg/myrepo/topics"
teardown

setup
export GH_MOCK_OUTPUT='{"names":[]}'
assert "成功メッセージ: チェックマーク + topic + repo" 0 "✓ 'java' -> myorg/myrepo" -- \
  bash "$SCRIPT_DIR/add_topic.sh" "https://github.com/myorg/myrepo" "java"
teardown

setup
# 1回目（GET）は既存トピック返す、2回目（PUT）は何も返さない
CALL_COUNT_FILE="$MOCK_BIN/call_count"
echo "0" > "$CALL_COUNT_FILE"
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
echo "$@" >> "$GH_CALLS"

COUNT=$(cat "$MOCK_BIN/call_count")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$MOCK_BIN/call_count"

JQ_FILTER=""
ARGS=("$@")
for i in "${!ARGS[@]}"; do
  if [[ "${ARGS[$i]}" == "--jq" ]]; then
    JQ_FILTER="${ARGS[$((i+1))]}"
  fi
done

if [[ "$COUNT" -eq 1 ]]; then
  RAW='{"names":["java"]}'
  if [[ -n "$JQ_FILTER" ]]; then
    echo "$RAW" | jq -r "$JQ_FILTER"
  else
    echo "$RAW"
  fi
fi
exit 0
MOCK
chmod +x "$MOCK_BIN/gh"
output=$(bash "$SCRIPT_DIR/add_topic.sh" "https://github.com/myorg/myrepo" "java" 2>&1)
# topics: の後の部分だけ取り出して java の出現数を確認
TOPICS_PART=$(echo "$output" | grep -oP '(?<=topics: )[^)]+' || true)
JAVA_COUNT=$(echo "$TOPICS_PART" | grep -o "java" | wc -l)
if [[ "$JAVA_COUNT" -eq 1 ]]; then
  echo "  PASS: 重複排除: 既存トピックを再追加しても重複しない"
  PASS=$((PASS + 1))
else
  echo "  FAIL: 重複排除: topics リストに java が $JAVA_COUNT 回出現 (期待: 1)"
  echo "    output: $output"
  FAIL=$((FAIL + 1))
fi
teardown

# --- add_team_permission.sh のテスト ---

echo "=== add_team_permission.sh ==="

setup
assert "引数なし → 非ゼロ終了 + Usage:" nonzero "Usage:" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh"
teardown

setup
assert "引数1個 → 非ゼロ終了 + Usage:" nonzero "Usage:" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/owner/repo"
teardown

setup
assert "引数2個 → 非ゼロ終了 + Usage:" nonzero "Usage:" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/owner/repo" "dev-team"
teardown

setup
assert "API エンドポイント: 正常終了" 0 "" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/myorg/myrepo" "dev-team" "push"
assert_file_contains "API エンドポイント: パス確認" "$GH_CALLS" "/orgs/myorg/teams/dev-team/repos/myorg/myrepo"
teardown

setup
assert "permission 値: 渡される" 0 "" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/myorg/myrepo" "dev-team" "push"
assert_file_contains "permission 値: push が渡される" "$GH_CALLS" "permission=push"
teardown

setup
assert "成功メッセージ" 0 "✓ push 権限を付与: dev-team -> myorg/myrepo" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/myorg/myrepo" "dev-team" "push"
teardown

setup
assert "末尾スラッシュ除去" 0 "✓ pull 権限を付与: team-a -> myorg/myrepo" -- \
  bash "$SCRIPT_DIR/add_team_permission.sh" "https://github.com/myorg/myrepo/" "team-a" "pull"
teardown

# --- 結果サマリー ---

echo ""
echo "=== 結果: ${PASS} PASS, ${FAIL} FAIL ==="

[[ "$FAIL" -eq 0 ]]
