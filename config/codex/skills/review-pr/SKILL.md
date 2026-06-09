---
name: review-pr
description: PRを体系的にレビューして実行可能なフィードバックを提供。Codexではgh/triage/既存レビュー確認を行い、明示的に並列レビューやマルチエージェントレビューを依頼された場合のみCodex subagentへ分担する。「PRレビュー」「コードレビュー」「レビューして」「review」「review-pr」等で起動。
---

# /review-pr - Codex-first PRレビュー

このPRを体系的にレビューし、実行可能なフィードバックを提供する。

> バイブコーディング用: `/vibe-review pr`

## 実行原則

- Codexではこのskillを直接実行する。Codex自身が主レビューワーであり、別paneのCodex起動は標準経路にしない。
- このskillはCodex専用forkとして `config/codex/skills/review-pr` 配下に置く。Claude Code用の `config/claude/skills/review-pr` は変更しない。
- Codex subagent / multi-agent tool は、ユーザーが「並列」「マルチエージェント」「subagentで」などを明示した場合だけ使う。明示がなければ、同じ観点をCodexがローカルで複数パスとして読む。
- レビュー結果はユーザーへの出力として返すだけで終了する。ユーザーから明示的に「投稿して」と指示されるまで `gh pr review` / `gh pr comment` / GitHub connectorの書き込み操作は行わない。
- 既存レビュー、PRコメント、CI/checksを必ず確認し、重複指摘や解決済み前提の指摘を避ける。

## Prerequisites

実行前に確認する。無い場合の振る舞いを併記。

| ツール | 用途 | 無い場合 |
|---|---|---|
| `gh` | PR情報、diff、checks、既存レビュー取得 | 必須。`gh auth status` も含めて原因確認 |
| `jq` | JSONパース | 必須。エラーで停止 |
| `python3` | triage/orchestratorスクリプト実行 | 必須。エラーで停止 |
| `uv` | `pyyaml` が無い場合のtriage依存解決 | `python3 -c "import yaml"` が通れば不要 |
| `ghq` | レビュー対象リポジトリの取得 | 無ければ `git clone https://github.com/$REPO $HOME/src/github.com/$REPO` で代替 |
| Codex multi-agent tools | 明示的な並列レビュー時のreviewer分担 | 無ければローカル複数パスでレビュー |

## 共通初期化

以降のスニペットは最初にこの初期化を流してから読む。Codexでは `~/.agents/skills` を優先し、未インストール環境だけ `~/.claude/skills` にfallbackする。

```bash
SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
if [ ! -d "$SKILLS_DIR/review-pr" ] && [ -d "$HOME/.claude/skills/review-pr" ]; then
  SKILLS_DIR="$HOME/.claude/skills"
fi

REVIEW_PR_DIR="$SKILLS_DIR/review-pr"
REVIEW_TRIAGE_DIR="$SKILLS_DIR/review-triage"
REVIEW_ORCH_DIR="$SKILLS_DIR/review-orchestrator"
REVIEW_PR_REFERENCE="$REVIEW_PR_DIR/review-pr-reference.md"
TRIAGE_SCRIPT="$REVIEW_TRIAGE_DIR/scripts/triage.py"
REVIEW_PROMPT_SCRIPT="$REVIEW_PR_DIR/scripts/build-reviewer-prompt.py"
if [ ! -f "$REVIEW_PROMPT_SCRIPT" ]; then
  REVIEW_PROMPT_SCRIPT="$REVIEW_ORCH_DIR/scripts/build-reviewer-prompt.py"
fi

if [ ! -f "$REVIEW_PR_REFERENCE" ] || [ ! -f "$TRIAGE_SCRIPT" ] || [ ! -f "$REVIEW_PROMPT_SCRIPT" ]; then
  echo "ERROR: review-pr skill dependencies are missing under $SKILLS_DIR" >&2
  exit 1
fi
```

## 変数の役割

| 変数 | 値の例 | 用途 |
|---|---|---|
| `$REPO` | `org/repo` | `gh` APIへの引数、`--pr-ref` のキー |
| `$REPO_NAME` | `repo` | `--repo` 引数の名前部分、bundle内のrepoフィールド |
| `$REPO_ROOT` | `/Users/.../repo` | ローカルのファイルシステムパス |
| `$WORK` | `$HOME/.cache/review-pr/123` | PRごとの中間ファイル置き場 |

## PRの特定

`gh pr view` はカレントブランチでPRを解決する。引数でURLまたはPR番号が渡された場合はそちらを優先する。

ユーザーメッセージからPR番号またはURLを抽出し、`set -- "<value>"` で位置パラメータに入れてから下のスニペットを流す。何も渡されないときは `set --` で空にする。以降の `$PR_ARGS` は **クオートしない**。`--repo X 123` のように複数トークンを含むため、`"$PR_ARGS"` で囲うと単一引数化されて壊れる。

```bash
case "${1:-}" in
  https://github.com/*)
    _owner_repo=$(echo "$1" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/.*#\1#')
    _pr_num=$(echo "$1" | sed -E 's#.*/pull/([0-9]+).*#\1#')
    PR_ARGS="--repo $_owner_repo $_pr_num"
    ;;
  ''|-*)
    PR_ARGS=""
    ;;
  *)
    PR_ARGS="$1"
    ;;
esac
```

以降のスニペットは `gh pr view $PR_ARGS` の形で呼び出す前提で読む。

## ルーティング

PR情報を取得した後、triageでサイズとリスクを判定して実行パスを決める。

```bash
_META=$(gh pr view $PR_ARGS --json number,url,baseRefOid,headRefOid 2>/dev/null)
PR_NUM=$(echo "$_META" | jq -r '.number')
PR_URL=$(echo "$_META" | jq -r '.url')
REPO=$(echo "$PR_URL" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/.*#\1#')
BASE_SHA=$(echo "$_META" | jq -r '.baseRefOid')
HEAD_SHA=$(echo "$_META" | jq -r '.headRefOid')
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
REPO_NAME=$(basename "$REPO")

if [ -z "$PR_NUM" ] || [ "$PR_NUM" = "null" ] || [ -z "$REPO" ]; then
  echo "ERROR: failed to resolve PR metadata. Check gh auth / PR_ARGS." >&2
  exit 1
fi

WORK="$HOME/.cache/review-pr/${PR_NUM}"
mkdir -p "$WORK"
TRIAGE="$WORK/triage.json"
BUNDLE="$WORK/bundle.json"
REPORT="$WORK/report.json"

if python3 -c "import yaml" >/dev/null 2>&1; then
  TRIAGE_RUNNER=(python3 "$TRIAGE_SCRIPT")
elif command -v uv >/dev/null 2>&1; then
  TRIAGE_RUNNER=(uv run --with pyyaml python3 "$TRIAGE_SCRIPT")
else
  echo "ERROR: pyyaml is missing and uv is not available." >&2
  exit 1
fi

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
  | "${TRIAGE_RUNNER[@]}" \
    --pr-ref "github.com/$REPO#$PR_NUM" \
    --base-sha "$BASE_SHA" --head-sha "$HEAD_SHA" \
    --repo "$REPO_NAME:$REPO_ROOT" \
    -o "$TRIAGE"

if [ ! -s "$TRIAGE" ] || ! jq -e '.size' "$TRIAGE" >/dev/null 2>&1; then
  echo "ERROR: triage failed. $TRIAGE is empty or invalid." >&2
  echo "ヒント: gh pr view が成功しているか、python3/pyyaml/uv が入っているか確認" >&2
  exit 1
fi

SIZE=$(jq -r '.size' "$TRIAGE")
RISK=$(jq -r '.risk_tags | length' "$TRIAGE")
echo "triage: size=$SIZE risk_tags=$RISK (work=$WORK)"
```

silent fallbackでquick扱いにしない。triageが失敗した場合は明示停止して原因を調査する。

**判定結果に応じた分岐:**

- `size=quick` かつ `risk_tags=0` → シンプルパス
- それ以外 (`standard` / `deep` / riskあり) → オーケストレーターパス

## 事前コンテキスト取得

シンプルパスでもオーケストレーターパスでも、既存レビューとコメントは先に取る。

```bash
gh api "repos/$REPO/pulls/$PR_NUM/reviews" 2>/dev/null \
  | jq '[.[] | {user: .user.login, state, commit_id, submitted_at, body}]' \
  > "$WORK/existing-reviews.json"
gh pr view $PR_ARGS --json comments 2>/dev/null \
  | jq '.comments | [.[] | {author: .author.login, body, createdAt}]' \
  > "$WORK/existing-comments.json"
gh pr checks $PR_ARGS > "$WORK/checks.txt" 2>&1 || true

gh pr view $PR_ARGS --json body,commits 2>/dev/null \
  | jq -r '.body, (.commits[].messageBody // "")' \
  | grep -oE '\b(PF|ASICS|SRV|WT)-[0-9]+\b' | sort -u \
  > "$WORK/referenced-issues.txt" || true
```

Linear connector/toolが使える環境では、`$WORK/referenced-issues.txt` のIssue状態を確認してreviewer promptまたは最終出力の注意事項へ反映する。使えない場合は「Linear状態未確認」と明示し、Issue完了/未完了を前提にした指摘は避ける。

## シンプルパス

詳細な優先度基準と出力フォーマットは `$REVIEW_PR_REFERENCE` を必要時だけ読む。

骨格:

1. `gh pr view $PR_ARGS --comments` / `gh pr diff $PR_ARGS` / `gh pr checks $PR_ARGS` でPR情報を取得する
2. `$WORK/existing-reviews.json` と `$WORK/existing-comments.json` を読んで重複指摘を避ける
3. diffを読み、`review-pr-reference.md` の観点に従ってレビューする
4. 最終出力はfindings優先で、GitHub投稿はしない

## オーケストレーターパス

`standard` / `deep` / riskありでは、triageのreviewer観点を使う。Codex subagentを使えるのはユーザーが明示的に並列レビューを依頼した場合だけ。明示がない場合は、生成されたreviewer promptをCodex自身が順番に読み、同じ観点でローカルレビューする。

**事前準備: レビュー対象リポジトリがローカルに無い場合**

```bash
if [ ! -d "$REPO_ROOT/.git" ] || ! git -C "$REPO_ROOT" remote get-url origin | grep -q "$REPO"; then
  if command -v ghq >/dev/null 2>&1; then
    ghq get "github.com/$REPO" 2>/dev/null || true
    REPO_ROOT=$(ghq root)/github.com/$REPO
  else
    REPO_ROOT="$HOME/src/github.com/$REPO"
    mkdir -p "$(dirname "$REPO_ROOT")"
    [ -d "$REPO_ROOT/.git" ] || git clone "https://github.com/$REPO" "$REPO_ROOT"
  fi
  (cd "$REPO_ROOT" && gh pr checkout "$PR_NUM" --repo "$REPO")
fi
```

**Step 1: bundleとreviewer prompt生成**

```bash
python3 "$REVIEW_ORCH_DIR/scripts/build-bundle.py" \
  --triage "$TRIAGE" -o "$BUNDLE"

REVIEWERS=$(jq -r '
  if ((.selected_reviewers // []) | length) > 0 then
    .selected_reviewers[]
  else
    "codex-baseline", "opus-baseline"
  end
' "$TRIAGE")
for reviewer in $REVIEWERS; do
  python3 "$REVIEW_PROMPT_SCRIPT" \
    --bundle "$BUNDLE" --triage "$TRIAGE" \
    --reviewer "$reviewer" --repo-root "$REPO_NAME:$REPO_ROOT" \
    -o "$WORK/prompt-${reviewer}.txt"

  {
    printf '\n## 既存レビュー（重複指摘回避のため必読）\n'
    cat "$WORK/existing-reviews.json"
    printf '\n## 既存コメント（重複指摘回避のため必読）\n'
    cat "$WORK/existing-comments.json"
    printf '\n## checks\n'
    cat "$WORK/checks.txt"
  } >> "$WORK/prompt-${reviewer}.txt"
done
```

**Step 2A: Codex subagentを使う場合**

ユーザーが明示的に並列レビューを依頼しており、`multi_agent_v1` が使える場合だけ実行する。未発見なら `tool_search` で `multi-agent spawn subagent` を検索する。

各reviewerについて同一ターンで `multi_agent_v1.spawn_agent` を呼び、次のように依頼する。

```text
Read /absolute/path/to/prompt-<reviewer>.txt and follow it.
Write findings JSON to /absolute/path/to/raw-<reviewer>.json.
Return only the path you wrote and a short status.
```

全reviewerが完了したら normalize/report へ進む。

```bash
FINDING_ARGS=()
for reviewer in $REVIEWERS; do
  FINDING_ARGS+=(--findings "$WORK/raw-${reviewer}.json")
done

python3 "$REVIEW_ORCH_DIR/scripts/normalize.py" \
  "${FINDING_ARGS[@]}" \
  --adapt -o "$REPORT"
python3 "$REVIEW_ORCH_DIR/scripts/report.py" \
  --report "$REPORT" --pr-ref "github.com/$REPO#$PR_NUM"
```

`report.py` の出力はユーザーに届く最終テキストへ全文反映する。要約でfindingsを落とさない。

**Step 2B: Codex subagentを使わない場合**

`$WORK/prompt-*.txt` をreviewer観点ごとに読み、Codex自身がローカルで統合レビューを作る。JSON中間ファイルやnormalizerは必須ではない。`review-pr-reference.md` の出力フォーマットに従い、注意事項に「subagent未使用: ユーザーから明示的な並列レビュー依頼が無かったため」と1行で書く。

## GitHub投稿指示を受けた場合

投稿指示を受けた時点で、必ず以下4点を順に確認する。

1. 投稿本文はmust-fixのみに絞ったか
2. 投稿本文を `proofread` skill で校正したか
3. 同PRの直近レビューに自分のuser、同じ `commit_id`、60秒以内のreviewが無いか
4. 書き込みコマンドに `|| fallback` やリトライを付けていないか

書き込み系 `gh` 呼び出し (`gh api -X POST/PUT/PATCH/DELETE`, `gh pr review`, `gh pr comment`, `gh pr merge`, `gh issue comment` 等) は1回だけ実行する。結果確認は別コマンドで後から取得する。

GitHubに投稿するレビュー本文はmust-fixのみに絞る。should-fix / watch / 「別観点の指摘」は削除してから投稿する。must-fixが0件のときは投稿しない、または短い確認コメントだけにする。

## Gotchas

- PR URLやPR番号が渡されていれば、`gh pr view` のカレントブランチ判定に頼らず `--repo org/repo PR番号` を指定する。
- 中間ファイルは必ず `$HOME/.cache/review-pr/$PR_NUM` 配下に置く。`/tmp/review-pr-triage.json` のような固定パスは複数セッションで衝突する。
- `gh pr view --json baseRepository` は一部ghバージョンで `Unknown JSON field` になる。REPOはPR URLから抽出する。
- `gh` 実行時にshell profile由来のnoiseがstderrに混ざる環境では、JSONをparseするコマンドに `2>/dev/null` を付ける。
- Codexが「サポートしていない」「動作しない」系の主張をしたら、該当コード、公式ドキュメント、実機挙動のいずれかで確認してから採用する。未確認のP0は禁止。
- triageの `selected_reviewers` がnullまたは空の場合、`codex-baseline` と `opus-baseline` の2本を固定で使う。
- `build-reviewer-prompt.py` の出力に「diff 取得不可」が出た場合は、`git diff "$BASE_SHA" "$HEAD_SHA"` を実行して必要なdiffを補ってから判断する。
- `uv run` がキャッシュ書き込みやsandboxで落ちる場合、`python3 -c "import yaml"` が通る環境では `python3 "$TRIAGE_SCRIPT"` に切り替える。orchestrator配下の `build-bundle.py` / `normalize.py` / `report.py` と、このskill配下の `scripts/build-reviewer-prompt.py` はpython3直実行でよい。
