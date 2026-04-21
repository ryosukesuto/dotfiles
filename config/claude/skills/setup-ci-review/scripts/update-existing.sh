#!/usr/bin/env bash
# 既存の setup-ci-review インストールを最新テンプレートに更新するヘルパー。
#
# 使い方:
#   bash ${CLAUDE_SKILL_DIR}/scripts/update-existing.sh <target-repo-root> [--yes]
#
# 挙動:
#   - .github/workflows/claude-review.yml を最新に置き換え
#   - .claude/skills/claude-code-review/SKILL.md を最新テンプレートで全置換
#     （REVIEWER_ROLE / REVIEW_CRITERIA は既存ファイルから抽出して保持）
#   - .greptile/config.json を最新テンプレートで全置換（preset自動判定）
#     IaC preset 判定: .github/workflows/checkov.yml の有無、または既存 rules[] に
#     テンプレート由来のIaC用 rule id が含まれるか
#   - 差分を表示してから y/N で確認（--yes で省略可）
#   - コミット・push は行わない
#
# 注意:
#   SKILL.md に REVIEWER_ROLE / REVIEW_CRITERIA 以外の手動カスタマイズがある場合、
#   全置換で失われる。差分を必ず目視確認すること。
#   .greptile/config.json の strictness / ignorePatterns / instructions / rules[] 等を
#   個別調整している場合も上書きで失われるため差分確認必須。
#   .greptile/rules.md と files.json は analyze=yes で埋めた内容を壊さないよう、
#   本スクリプトの対象外（手動で追随させる）。

set -euo pipefail

AUTO_YES=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=1 ;;
    *) TARGET="$arg" ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "usage: $0 <target-repo-root> [--yes]" >&2
  exit 2
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$TARGET/.github/workflows" ]; then
  echo "ERROR: $TARGET is not a setup-ci-review installed repo (missing .github/workflows)" >&2
  exit 1
fi

WF_SRC="$SKILL_DIR/templates/claude-review.yml"
WF_DST="$TARGET/.github/workflows/claude-review.yml"
SKILL_TEMPLATE="$SKILL_DIR/templates/claude-code-review-skill.md"
SKILL_DST="$TARGET/.claude/skills/claude-code-review/SKILL.md"

updated=()

confirm() {
  # $1: prompt message
  if [ "$AUTO_YES" -eq 1 ]; then
    return 0
  fi
  local answer
  read -r -p "$1 (y/N): " answer </dev/tty
  [[ "$answer" =~ ^[Yy]$ ]]
}

trim_blank_lines() {
  awk '
    { lines[NR] = $0 }
    END {
      s = 1; e = NR
      while (s <= e && lines[s] ~ /^$/) s++
      while (e >= s && lines[e] ~ /^$/) e--
      for (i = s; i <= e; i++) print lines[i]
    }
  '
}

extract_role() {
  sed -n 's/^あなたは \(.*\) です。このPRをレビューします。$/\1/p' "$1" | head -1
}

extract_criteria() {
  awk '
    /^3\. 既存コードとの一貫性チェックは Greptile が担当するため、そちらには踏み込まない$/{flag=1; next}
    /^## 優先度ラベル/{exit}
    flag {print}
  ' "$1" | trim_blank_lines
}

render_skill_template() {
  # $1: template, $2: role string, $3: criteria file path
  awk -v role="$2" -v cfile="$3" '
    {
      line = $0
      gsub(/\{\{REVIEWER_ROLE\}\}/, role, line)
      if (line ~ /^\{\{REVIEW_CRITERIA\}\}$/) {
        while ((getline cline < cfile) > 0) print cline
        close(cfile)
        next
      }
      print line
    }
  ' "$1"
}

# 1) claude-review.yml を置き換え（丸ごと同一化）
if [ -f "$WF_DST" ]; then
  if ! cmp -s "$WF_SRC" "$WF_DST"; then
    echo "=== diff: $WF_DST ==="
    diff -u "$WF_DST" "$WF_SRC" || true
    echo ""
    if confirm "claude-review.yml を最新テンプレートで上書きしますか？"; then
      cp "$WF_SRC" "$WF_DST"
      updated+=("claude-review.yml")
    else
      echo "claude-review.yml の更新をスキップしました。"
    fi
  fi
else
  echo "WARN: $WF_DST not found — skipping" >&2
fi

# 2) SKILL.md を全置換（REVIEWER_ROLE / REVIEW_CRITERIA は保持）
if [ -f "$SKILL_DST" ]; then
  ROLE=$(extract_role "$SKILL_DST")
  CRITERIA_FILE=$(mktemp)
  extract_criteria "$SKILL_DST" > "$CRITERIA_FILE"

  if [ -z "$ROLE" ]; then
    echo "WARN: REVIEWER_ROLE を抽出できませんでした。SKILL.md の形式が想定と異なる可能性があります。" >&2
    rm -f "$CRITERIA_FILE"
  elif [ ! -s "$CRITERIA_FILE" ]; then
    echo "WARN: REVIEW_CRITERIA を抽出できませんでした。" >&2
    rm -f "$CRITERIA_FILE"
  else
    TMP=$(mktemp)
    render_skill_template "$SKILL_TEMPLATE" "$ROLE" "$CRITERIA_FILE" > "$TMP"

    if ! cmp -s "$TMP" "$SKILL_DST"; then
      echo ""
      echo "=== diff: $SKILL_DST (全置換、REVIEWER_ROLE / REVIEW_CRITERIA は保持) ==="
      diff -u "$SKILL_DST" "$TMP" || true
      echo ""
      echo "抽出値:"
      echo "  REVIEWER_ROLE: $ROLE"
      echo "  REVIEW_CRITERIA: $(wc -l < "$CRITERIA_FILE") 行"
      echo ""
      if confirm "SKILL.md を上記の内容で上書きしますか？"; then
        mv "$TMP" "$SKILL_DST"
        updated+=("claude-code-review/SKILL.md")
      else
        echo "SKILL.md の更新をスキップしました。"
        rm -f "$TMP"
      fi
    else
      rm -f "$TMP"
    fi
    rm -f "$CRITERIA_FILE"
  fi
else
  echo "WARN: $SKILL_DST not found — skipping" >&2
fi

# 3) .greptile/config.json を preset 判定して全置換
GREPTILE_DST="$TARGET/.greptile/config.json"
if [ -f "$GREPTILE_DST" ]; then
  # IaC preset 判定（どちらかに該当すれば IaC とみなす）:
  #   a) .github/workflows/checkov.yml が存在する
  #   b) 既存 rules[] に config-iac.json 由来の rule id が含まれる
  if [ -f "$TARGET/.github/workflows/checkov.yml" ] \
     || grep -qE '"id"[[:space:]]*:[[:space:]]*"(iam-no-basic-roles|wif-attribute-condition|iam-use-member-not-binding)"' "$GREPTILE_DST" 2>/dev/null; then
    GREPTILE_SRC="$SKILL_DIR/templates/greptile/config-iac.json"
    GREPTILE_PRESET="iac"
  else
    GREPTILE_SRC="$SKILL_DIR/templates/greptile/config.json"
    GREPTILE_PRESET="generic"
  fi

  if [ ! -f "$GREPTILE_SRC" ]; then
    echo "WARN: $GREPTILE_SRC not found — skipping greptile config update" >&2
  elif ! cmp -s "$GREPTILE_SRC" "$GREPTILE_DST"; then
    echo ""
    echo "=== diff: $GREPTILE_DST (preset=$GREPTILE_PRESET) ==="
    diff -u "$GREPTILE_DST" "$GREPTILE_SRC" || true
    echo ""
    echo "注意: strictness / ignorePatterns / instructions / rules[] 等のローカル調整は上書きで失われます。"
    if confirm ".greptile/config.json を最新テンプレートで上書きしますか？"; then
      cp "$GREPTILE_SRC" "$GREPTILE_DST"
      updated+=(".greptile/config.json")
    else
      echo ".greptile/config.json の更新をスキップしました。"
    fi
  fi
fi

if [ ${#updated[@]} -eq 0 ]; then
  echo "既に最新です。更新不要です。"
else
  echo ""
  echo "更新完了: ${updated[*]}"
  echo "確認のうえ、以下でコミットしてください:"
  add_paths=()
  for f in "${updated[@]}"; do
    case "$f" in
      "claude-review.yml") add_paths+=(".github/workflows/claude-review.yml") ;;
      "claude-code-review/SKILL.md") add_paths+=(".claude/skills/claude-code-review/SKILL.md") ;;
      ".greptile/config.json") add_paths+=(".greptile/config.json") ;;
    esac
  done
  echo "  git -C '$TARGET' add ${add_paths[*]}"
  echo "  git -C '$TARGET' commit -m 'chore: setup-ci-review の最新テンプレートに追随'"
fi
