---
name: review-orchestrator
description: マルチエージェント型コードレビューのオーケストレーター。Opus（lead）がtriageでreviewerを選定し、bundle配布、並列実行、finding-normalizerを経て最終レポートを出力する。「マルチエージェントレビュー」「review orchestrator」「PRレビュー（チーム構成）」等で起動。review-prが内部で呼び出す。
model: claude-opus-4-7
user-invocable: true
allowed-tools:
  - Bash
  - Read
---

# review-orchestrator

複数のreviewer（Opus baseline / Codex baseline / specialist）をleadが調整してPRをレビューする。設計の背景・意図は末尾の参考リンクを参照。

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

## specialist reviewer の起動

triage の `selected_reviewers` に `review-server` / `security-review-opus` / `security-review-codex` / `cross-repo` が含まれる場合、baseline と同じ `build-reviewer-prompt.py` で生成する。プロンプトには specialist 用の追加ガイダンス（既存 skill を Read してから指摘を返す指示）が自動で埋め込まれる。

```bash
# specialist 用プロンプト生成（baseline と同じ手順、--reviewer を差し替えるだけ）
for rid in review-server security-review-opus security-review-codex; do
  case "$rid" in
    *opus*) role="opus" ;;
    *)      role="codex" ;;
  esac
  uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-reviewer-prompt.py \
    --bundle /tmp/bundle.json --triage /tmp/triage.json \
    --reviewer "$rid" --repo-root "$REPO:$SERVER_ROOT" \
    -o "/tmp/prompt-$rid.txt"
done
```

起動時の注意:
- `security-review-opus` / `review-server` は Opus 系 subagent（`general-purpose` + `model: "opus"`）で起動
- `security-review-codex` は Codex 経由で実行する（codex-review skill の流儀に従う）
- 各 specialist のプロンプト先頭で既存 skill（`review-server` / `security-review` / `cross-repo`）を Read してから findings を返すよう指示済み

## 裁定ロジック

normalizer の `merge_findings` は以下を行う（`scripts/normalize.py` 参照）:

- `arbitration_score = confidence × (0.6 + 0.4 × evidence_specificity)` で勝者決定
- `evidence_specificity` は evidence_type 重み・excerpt 長さ・location 一致で 0.0-1.0
- severity / issue_type が食い違うときは衝突とみなし、敗者を `arbitration.rejected_alternatives` に退避
- severity / issue_type が一致する corroboration 時は confidence を +0.05 でブースト（上限 1.0）、`sources` に両 reviewer を記録

report 側は `sources` 複数時に "A + B (lead: A)" と表示し、`rejected_alternatives` を `<details>` で折りたたむ。

## cross-repo 発火（must_check_interfaces）

triage で `must_check_interfaces` が空でないとき、lead は `build-cross-repo-queries.py` で pinpoint/scoped クエリを生成し、cross-repo reviewer に渡す。

```bash
# クエリ JSON を生成（schema: schemas/cross-repo-query.schema.json）
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-cross-repo-queries.py \
  --triage /tmp/triage.json -o /tmp/cross-repo-queries.json
```

生成ルール:
- `source_symbol` が埋まっている interface は `pinpoint`（Grep + Read で解決可能）
- RPC は `{Name}|{Name}Client|{Name}Request|{Name}Response` をパターン化
- `allow_survey: false` 固定（survey 昇格は pinpoint/scoped でヒットゼロの場合のみ、lead が明示的に書き換える）
- 1 interface × candidate_repos 件数ぶんのクエリを発行

cross-repo reviewer の起動:
- `subagent_type: "general-purpose"`、`cross-repo` skill を最初に Read させる
- 入力: `/tmp/cross-repo-queries.json` のパスと、各 `candidate_repo` のローカルパス
- 出力: `finding.schema.json` 準拠の findings（`entity_key` は `must_check_interfaces[].source_repo:source_path:source_symbol` を使用、consumer 側位置は `related_locations[]`）

## bundle 拡張項目

`build-bundle.py` のオプションで `symbol_index` / `static_analysis_summary` を bundle に埋め込める。

```bash
# 既存フロー + 拡張
uv run python3 ~/.claude/skills/review-orchestrator/scripts/build-bundle.py \
  --triage /tmp/triage.json \
  --symbol-index \
  --static-analysis /tmp/semgrep-or-gosec-or-tfsec.json \
  -o /tmp/bundle.json
```

- `--symbol-index`: ripgrep で `triage.changed_symbols` 各 symbol を `repo_roots` 配下で検索し、定義/参照を index 化。Go の `func/type/const/var` 始まり行を definition と判定。vendor/node_modules/third_party/.git は除外。rg 未インストール時は空を返すだけ（失敗しない）
- `--static-analysis PATH`: 事前に実行した Semgrep / gosec / tfsec の出力 JSON をそのまま `bundle.static_analysis_summary` にマージ。形式は自由（`additionalProperties: true`）

reviewer はこの index を参照することで、caller/callee の位置特定のために repo 全探索しなくてよい。

## 未実装（残タスク）

- cross-repo survey 実装（pinpoint/scoped で全滅時の概念検索、`allow_survey: true` への昇格判断）
- `symbol_index` の多言語対応（現状は Go 前提の正規表現。TS/Python への拡張）
- `static_analysis_summary` を自動実行する wrapper（現在は事前生成済みファイルを受け取るだけ）

## 参考

- 設計ドキュメント: `~/gh/github.com/ryosukesuto/dotfiles/docs/multi-agent-review-plan.md`
- 既存skill: `codex-review` / `review-pr` / `review-server` / `cross-repo` / `security-review`


## Gotchas

- reviewer subagent は必ず `subagent_type: "general-purpose"` を使う。`Explore` は reasoning に不向きで findings を返さないことがある
- normalize.py の `--adapt` は LLM が独自フィールド（`category` / `title` 等）で返したときの保険。schema 準拠なら不要だが付けておくと安全
- triage の `selected_reviewers` が authoritative。後段でルールを再評価しない
- `build-reviewer-prompt.py` は triage.json と bundle.json の両方が必要。片方だけだとプロンプトの diff が空になる
