---
name: dd-investigate
description: Datadogでサービス・アラート・モニターを調査。「アラートについて調査」「このアラート調べて」「Datadogで調べて」「モニター確認」「サービスの状態確認」「エラー調査」等で起動。
user-invocable: true
allowed-tools:
  - mcp__datadog-mcp__analyze_datadog_logs
  - mcp__datadog-mcp__search_datadog_logs
  - mcp__datadog-mcp__search_datadog_spans
  - mcp__datadog-mcp__get_datadog_metric
  - mcp__datadog-mcp__get_datadog_metric_context
  - mcp__datadog-mcp__search_datadog_services
  - mcp__datadog-mcp__search_datadog_monitors
  - mcp__datadog-mcp__search_datadog_incidents
  - mcp__datadog-mcp__search_datadog_events
  - mcp__datadog-mcp__get_datadog_incident
  - mcp__datadog-mcp__get_datadog_trace
  - Bash
---

# dd-investigate

Datadogを起点としたアラート・サービス調査。

## 基本原則

1. アラート調査: モニター詳細 → イベント履歴 → メトリクス/ログ
2. サービス調査: 集計 → パターン → 詳細
3. GCP系アラート: Datadog確認後、gcloudで補完調査

## 調査フロー

### アラート調査（優先）

ユーザーがアラートについて質問した場合：

1. **モニター特定**: `search_datadog_monitors` でタイトルキーワード検索
2. **イベント履歴**: `search_datadog_events` で発火/復旧タイミング確認
3. **メトリクス確認**: `get_datadog_metric` でモニターのクエリを実行
4. **根本原因**: ログ/トレースで詳細確認

GCP系（Cloud Armor, Cloud Run等）の場合：
- Datadogで概要把握後、`gcloud logging read` で詳細ログ確認
- 環境: REDACTED-dev, REDACTED-stg, REDACTED-prd(prd)

### サービス調査

特定サービスの状態を確認する場合：
1. `analyze_datadog_logs` で集計
2. `search_datadog_logs` でパターン確認
3. 必要に応じてトレース/メトリクス

---

## テンプレート集

### 0. アラート調査（推奨）

対象: Slackに来たアラートを調査したい

```
手順:
1. search_datadog_monitors でモニター特定
   query: "title:{アラート名のキーワード}"

2. search_datadog_events でイベント履歴
   query: "*{モニター名}*"
   from: "now-24h"

3. get_datadog_metric でメトリクス確認
   queries: [モニターのクエリ]
   from: "now-2h"

4. GCP系の場合、gcloudで補完:
   gcloud logging read '<フィルタ>' --project=<project_id> --freshness=4h

結果を要約:
- 発火時刻と復旧時刻
- 原因（ログ/メトリクスから特定）
- 対応要否の判断
```

### 1. エラー調査

対象: サービスのエラー状況を把握したい

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    {service} のエラー状況を調査。

    手順:
    1. analyze_datadog_logs で時系列カウント
       filter: "service:{service} status:error"
       sql_query: "SELECT DATE_TRUNC('minute', timestamp) as min, count(*) FROM logs GROUP BY DATE_TRUNC('minute', timestamp) ORDER BY min DESC"
       from: "now-1h", max_tokens: 3000

    2. search_datadog_logs でパターン確認
       query: "service:{service} status:error"
       use_log_patterns: true, max_tokens: 2000

    結果を要約:
    - エラー数の推移（増加傾向/安定/減少）
    - 主なエラーパターン
    - 推奨アクション（あれば）
```

### 2. レイテンシ調査

対象: サービスの応答速度を確認したい

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    {service} のレイテンシを調査。

    手順:
    1. get_datadog_metric でp99レイテンシ
       queries: ["p99:trace.http.request.duration{service:{service}}"]
       from: "now-1h", raw_data: false, max_tokens: 3000

    2. 異常があれば search_datadog_spans で遅いリクエスト
       query: "service:{service} @duration:>1000000000"
       max_tokens: 3000

    結果を要約:
    - p99レイテンシの状況
    - 遅いリクエストのパターン（あれば）
```

### 3. インシデント確認

対象: 現在のインシデント状況を把握したい

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    アクティブなインシデントを確認。

    手順:
    1. search_datadog_incidents
       query: "state:(active OR stable)"
       max_tokens: 3000

    結果を要約:
    - インシデント数
    - 重要度別の内訳
    - 各インシデントの概要（1行ずつ）
```

### 4. サービス全体ヘルスチェック

対象: 特定サービスの総合的な状態確認

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    {service} の総合ヘルスチェック。

    手順:
    1. analyze_datadog_logs でstatus別カウント
       filter: "service:{service}"
       sql_query: "SELECT status, count(*) FROM logs GROUP BY status"
       from: "now-1h", max_tokens: 2000

    2. search_datadog_monitors で関連モニター状態
       query: "tag:service:{service}"
       max_tokens: 2000

    結果を要約:
    - ログのstatus分布
    - アラート状態のモニター（あれば）
    - 総合判定: 正常/警告/異常
```

### 5. 特定トレース調査

対象: trace_idから詳細を追いたい

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    トレース {trace_id} を調査。

    手順:
    1. get_datadog_trace
       trace_id: "{trace_id}"
       only_service_entry_spans: true
       max_tokens: 5000

    結果を要約:
    - リクエストフロー
    - ボトルネック箇所
    - エラー発生箇所（あれば）
```

### 6. ログ検索（キーワード）

対象: 特定のキーワードでログを探したい

```
Task:
  subagent_type: "general-purpose"
  prompt: |
    "{keyword}" を含むログを調査。

    手順:
    1. analyze_datadog_logs でサービス別カウント
       filter: "{keyword}"
       sql_query: "SELECT service, count(*) FROM logs GROUP BY service ORDER BY count(*) DESC"
       from: "now-1h", max_tokens: 2000

    2. 上位サービスのログパターン
       search_datadog_logs
       query: "service:{top_service} {keyword}"
       use_log_patterns: true, max_tokens: 2000

    結果を要約:
    - どのサービスで発生しているか
    - 主なパターン
```

