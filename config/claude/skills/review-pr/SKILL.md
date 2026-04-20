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

## ルーティング（最初に必ず実行）

PR情報を取得した後、triage でサイズとリスクを判定して実行パスを決定する。

```bash
# 1. PR の changed_files JSON を生成
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR_NUM=$(gh pr view --json number -q .number)
BASE_SHA=$(gh pr view --json baseRefOid -q .baseRefOid)
HEAD_SHA=$(gh pr view --json headRefOid -q .headRefOid)
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO")

gh pr view --json files \
  | python3 -c "
import json,sys,os
files=json.load(sys.stdin)['files']
print(json.dumps([{
  'repo': os.environ.get('REPO_NAME','server'),
  'path': f['path'],
  'status': 'modified',
  'additions': f['additions'],
  'deletions': f['deletions']
} for f in files]))" REPO_NAME="$REPO_NAME" \
  | uv run --with pyyaml python3 ~/.claude/skills/review-triage/scripts/triage.py \
    --pr-ref "github.com/$REPO#$PR_NUM" \
    --base-sha "$BASE_SHA" --head-sha "$HEAD_SHA" \
    --repo "$REPO_NAME:$REPO_ROOT" \
    -o /tmp/review-pr-triage.json 2>/dev/null

SIZE=$(jq -r '.size' /tmp/review-pr-triage.json 2>/dev/null || echo "quick")
RISK=$(jq -r '.risk_tags | length' /tmp/review-pr-triage.json 2>/dev/null || echo "0")
echo "triage: size=$SIZE risk_tags=$RISK"
```

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

1. `gh pr view --comments` / `gh pr diff` / `gh pr checks` で PR 情報取得
2. 既存レビューコメントを確認し重複指摘を避ける
3. Codex を起動（`~/.claude/skills/codex-review/scripts/pane-manager.sh`）しながら自分も diff 分析（並列）
4. Codex 指摘を検証してから採用（技術的主張は必ず裏取り）
5. reference.md の出力フォーマットで統合レビューを作成

## Gotchas

- triage 判定は PR 取得後に行う。PR URL や PR 番号が引数として渡されていれば `gh pr view` のカレントブランチ判定に頼らず明示的に `--repo org/repo` と `PR番号` を指定する
- オーケストレーターパスは `report.py` の出力をそのまま返す。その後に手動でレビューを追記しない
- Codex が「サポートしていない」「動作しない」系の主張をしたら実際にコードを読んで確認してから採用する。未確認の指摘を P0 として出すと信頼性を損なう
- subagent 内から review-pr が呼ばれた場合、triage の `size` / `risk_tags` に関わらずシンプルパス骨格にフォールバックする（Agent tool の再帰呼び出し禁止のため）。出力は `review-pr-reference.md` のフォーマットに従い、`risk_tags` の内容は「注意事項」節に転記する
- triage の `reviewers` が null の場合、オーケストレーターパスでは `codex-baseline` と `opus-baseline` の 2 本を固定で使う
- `build-reviewer-prompt.py` の出力プロンプトに diff セクションが空（「(diff 取得不可)」など）のときは、`git diff $BASE_SHA..$HEAD_SHA` を実行してプロンプトに追記してから subagent に渡す。未対応のまま渡すと findings が生成できない
