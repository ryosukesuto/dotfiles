#!/usr/bin/env bash
# 既存の setup-ci-review インストールを最新テンプレートに更新するヘルパー。
#
# 使い方:
#   bash ${CLAUDE_SKILL_DIR}/scripts/update-existing.sh <target-repo-root>
#
# 挙動:
#   - .github/workflows/claude-review.yml を最新に置き換え
#   - .claude/skills/claude-code-review/SKILL.md の「投稿ルール」セクションを最新に置き換える
#     （REVIEWER_ROLE / REVIEW_CRITERIA などリポジトリ固有の部分は保持）
#   - 差分を stdout に出してレビューしやすくする
#   - コミット・push は行わない（ユーザー判断で実行）

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <target-repo-root>" >&2
  exit 2
fi

TARGET="$1"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$TARGET/.github/workflows" ]; then
  echo "ERROR: $TARGET is not a setup-ci-review installed repo (missing .github/workflows)" >&2
  exit 1
fi

WF_SRC="$SKILL_DIR/templates/claude-review.yml"
WF_DST="$TARGET/.github/workflows/claude-review.yml"
SKILL_DST="$TARGET/.claude/skills/claude-code-review/SKILL.md"

updated=()

# 1) claude-review.yml を丸ごと置き換え
if [ -f "$WF_DST" ]; then
  if ! cmp -s "$WF_SRC" "$WF_DST"; then
    echo "=== update: $WF_DST ==="
    diff -u "$WF_DST" "$WF_SRC" || true
    cp "$WF_SRC" "$WF_DST"
    updated+=("claude-review.yml")
  fi
else
  echo "WARN: $WF_DST not found — skipping" >&2
fi

# 2) SKILL.md の投稿ルールセクションを置き換え
# `## 投稿ルール` 以降をテンプレート側で上書きする
if [ -f "$SKILL_DST" ]; then
  TEMPLATE="$SKILL_DIR/templates/claude-code-review-skill.md"
  TMP=$(mktemp)
  # 既存 SKILL.md の「## 投稿ルール」より前を出力（ファイルに直接書き込みで末尾改行を保持）
  awk '/^## 投稿ルール/{exit} {print}' "$SKILL_DST" > "$TMP"
  # テンプレートの「## 投稿ルール」以降を追記
  awk '/^## 投稿ルール/{p=1} p{print}' "$TEMPLATE" >> "$TMP"

  if ! cmp -s "$TMP" "$SKILL_DST"; then
    echo "=== update: $SKILL_DST (投稿ルールセクションを置換) ==="
    diff -u "$SKILL_DST" "$TMP" || true
    mv "$TMP" "$SKILL_DST"
    updated+=("claude-code-review/SKILL.md")
  else
    rm -f "$TMP"
  fi
else
  echo "WARN: $SKILL_DST not found — skipping" >&2
fi

if [ ${#updated[@]} -eq 0 ]; then
  echo "既に最新です。更新不要です。"
else
  echo ""
  echo "更新完了: ${updated[*]}"
  echo "確認のうえ、以下でコミットしてください:"
  echo "  git -C '$TARGET' add .github/workflows/claude-review.yml .claude/skills/claude-code-review/SKILL.md"
  echo "  git -C '$TARGET' commit -m 'chore: setup-ci-review の最新テンプレートに追随'"
fi
