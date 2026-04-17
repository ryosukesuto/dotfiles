---
name: review-triage
description: PR/git diff を受け取り triage.schema.json 準拠のJSONを出力する。機械判定優先。review-orchestrator が内部で使う。単体でも使用可能。
---

# review-triage

PR または git diff から変更ファイルリストを分析し、triage 結果（size / risk_tags / selected_reviewers / must_check_interfaces）を出力する。

## スクリプトパス

```
config/claude/skills/review-triage/scripts/triage.py
```

依存: `pyyaml`（`uv run --with pyyaml python3 triage.py ...` で解決）

判定ルール設定:

```
config/claude/skills/review-orchestrator/triage-config.yaml
```

## 入力

changed_files JSON を stdin または `--changed-files` ファイルで渡す。

```json
[
  {"repo": "server", "path": "api/payment/v1/payment.proto", "status": "modified", "additions": 15, "deletions": 3},
  {"repo": "server-config", "path": "config/payment.yaml", "status": "modified", "additions": 4, "deletions": 1}
]
```

`status` は `added | modified | deleted | renamed`。

## 使い方

### PRモード

```bash
echo '[...]' | uv run --with pyyaml python3 \
  config/claude/skills/review-triage/scripts/triage.py \
  --pr-ref "github.com/org/repo#123" \
  --base-sha abc1234 --head-sha def5678 \
  --repo server:/path/to/server \
  --repo server-config:/path/to/server-config \
  --pr-title "payment proto update" \
  --pr-labels "breaking-change" \
  --pr-author "alice"
```

### local-diffモード

```bash
# git diff --name-status で changed_files を作ってから渡す
uv run --with pyyaml python3 \
  config/claude/skills/review-triage/scripts/triage.py \
  --local-diff \
  --base-sha $(git merge-base HEAD main) \
  --head-sha $(git rev-parse HEAD) \
  --repo server:$(pwd) \
  --changed-files /tmp/changed_files.json
```

## git diff からchanged_files JSONを生成するヘルパー

```bash
# repo内で実行。changed_files.json を生成する
git diff --name-status base_sha head_sha | while IFS=$'\t' read -r status src dst; do
  case "$status" in
    A) echo "{\"repo\":\"server\",\"path\":\"$src\",\"status\":\"added\",\"additions\":$(git diff --numstat base_sha head_sha -- "$src" | awk '{print $1}'),\"deletions\":0}" ;;
    M) echo "{\"repo\":\"server\",\"path\":\"$src\",\"status\":\"modified\",\"additions\":$(git diff --numstat base_sha head_sha -- "$src" | awk '{print $1}'),\"deletions\":$(git diff --numstat base_sha head_sha -- "$src" | awk '{print $2}')}" ;;
    D) echo "{\"repo\":\"server\",\"path\":\"$src\",\"status\":\"deleted\",\"additions\":0,\"deletions\":$(git show base_sha:"$src" | wc -l)}" ;;
    R*) echo "{\"repo\":\"server\",\"path\":\"$dst\",\"status\":\"renamed\",\"renamed_from\":\"$src\",\"additions\":0,\"deletions\":0}" ;;
  esac
done | jq -s '.'
```

## 出力

`triage.schema.json` 準拠の JSON を stdout に出力。
`-o /path/to/triage.json` でファイルに書き出し可能。

## 設定のチューニング

`triage-config.yaml` を編集して:

- `size_thresholds`: quick/standard の行数境界
- `critical_paths`: deep扱いにするパスキーワード
- `path_risk_rules`: パスパターン → risk_tags のマッピング
- `cross_repo_rules`: パスパターン → candidate_repos のマッピング
- `reviewer_rules`: reviewer選定条件
- `token_budget`: global / per_reviewer のトークン上限
