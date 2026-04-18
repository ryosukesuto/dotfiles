---
name: review-orchestrator
description: マルチエージェント型コードレビューのオーケストレーター。Opus（lead）がtriageでreviewerを選定し、bundle配布、並列実行、finding-normalizerを経て最終レポートを出力する。「マルチエージェントレビュー」「review orchestrator」「PRレビュー（チーム構成）」等で起動。
---

# review-orchestrator

複数のreviewer（Opus baseline / Codex baseline / specialist）をleadが調整してPRをレビューする。設計ドキュメントは `docs/multi-agent-review-plan.md` 参照。

## 役割分担

- lead（Opus、本skillの呼び出し元）: triage → bundle配布 → reviewer起動 → normalize → 裁定
- reviewer（baseline/specialist）: bundle + review_slice を読み、finding schema に従って findings を返す
- cross-repo agent: leadが発行する pinpoint クエリに答える

leadはレビューしない。router + judge に徹する。

## 主要コンポーネント

| ファイル | 役割 |
|---------|------|
| `schemas/triage.schema.json` | triage出力の JSON Schema |
| `schemas/bundle.schema.json` | review bundle の JSON Schema |
| `schemas/finding.schema.json` | reviewer出力 finding の JSON Schema |
| `schemas/cross-repo-query.schema.json` | lead→cross-repo agent のクエリ定義 |
| `contracts/reviewer-io.md` | reviewer 共通 I/O 契約とプロンプトテンプレ |
| `triage-config.yaml` | triage判定ルール設定（パスパターン、閾値、reviewer選定条件） |
| `scripts/build-bundle.py` | triage.json → bundle.json 生成スクリプト |
| `scripts/build-reviewer-prompt.py` | bundle + git diff → reviewer プロンプト自動生成 |
| `scripts/adapt-findings.py` | LLM raw output → finding.schema.json 準拠に変換（normalizer の前処理） |
| `scripts/normalize.py` | 複数reviewerのfindings → dedupe → 最終レポート生成スクリプト |
| `scripts/report.py` | normalize 出力 → markdown レポート自動生成 |

関連skill:

| skill | 役割 |
|-------|------|
| `review-triage` | changed_files → triage.json 生成 |

## 実行フロー

```bash
PR="WinTicket/server#1234"
REPO="server"
SERVER_ROOT=$(ghq root)/github.com/WinTicket/server
BASE_SHA=$(gh pr view 1234 --repo WinTicket/server --json baseRefOid -q .baseRefOid)
HEAD_SHA=$(gh pr view 1234 --repo WinTicket/server --json headRefOid -q .headRefOid)

# Step 1: changed_files JSON を取得して triage
gh pr view 1234 --repo WinTicket/server --json files \
  | python3 -c "import json,sys; files=json.load(sys.stdin)['files']; print(json.dumps([{'repo':'$REPO','path':f['path'],'status':'modified','additions':f['additions'],'deletions':f['deletions']} for f in files]))" \
  | uv run --with pyyaml python3 ~/.claude/skills/review-triage/scripts/triage.py \
    --pr-ref "$PR" --base-sha "$BASE_SHA" --head-sha "$HEAD_SHA" \
    --repo "$REPO:$SERVER_ROOT" -o /tmp/triage.json

# Step 2: bundle 生成
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-bundle.py \
  --triage /tmp/triage.json -o /tmp/bundle.json

# Step 3: reviewer プロンプト自動生成（毎回手作業不要）
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle /tmp/bundle.json --triage /tmp/triage.json \
  --reviewer codex-baseline --repo-root "$REPO:$SERVER_ROOT" \
  -o /tmp/prompt-codex.txt
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
  --bundle /tmp/bundle.json --triage /tmp/triage.json \
  --reviewer opus-baseline  --repo-root "$REPO:$SERVER_ROOT" \
  -o /tmp/prompt-opus.txt

# Step 4: reviewer 起動（general-purpose subagent で並列実行）
# /tmp/prompt-codex.txt と /tmp/prompt-opus.txt の内容を subagent に渡す
# subagent_type は必ず general-purpose（Explore は不可）

# Step 5: schema adapter → normalizer（--adapt で自動変換）
uv run python3 ~/.claude/skills/review-orchestrator/scripts/normalize.py \
  --findings /tmp/raw-codex.json \
  --findings /tmp/raw-opus.json \
  --adapt \
  -o /tmp/normalized.json

# Step 6: markdown レポート自動生成
uv run python3 ~/.claude/skills/review-orchestrator/scripts/report.py \
  --report /tmp/normalized.json --pr-ref "$PR"
```

## reviewer subagent の起動方法

reviewer は必ず `subagent_type: "general-purpose"` で Agent ツールを使う。`Explore` は探索専用のため finding 生成に不向き。

プロンプトは `contracts/reviewer-io.md` の「baseline reviewer 共通」テンプレを使い、以下を置換して渡す:
- `{reviewer_id}`: reviewer_id 固定値
- `{bundle_path}`: /tmp/bundle.json のパス
- `{slice_path}`: bundle の review_slices[reviewer_id] を /tmp/slice-{reviewer}.json として書き出したパス  
- `{observation_points}`: contracts/reviewer-io.md の observation_points テーブルから該当行を抜粋

## PoC構成（最小）

- reviewers: `codex-baseline` + `opus-baseline` のみ
- normalizer: 単純 dedupe（`repo+file+line-range+issue_type+entity_key` キー、±3行を近傍とみなす）
- cross-repo: 未実装（`must_check_interfaces` がある場合のみ後付け）

## 未実装（PoC後）

- specialist reviewers（`review-server` / `security-review-opus` / `security-review-codex`）
- cross-repo agent の pinpoint/scoped/survey 実装
- bundle の拡張項目（`symbol_index` / `static_analysis_summary` 等）
- conflicting findings 裁定ロジック

## 参考

- 設計ドキュメント: `~/gh/github.com/ryosukesuto/dotfiles/docs/multi-agent-review-plan.md`
- 既存skill: `codex-review` / `review-pr` / `review-server` / `cross-repo` / `security-review`
