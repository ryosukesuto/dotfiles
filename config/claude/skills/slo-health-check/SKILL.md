---
name: slo-health-check
description: SLO Health Checkレポートを作成する。「SLO調査」「SLOレポート」「SLO Health Check」「SLOの状態確認」「breached確認」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - TaskCreate
  - TaskUpdate
  - mcp__datadog-mcp__create_datadog_notebook
  - mcp__datadog-mcp__get_datadog_metric
  - mcp__datadog-mcp__search_datadog_events
  - mcp__claude_ai_Slack__slack_read_channel
  - mcp__claude_ai_Slack__slack_search_public_and_private
  - mcp__ragent__hybrid_search
---

# /slo-health-check - SLO Health Check レポート作成

Kibelaノート(notes/30698)の「SLO Health Check MTG」の進め方に沿って、SLOの健全性を調査しDatadog Notebookにレポートを作成する。

## 実行手順

### 0. リファレンス読み込み

詳細な手順・コマンド・テンプレートを参照する:
- `${CLAUDE_SKILL_DIR}/reference.md` - 調査手順の詳細、pupコマンド、Slackチャンネル情報
- `${CLAUDE_SKILL_DIR}/templates/notebook.md` - Datadog Notebookのセル構成テンプレート

### 1. 事前確認

- `date "+%Y-%m-%d (%a) %H:%M"` で現在日時を確認
- `pup auth status` で認証状態を確認（未認証ならユーザーに `! pup auth login` を依頼）

### 2. SLOステータス取得（pup CLI）

`pup slos list` で全SLOを取得し、`pup slos status` で各SLOのbreached/warn/ok状態を確認する。
Datadog MCPにはSLO一覧取得ツールがないため、pup CLIが唯一の正確な取得手段。

### 3. 障害・アラート一覧収集（Slack）

#00-alert, #00-emergency, #00-trouble-shooting を1ヶ月分遡って読み、SLO反応と突合する。

### 4. レイテンシ調査（breachedのレイテンシSLOがある場合）

Terraformコードからメトリクス名を特定し、Datadog MCPでメトリクスデータを取得する。

### 5. Datadog Notebookにレポート作成

テンプレートに沿って `create_datadog_notebook` で新規作成する。

## Gotchas

- Datadog MCPの `search_datadog_monitors` で `type:slo status:alert` を検索してもSLOのbreached状態は取れない。バーンレートアラートモニターの発火状態とSLO自体のbreached状態は別物。必ず `pup slos status` を使う
- Datadog Notebook の edit API はセル内容が重複するバグがある。既存Notebookの編集は行わず、常に新規作成する
- Slack の Datadog bot 投稿は attachment 形式のため、検索でもチャンネル読み込みでもテキスト本文が取れない。件数とスレッド数・リアクションから重要度を推測する
- Slack の `slack_search_public_and_private` は結果が限定的。1ヶ月分のデータを取るには `slack_read_channel` でページネーション（cursor）しながら遡る必要がある
- zsh では `status` は読み取り専用変数。シェルスクリプト内で変数名に使うとエラーになる。`slo_state` 等を使う
- `pup slos status` のレスポンスパスは `.data.attributes.state`（`.data.overall_status[0].state` ではない）
- レイテンシSLOのメトリクス名は Terraform の `terraform/datadog/modules/gateway/slo_latency/main.tf` に定義されている（`gcp.prometheus.<INTERNAL_METRIC_NAME>.histogram.p99`）
