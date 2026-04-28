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
#     triggerOnUpdates は既存値を保持（ops / server-config のように true 運用中のリポで
#     テンプレート既定の false に勝手に戻さないため）
#   - 差分を表示してから y/N で確認（--yes で省略可）
#   - コミット・push は行わない
#
# サポート対象外:
#   Tier 3 化（Greptile 完全撤去）は本スクリプトでは扱わない。GitHub App uninstall →
#   .greptile/ 削除 → CLAUDE.md 整理の順序で手動実施する。詳細は reference.md の
#   「Tier 分類」セクションを参照。
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
  # `です。` 直前のスペース有無は世代によってブレる（古い SKILL.md は
  # 「シニアエンジニアです。」、新しいテンプレートは「シニアエンジニア です。」）。
  # 両方を許容するため正規表現でスペースを optional に扱い、末尾の空白も trim する。
  # awk を使うのは他の extract_* と実装を揃え、BSD sed のロケール依存挙動を避けるため。
  awk '
    /^あなたは .*です。このPRをレビューします。$/ {
      line = $0
      sub(/^あなたは /, "", line)
      sub(/ ?です。このPRをレビューします。$/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  ' "$1"
}

# `## 役割` セクションの 3 番目の項目（一貫性チェックの責務記述）を抽出する。
# 旧テンプレート（"3. 既存コードとの一貫性チェックは Greptile が担当するため..."）と
# 新テンプレート（"3. 既存コードとの一貫性チェックも自分で行う..." 等、Greptile 非選択時）の
# どちらの文面でも汎用的に拾えるよう "^3\. " で始まる最初の行をターゲットにする。
extract_consistency() {
  awk '
    /^3\. / && !found {
      sub(/^3\. /, "")
      print
      found=1
      exit
    }
  ' "$1"
}

extract_criteria() {
  awk '
    /^3\. / && !flag { flag=1; next }
    /^## 優先度ラベル/ && flag { exit }
    flag { print }
  ' "$1" | trim_blank_lines
}

render_skill_template() {
  # $1: template, $2: role string, $3: criteria file path, $4: consistency delegation string
  awk -v role="$2" -v cfile="$3" -v consistency="$4" '
    {
      line = $0
      gsub(/\{\{REVIEWER_ROLE\}\}/, role, line)
      # gsub は右辺の & を特殊扱いするため、index ベースで安全に置換する
      idx = index(line, "{{CONSISTENCY_DELEGATION}}")
      if (idx > 0) {
        line = substr(line, 1, idx - 1) consistency substr(line, idx + length("{{CONSISTENCY_DELEGATION}}"))
      }
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

# 2) SKILL.md を全置換（REVIEWER_ROLE / REVIEW_CRITERIA / CONSISTENCY_DELEGATION は保持）
if [ -f "$SKILL_DST" ]; then
  ROLE=$(extract_role "$SKILL_DST")
  CONSISTENCY=$(extract_consistency "$SKILL_DST")
  CRITERIA_FILE=$(mktemp)
  extract_criteria "$SKILL_DST" > "$CRITERIA_FILE"

  if [ -z "$ROLE" ]; then
    echo "WARN: REVIEWER_ROLE を抽出できませんでした。SKILL.md の形式が想定と異なる可能性があります。" >&2
    rm -f "$CRITERIA_FILE"
  elif [ -z "$CONSISTENCY" ]; then
    echo "WARN: CONSISTENCY_DELEGATION を抽出できませんでした（## 役割 セクションの 3 番目の項目が想定形式と異なります）。" >&2
    rm -f "$CRITERIA_FILE"
  elif [ ! -s "$CRITERIA_FILE" ]; then
    echo "WARN: REVIEW_CRITERIA を抽出できませんでした。" >&2
    rm -f "$CRITERIA_FILE"
  else
    TMP=$(mktemp)
    render_skill_template "$SKILL_TEMPLATE" "$ROLE" "$CRITERIA_FILE" "$CONSISTENCY" > "$TMP"

    if ! cmp -s "$TMP" "$SKILL_DST"; then
      echo ""
      echo "=== diff: $SKILL_DST (全置換、REVIEWER_ROLE / REVIEW_CRITERIA / CONSISTENCY_DELEGATION は保持) ==="
      diff -u "$SKILL_DST" "$TMP" || true
      echo ""
      echo "抽出値:"
      echo "  REVIEWER_ROLE: $ROLE"
      echo "  CONSISTENCY_DELEGATION: $CONSISTENCY"
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

  # 既存の triggerOnUpdates 値を抽出（ops / server-config のように true で運用中のリポで
  # テンプレート置換により勝手に false に戻らないようにする）。抽出失敗時はテンプレート既定の false を採用。
  EXISTING_TRIGGER=$(grep -Eo '"triggerOnUpdates"[[:space:]]*:[[:space:]]*(true|false)' "$GREPTILE_DST" 2>/dev/null \
    | grep -Eo '(true|false)' | head -1)

  if [ ! -f "$GREPTILE_SRC" ]; then
    echo "WARN: $GREPTILE_SRC not found — skipping greptile config update" >&2
  else
    # テンプレートを一時ファイルに展開し、既存の triggerOnUpdates 値を書き戻してから比較する
    GREPTILE_TMP=$(mktemp)
    cp "$GREPTILE_SRC" "$GREPTILE_TMP"
    if [ "$EXISTING_TRIGGER" = "true" ]; then
      # macOS / Linux 両対応で in-place 編集
      sed -i.bak 's/"triggerOnUpdates": false,/"triggerOnUpdates": true,/' "$GREPTILE_TMP"
      rm -f "$GREPTILE_TMP.bak"
    fi

    if ! cmp -s "$GREPTILE_TMP" "$GREPTILE_DST"; then
      echo ""
      echo "=== diff: $GREPTILE_DST (preset=$GREPTILE_PRESET, triggerOnUpdates=${EXISTING_TRIGGER:-false} を保持) ==="
      diff -u "$GREPTILE_DST" "$GREPTILE_TMP" || true
      echo ""
      echo "注意: strictness / ignorePatterns / instructions / rules[] 等のローカル調整は上書きで失われます。"
      echo "      triggerOnUpdates は既存値を保持しています（ops / server-config 等での true 運用を壊さないため）。"
      if confirm ".greptile/config.json を最新テンプレートで上書きしますか？"; then
        mv "$GREPTILE_TMP" "$GREPTILE_DST"
        updated+=(".greptile/config.json")
      else
        echo ".greptile/config.json の更新をスキップしました。"
        rm -f "$GREPTILE_TMP"
      fi
    else
      rm -f "$GREPTILE_TMP"
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
