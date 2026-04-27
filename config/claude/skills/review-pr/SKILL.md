---
name: review-pr
description: PRを体系的にレビューして実行可能なフィードバックを提供。PRの規模・リスクを自動判定し、小さいPRは単独レビュー、大きいPRはマルチエージェントレビューに自動ルーティングする。「PRレビュー」「コードレビュー」「レビューして」「review」「review-pr」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /review-pr - 体系的なPRレビュー

このPRを体系的にレビューし、実行可能なフィードバックを提供してください。

> バイブコーディング用: `/vibe-review pr`

## Prerequisites

実行前に確認する。無い場合の振る舞いを併記。

| ツール | 用途 | 無い場合 |
|---|---|---|
| `gh` | PR情報取得 | 必須。エラーで停止 |
| `uv` `python3` | triage 実行 | 必須。エラーで停止 |
| `jq` | triage 結果のパース | 必須。エラーで停止 |
| `tmux` または `cmux` セッション | Codex pane起動 | スキップして単独レビュー |
| Codex CLI (`~/.claude/skills/codex-review/scripts/pane-manager.sh`) | 並列分析 | スキップして単独レビュー |
| `ghq` | リポジトリ取得（オーケストレーターパス） | 必須。無い環境では事前準備スニペットの `ghq get` を `git clone https://github.com/$REPO $HOME/src/github.com/$REPO` で置き換える |

呼び出し元（subagent vs 親セッション）を判定する手段は無い。subagent 経由で呼ぶ場合は **呼び出し側が prompt 冒頭または環境変数で `IS_SUBAGENT=1` を渡す**。Claude はこれを検出した時点でシンプルパス骨格にフォールバックする（Agent tool の再帰呼び出し禁止のため）。判定ロジックは下の「subagent 内呼び出しのフォールバック判定」節を参照。

## 変数の役割（混同注意）

| 変数 | 値の例 | 用途 |
|---|---|---|
| `$REPO` | `org/repo`（nameWithOwner） | `gh` API への引数、`--pr-ref` のキー |
| `$REPO_NAME` | `repo`（basename） | `--repo` 引数の名前部分、bundle 内の repo フィールド |
| `$REPO_ROOT` | `/Users/.../repo` | ローカルのファイルシステムパス |

## PR の特定

`gh pr view` はカレントブランチで PR を解決する。引数で URL または PR 番号が渡された場合はそちらを優先する。

Claude が Bash tool で実行する場合は、user message から PR 番号 / URL を抽出して `set -- "<value>"` で位置パラメータに入れてから下のスニペットを流す。何も渡されないときは `set --` で空にする。以降の `$PR_ARGS` は **クオートしない** こと（`--repo X 123` のように複数トークンを含むため、`"$PR_ARGS"` で囲うと単一引数化されて壊れる）。

```bash
# $1 に渡された値で PR_ARGS を組み立てる
case "${1:-}" in
  https://github.com/*)
    # URL 例: https://github.com/org/repo/pull/123
    _owner_repo=$(echo "$1" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/.*#\1#')
    _pr_num=$(echo "$1" | sed -E 's#.*/pull/([0-9]+).*#\1#')
    PR_ARGS="--repo $_owner_repo $_pr_num"
    ;;
  ''|-*)
    # 引数なし、またはオプションのみ → カレントブランチで解決
    PR_ARGS=""
    ;;
  *)
    # 数字のみ → カレントリポジトリの PR 番号
    PR_ARGS="$1"
    ;;
esac
```

以降のスニペットは `gh pr view $PR_ARGS` の形で呼び出す前提で読む。

## subagent 内呼び出しのフォールバック判定

呼び出し側 prompt に「subagent 内である」という明示があるか、Agent tool 経由で起動された自覚がある場合は、ルーティングをスキップしてシンプルパスへ直行する。Agent tool の再帰呼び出し禁止のため、triage が standard/deep を返してもオーケストレーターパスは選ばない。

```bash
# 呼び出し側が IS_SUBAGENT=1 を渡している、または prompt 内で明示している場合
IS_SUBAGENT="${IS_SUBAGENT:-0}"
if [ "$IS_SUBAGENT" = "1" ]; then
  echo "subagent context: skipping triage, going to simple path"
  # → そのままシンプルパス手順 1 へ
else
  # → 下のルーティング節へ
  :
fi
```

## ルーティング（subagent 外でのみ実行）

PR情報を取得した後、triage でサイズとリスクを判定して実行パスを決定する。

```bash
# 1. PR メタ情報を一括取得（一部 gh バージョンは baseRepository フィールド非対応のため URL から REPO を抽出する）
_META=$(gh pr view $PR_ARGS --json number,url,baseRefOid,headRefOid 2>/dev/null)
PR_NUM=$(echo "$_META" | jq -r '.number')
PR_URL=$(echo "$_META" | jq -r '.url')
REPO=$(echo "$PR_URL" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/.*#\1#')
BASE_SHA=$(echo "$_META" | jq -r '.baseRefOid')
HEAD_SHA=$(echo "$_META" | jq -r '.headRefOid')
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
REPO_NAME=$(basename "$REPO")

# 取得失敗時は明示停止（PR_NUM が空 = gh pr view が失敗している）
if [ -z "$PR_NUM" ] || [ "$PR_NUM" = "null" ] || [ -z "$REPO" ]; then
  echo "ERROR: failed to resolve PR metadata. Check gh auth / PR_ARGS." >&2
  exit 1
fi

# 中間ファイルは PR_NUM 付きの一意パスにする（同時複数セッションでの上書き事故を防ぐ）
WORK="/tmp/review-pr-${PR_NUM}"
TRIAGE="${WORK}-triage.json"
BUNDLE="${WORK}-bundle.json"
REPORT="${WORK}-report.json"

# 2. files JSON を triage 用フォーマットに変換し、status を正しくマッピング
gh pr view $PR_ARGS --json files 2>/dev/null \
  | REPO_NAME="$REPO_NAME" python3 -c "
import json,sys,os
status_map = {
    'added': 'added',
    'modified': 'modified',
    'removed': 'deleted',
    'renamed': 'renamed',
    'copied': 'modified',
    'changed': 'modified',
}
files = json.load(sys.stdin)['files']
out = []
for f in files:
    raw = f.get('status') or 'modified'
    out.append({
        'repo': os.environ['REPO_NAME'],
        'path': f['path'],
        'status': status_map.get(raw, 'modified'),
        'additions': f['additions'],
        'deletions': f['deletions'],
    })
print(json.dumps(out))" \
  | uv run --with pyyaml python3 ~/.claude/skills/review-triage/scripts/triage.py \
    --pr-ref "github.com/$REPO#$PR_NUM" \
    --base-sha "$BASE_SHA" --head-sha "$HEAD_SHA" \
    --repo "$REPO_NAME:$REPO_ROOT" \
    -o "$TRIAGE"
# ↑ stderr は握りつぶさない。失敗したら明示的に止めて原因調査する

# triage 失敗判定（空ファイル / JSON 不正 / size キー欠損のいずれも明示停止）
if [ ! -s "$TRIAGE" ] || ! jq -e '.size' "$TRIAGE" >/dev/null 2>&1; then
  echo "ERROR: triage failed. $TRIAGE is empty or invalid." >&2
  echo "ヒント: gh pr view が成功しているか、uv/pyyaml が入っているか確認" >&2
  exit 1
  # ↑ Claude が Bash tool 経由で実行する場合は、exit 後は以降の手順を実行せず、
  #   ユーザーに「triage 失敗」を報告して原因を一緒に調査する
fi

SIZE=$(jq -r '.size' "$TRIAGE")
RISK=$(jq -r '.risk_tags | length' "$TRIAGE")
echo "triage: size=$SIZE risk_tags=$RISK (work=$WORK)"
```

silent fallback で安易に quick 扱いすると本来オーケストレーターが必要な PR を取りこぼすため、必ず明示停止する。

**判定結果に応じて分岐:**

- `size=quick` かつ `risk_tags=0` → **シンプルパス**（以下の「実行手順」へ）
- それ以外（`standard` / `deep` / risk あり）→ **オーケストレーターパス**

### オーケストレーターパス

**前提: このパスは親 Claude Code セッションからのみ実行する。** subagent の内部から review-pr を呼ばれた場合は Agent tool の再帰呼び出しを避けるため、下のシンプルパス骨格にフォールバックする。

**事前準備: レビュー対象リポジトリがローカルに無い場合**

```bash
# REPO_ROOT が空 or 該当リポジトリでないなら clone or worktree で取得
if [ ! -d "$REPO_ROOT/.git" ] || ! git -C "$REPO_ROOT" remote get-url origin | grep -q "$REPO"; then
  # ghq 経由で未取得なら clone、あれば pr checkout
  ghq get "github.com/$REPO" 2>/dev/null || true
  REPO_ROOT=$(ghq root)/github.com/$REPO
  (cd "$REPO_ROOT" && gh pr checkout "$PR_NUM" --repo "$REPO")
fi
```

中間ファイルはルーティングで定義済みの `$WORK` プレフィックス（`/tmp/review-pr-${PR_NUM}`）を使う。triage の `selected_reviewers` に含まれる reviewer を対象とする（null の場合は `codex-baseline` と `opus-baseline` の 2 本を固定）。

```bash
# Step 2: bundle 生成
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-bundle.py \
  --triage "$TRIAGE" -o "$BUNDLE"

# Step 3a: reviewer プロンプトを selected_reviewers 分生成
#   例: codex-baseline と opus-baseline の 2 本のみの場合
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle "$BUNDLE" --triage "$TRIAGE" \
  --reviewer codex-baseline --repo-root "$REPO_NAME:$REPO_ROOT" \
  -o "${WORK}-prompt-codex-baseline.txt"
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle "$BUNDLE" --triage "$TRIAGE" \
  --reviewer opus-baseline --repo-root "$REPO_NAME:$REPO_ROOT" \
  -o "${WORK}-prompt-opus-baseline.txt"
# selected_reviewers に security-review-opus / security-review-codex / cross-repo 等が入っていれば
# 同じ要領で ${WORK}-prompt-<reviewer>.txt に出力する
```

**Step 3b: Agent tool で並列起動（同一メッセージ内で全 reviewer 同時発行）**

各 subagent に次を指示する:
1. `${WORK}-prompt-<reviewer>.txt` を Read で読む
2. 指示通り findings を JSON で生成する
3. 返却 JSON を `${WORK}-raw-<reviewer>.json` に Write する

呼び出し例:

```
Agent(
  subagent_type="general-purpose",
  description="review-pr codex-baseline",
  prompt="Read ${WORK}-prompt-codex-baseline.txt then follow it. Write findings JSON to ${WORK}-raw-codex-baseline.json."
)
Agent(
  subagent_type="general-purpose",
  description="review-pr opus-baseline",
  prompt="Read ${WORK}-prompt-opus-baseline.txt then follow it. Write findings JSON to ${WORK}-raw-opus-baseline.json."
)
```

`${WORK}` はリテラルに展開した実パス（例 `/tmp/review-pr-6919-prompt-codex-baseline.txt`）を Agent の prompt に渡す。subagent は shell 変数を読まないためここで変数を残してはいけない。

全 reviewer が完了したら Step 4 へ進む。

```bash
# Step 4: normalize → report（--findings は生成した raw JSON 全てを列挙する）
uv run python3 ~/.claude/skills/review-orchestrator/scripts/normalize.py \
  --findings "${WORK}-raw-codex-baseline.json" \
  --findings "${WORK}-raw-opus-baseline.json" \
  --adapt -o "$REPORT"
uv run python3 ~/.claude/skills/review-orchestrator/scripts/report.py \
  --report "$REPORT" --pr-ref "github.com/$REPO#$PR_NUM"
```

オーケストレーターパスでは以下の手順へ進まず、report.py の出力をそのまま返す。
report.py の出力はツール結果に流れるだけで、ユーザーには届かない。**必ず最終テキストメッセージで report.py の出力全文をそのまま貼り付けてユーザーに伝えること。** 要約に圧縮せず、全 findings を掲載する。

---

## 実行手順（シンプルパス: quick かつ risk なし）

詳細な手順・優先度基準・出力フォーマットは `${CLAUDE_SKILL_DIR}/review-pr-reference.md` を参照する。
必要時のみ読み込む（毎回ロード不要）。

骨格:

1. `gh pr view $PR_ARGS --comments` / `gh pr diff $PR_ARGS` / `gh pr checks $PR_ARGS` で PR 情報取得
2. 既存レビューコメントを確認し重複指摘を避ける
3. Codex pane manager を起動して並列分析を試みる:
   - tmux/cmux セッション内、かつ `~/.claude/skills/codex-review/scripts/pane-manager.sh` が存在し、起動が成功した場合 → 並列で Codex の指摘を待ちつつ、自分も diff 分析
   - tmux/cmux 外、Codex CLI 不在、起動失敗、subagent 内呼び出しのいずれかに該当する場合 → Codex は使わず単独で diff 分析する。スキップ理由を最終出力の「注意事項」節に 1 行で明示
4. Codex を使った場合: 指摘を検証してから採用（技術的主張は必ず裏取り）。使わなかった場合: ステップ 4 はスキップ
5. reference.md の出力フォーマットで統合レビューを作成

## Gotchas

- triage 判定は PR 取得後に行う。PR URL や PR 番号が引数として渡されていれば `gh pr view` のカレントブランチ判定に頼らず明示的に `--repo org/repo` と `PR番号` を指定する
- 中間ファイルは必ず PR 番号付きの `${WORK}` プレフィックスを使う。`/tmp/review-pr-triage.json` などの固定パスは複数セッションで衝突するため使用禁止
- `gh pr view --json baseRepository` は一部 gh バージョンで `Unknown JSON field` になる。REPO は `--json url` の PR URL から正規表現で抽出する（ルーティング節のスニペット参照）
- `gh` 実行時に shell profile 由来の noise（例: `gh:1: command not found: _gh_ensure_token`）が stderr に混ざる環境では `2>/dev/null` を付けて stdout の jq パースが壊れないようにする
- オーケストレーターパスは `report.py` の出力をそのまま返す。その後に手動でレビューを追記しない
- レビュー結果はユーザーへの出力として返すだけで終了する。`gh pr review` / `gh pr comment` 等で GitHub に投稿するかどうかはユーザーが判断する。**ユーザーから明示的に「投稿して」と指示されるまで書き込み操作は行わない**
- Codex が「サポートしていない」「動作しない」系の主張をしたら実際にコードを読んで確認してから採用する。未確認の指摘を P0 として出すと信頼性を損なう
- subagent 内から review-pr が呼ばれた場合、triage の `size` / `risk_tags` に関わらずシンプルパス骨格にフォールバックする（Agent tool の再帰呼び出し禁止のため）。出力は `review-pr-reference.md` のフォーマットに従い、`risk_tags` の内容は「注意事項」節に転記する
- triage の `selected_reviewers` が null または空の場合、オーケストレーターパスでは `codex-baseline` と `opus-baseline` の 2 本を固定で使う。非 null の場合はその全員分のプロンプトを生成して並列起動する
- `build-reviewer-prompt.py` の出力プロンプトに diff セクションが空（「(diff 取得不可)」など）のときは、`git diff $BASE_SHA..$HEAD_SHA` を実行してプロンプトに追記してから subagent に渡す。未対応のまま渡すと findings が生成できない
- 書き込み系 gh 呼び出し（`gh api -X POST/PUT/PATCH/DELETE`、`gh pr review`、`gh pr comment`、`gh pr merge`、`gh issue comment` 等）は、**絶対に `|| fallback` やリトライを付けない**。`gh api -X POST ... 2>&1 | jq ... || gh api -X POST ...` のようなパターンは、`_gh_ensure_token` 等の stderr noise が `2>&1` で stdout に混ざると jq が parse error になり、右辺が発火して同じ POST が 2 回飛び、PR レビューやコメントが二重投稿される（2026-04-24 に実際に発生）。冪等でない副作用のあるコマンドは 1 回だけ実行し、結果確認は別コマンドで後から取得する。どうしても結果 JSON をパースしたい場合は `gh api ... -X POST --input ... > /tmp/resp.json` で一度ファイルに落としてから `jq < /tmp/resp.json` する
- レビュー投稿前は `gh api repos/$REPO/pulls/$PR_NUM/reviews` で直近のレビュー一覧を確認し、同じ `commit_id` かつ自分の user で 60 秒以内の review が既にあれば再投稿を止める。race condition での二重投稿を防ぐため
