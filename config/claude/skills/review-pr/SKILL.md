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
# 1. PR メタ情報を取得（gh pr view ベース、gh repo view は引数を受け取れないので使わない）
REPO=$(gh pr view $PR_ARGS --json baseRepository -q '.baseRepository.owner.login + "/" + .baseRepository.name')
PR_NUM=$(gh pr view $PR_ARGS --json number -q .number)
BASE_SHA=$(gh pr view $PR_ARGS --json baseRefOid -q .baseRefOid)
HEAD_SHA=$(gh pr view $PR_ARGS --json headRefOid -q .headRefOid)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
REPO_NAME=$(basename "$REPO")

# 2. files JSON を triage 用フォーマットに変換し、status を正しくマッピング
gh pr view $PR_ARGS --json files \
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
    -o /tmp/review-pr-triage.json
# ↑ stderr は握りつぶさない。失敗したら明示的に止めて原因調査する

# triage 失敗判定（空ファイル / JSON 不正 / size キー欠損のいずれも明示停止）
if [ ! -s /tmp/review-pr-triage.json ] || ! jq -e '.size' /tmp/review-pr-triage.json >/dev/null 2>&1; then
  echo "ERROR: triage failed. /tmp/review-pr-triage.json is empty or invalid." >&2
  echo "ヒント: gh pr view が成功しているか、uv/pyyaml が入っているか確認" >&2
  exit 1
  # ↑ Claude が Bash tool 経由で実行する場合は、exit 後は以降の手順を実行せず、
  #   ユーザーに「triage 失敗」を報告して原因を一緒に調査する
fi

SIZE=$(jq -r '.size' /tmp/review-pr-triage.json)
RISK=$(jq -r '.risk_tags | length' /tmp/review-pr-triage.json)
echo "triage: size=$SIZE risk_tags=$RISK"
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

```bash
# Step 2: bundle 生成
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-bundle.py \
  --triage /tmp/review-pr-triage.json -o /tmp/review-pr-bundle.json

# Step 3a: reviewer プロンプトを 2 本生成
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle /tmp/review-pr-bundle.json --triage /tmp/review-pr-triage.json \
  --reviewer codex-baseline --repo-root "$REPO_NAME:$REPO_ROOT" \
  -o /tmp/review-pr-prompt-codex.txt
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle /tmp/review-pr-bundle.json --triage /tmp/review-pr-triage.json \
  --reviewer opus-baseline --repo-root "$REPO_NAME:$REPO_ROOT" \
  -o /tmp/review-pr-prompt-opus.txt
```

**Step 3b: Agent tool で並列起動（同一メッセージ内で2本同時発行）**

各 subagent に次を指示する:
1. `/tmp/review-pr-prompt-codex.txt`（または opus 版）を Read で読む
2. 指示通り findings を JSON で生成する
3. 返却 JSON を所定のパスに Write する

呼び出し例:

```
Agent(
  subagent_type="general-purpose",
  description="review-pr codex-baseline",
  prompt="Read /tmp/review-pr-prompt-codex.txt then follow it. Write findings JSON to /tmp/raw-codex.json."
)
Agent(
  subagent_type="general-purpose",
  description="review-pr opus-baseline",
  prompt="Read /tmp/review-pr-prompt-opus.txt then follow it. Write findings JSON to /tmp/raw-opus.json."
)
```

両方が完了したら Step 4 へ進む。

```bash
# Step 4: normalize → report
uv run python3 ~/.claude/skills/review-orchestrator/scripts/normalize.py \
  --findings /tmp/raw-codex.json --findings /tmp/raw-opus.json \
  --adapt -o /tmp/review-pr-report.json
uv run python3 ~/.claude/skills/review-orchestrator/scripts/report.py \
  --report /tmp/review-pr-report.json --pr-ref "github.com/$REPO#$PR_NUM"
```

オーケストレーターパスでは以下の手順へ進まず、report.py の出力をそのまま返す。

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
- オーケストレーターパスは `report.py` の出力をそのまま返す。その後に手動でレビューを追記しない
- Codex が「サポートしていない」「動作しない」系の主張をしたら実際にコードを読んで確認してから採用する。未確認の指摘を P0 として出すと信頼性を損なう
- subagent 内から review-pr が呼ばれた場合、triage の `size` / `risk_tags` に関わらずシンプルパス骨格にフォールバックする（Agent tool の再帰呼び出し禁止のため）。出力は `review-pr-reference.md` のフォーマットに従い、`risk_tags` の内容は「注意事項」節に転記する
- triage の `reviewers` が null の場合、オーケストレーターパスでは `codex-baseline` と `opus-baseline` の 2 本を固定で使う
- `build-reviewer-prompt.py` の出力プロンプトに diff セクションが空（「(diff 取得不可)」など）のときは、`git diff $BASE_SHA..$HEAD_SHA` を実行してプロンプトに追記してから subagent に渡す。未対応のまま渡すと findings が生成できない
