#!/usr/bin/env bash
# update-existing.sh の抽出ロジック (extract_role / extract_consistency / extract_criteria) を
# 合成した SKILL.md に対して実行し、想定どおり抽出できることを検証する。
#
# 使い方:
#   bash scripts/test-update-existing.sh
#
# 失敗時は非ゼロで exit する。CI に組み込む場合はそのまま使える。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/update-existing.sh"

if [ ! -f "$TARGET_SCRIPT" ]; then
  echo "ERROR: update-existing.sh not found at $TARGET_SCRIPT" >&2
  exit 1
fi

# update-existing.sh の関数を eval で取り込むのは行数が多く副作用も大きいため、
# extract_role / extract_consistency / extract_criteria の実装をここに複製して検証する。
# 本物の関数定義との同期は必要だが、テスト対象が pure function（標準入出力のみ）なので
# 複製コストよりも eval 副作用のリスク回避を優先する。

extract_role() {
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

extract_criteria() {
  awk '
    /^3\. / && !flag { flag=1; next }
    /^## 優先度ラベル/ && flag { exit }
    flag { print }
  ' "$1" | trim_blank_lines
}

# update-existing.sh 内の関数定義と本テストの複製が乖離していないか、簡易的に検証する。
# extract_role の awk 1 行目のシグネチャだけ突き合わせる（フルマッチは保守コストが高いため）。
verify_in_sync() {
  local expected='/^あなたは .*です。このPRをレビューします。$/'
  if ! grep -qF "$expected" "$TARGET_SCRIPT"; then
    echo "FAIL: update-existing.sh の extract_role 実装がテスト側と乖離しています。" >&2
    echo "      期待するパターン: $expected" >&2
    return 1
  fi
}

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    echo "  expected: [$expected]"
    echo "  actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ケース1: 新形式（です。直前にスペースあり）
cat > "$TMPDIR/new-format.md" <<'EOF'
# PR コードレビュー

あなたは Marp / Markdown スライド制作に精通したシニアエンジニア です。このPRをレビューします。
EOF
run_test "extract_role: 新形式 (スペースあり)" \
  "$(extract_role "$TMPDIR/new-format.md")" \
  "Marp / Markdown スライド制作に精通したシニアエンジニア"

# ケース2: 旧形式（です。直前にスペースなし）
cat > "$TMPDIR/old-format.md" <<'EOF'
# PR コードレビュー

あなたは Marp / Markdown スライド制作に精通したシニアエンジニアです。このPRをレビューします。
EOF
run_test "extract_role: 旧形式 (スペースなし)" \
  "$(extract_role "$TMPDIR/old-format.md")" \
  "Marp / Markdown スライド制作に精通したシニアエンジニア"

# ケース3: ASCII のみ
cat > "$TMPDIR/ascii.md" <<'EOF'
あなたは senior backend engineer です。このPRをレビューします。
EOF
run_test "extract_role: ASCII" \
  "$(extract_role "$TMPDIR/ascii.md")" \
  "senior backend engineer"

# ケース4: 全角括弧を含む（incbot 実例）
cat > "$TMPDIR/parens.md" <<'EOF'
あなたは TypeScript / Node.js および Slack Bolt / GCP（Cloud Run, Firestore, Secret Manager, Vertex AI）に精通したシニアエンジニアです。このPRをレビューします。
EOF
run_test "extract_role: 全角括弧+旧形式" \
  "$(extract_role "$TMPDIR/parens.md")" \
  "TypeScript / Node.js および Slack Bolt / GCP（Cloud Run, Firestore, Secret Manager, Vertex AI）に精通したシニアエンジニア"

# ケース5: ROLE 行が無い（server のような全面カスタム SKILL.md）
cat > "$TMPDIR/no-role.md" <<'EOF'
# PR コードレビュー

## レビューガイドライン
EOF
run_test "extract_role: ROLE 行なし → 空文字" \
  "$(extract_role "$TMPDIR/no-role.md")" \
  ""

# ケース6: extract_consistency と extract_criteria を実テンプレート相当の構造で検証する。
# render_skill_template が REVIEW_CRITERIA に挿入するのは「## レビュー観点」セクション全体
# （見出し含む、## 優先度ラベル の手前まで）なので、それに合わせた fixture を組む。
cat > "$TMPDIR/full.md" <<'EOF'
あなたは generic engineer です。このPRをレビューします。

## 役割

1. トリアージ
2. 重要度ラベル
3. 既存コードとの一貫性チェックは Greptile が担当するため、本レビューでは省略する。

## レビュー観点

1. アーキテクチャ整合性
2. プロジェクト固有ルール
3. 機能フラグの導入確認

## 優先度ラベル

P0: ブロッカー
EOF
run_test "extract_consistency" \
  "$(extract_consistency "$TMPDIR/full.md")" \
  "既存コードとの一貫性チェックは Greptile が担当するため、本レビューでは省略する。"

# extract_criteria は consistency 行の直後から ## 優先度ラベル の手前まで（trim 済み）
expected_criteria="## レビュー観点

1. アーキテクチャ整合性
2. プロジェクト固有ルール
3. 機能フラグの導入確認"
run_test "extract_criteria" \
  "$(extract_criteria "$TMPDIR/full.md")" \
  "$expected_criteria"

echo ""
if verify_in_sync; then
  echo "PASS: update-existing.sh と sync OK"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
fi

echo ""
echo "結果: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
