## 調査手順の詳細

### Step 1: pup CLI でSLOステータス取得

```bash
# 1. team:sre の SLO ID を全件取得
pup slos list 2>&1 | jq -r '[.data[] | select(.tags | any(. == "team:sre")) | .id] | .[]' > /tmp/sre_slo_ids.txt

# 2. 各SLOのステータスを取得し、breached/warning/no_data を抽出
while read slo_id; do
  result=$(pup slos status "$slo_id" --from 30d --to now 2>&1)
  slo_state=$(echo "$result" | jq -r '.data.attributes.state // empty' 2>/dev/null)
  if [ "$slo_state" = "breached" ] || [ "$slo_state" = "warning" ] || [ "$slo_state" = "no_data" ]; then
    slo_name=$(pup slos get "$slo_id" 2>&1 | jq -r '.data.name // empty' 2>/dev/null)
    sli_val=$(echo "$result" | jq -r '.data.attributes.sli // empty' 2>/dev/null)
    budget_left=$(echo "$result" | jq -r '.data.attributes.error_budget_remaining // empty' 2>/dev/null)
    tgt=$(pup slos get "$slo_id" 2>&1 | jq -r '.data.target_threshold // empty' 2>/dev/null)
    echo "${slo_state}|${slo_name}|${sli_val}|${tgt}|${budget_left}"
  fi
done < /tmp/sre_slo_ids.txt
```

134件程度あるため、バックグラウンド実行（`run_in_background: true`）を推奨。所要時間は5-10分。

### Step 2: Slack チャンネル調査

対象チャンネル:
- `#00-alert` (ID: C025CATGXCY) - Datadog/PagerDuty/外部サービスのアラート
- `#00-emergency` - 緊急対応
- `#00-trouble-shooting` - 障害対応

調査方法:
1. `slack_read_channel` で直近のメッセージを取得（limit: 30-50）
2. cursor でページネーションしながら1ヶ月分遡る
3. 非Datadog/非PagerDuty のメッセージ（外部サービス通知、人のコメント）に注目
4. スレッド返信数・リアクション（eyes, white_check_mark等）が多いものは重要度が高い

注意:
- Datadog bot の投稿は attachment 形式で本文が空になる。件数・リアクション・スレッド数から推測する
- `slack_search_public_and_private` は精度が低い。`slack_read_channel` + pagination が確実
- 1回のread_channelで取得できるのは50件まで。アラートストーム発生日は1日で100件超えることがある

### Step 3: レイテンシSLO の詳細調査

breached のレイテンシSLO がある場合:

1. Terraform からメトリクス名を特定:
   ```bash
   grep -r "ウォレット残高照会" terraform/datadog/slo/
   ```
   → SLO定義ファイルで `route` と `max_latency` を確認

2. メトリクスモジュールの確認:
   - `terraform/datadog/modules/gateway/slo_latency/main.tf` にメトリクスクエリがある
   - メトリクス名: `gcp.prometheus.billioon_http_server_handling_seconds.histogram.p99`
   - タグ: `route`, `method`, `status`

3. Datadog MCP でメトリクス取得:
   ```
   get_datadog_metric:
     queries: ["avg:gcp.prometheus.billioon_http_server_handling_seconds.histogram.p99{route:{route},method:{method},status:2*}"]
     from: "now-7d"
   ```

### Step 4: SLO反応の突合

Slack で収集した障害・アラートに対して、以下を確認:
- その障害でSLOが反応（breachまたはburn rate alert発火）したか
- 反応しなかった場合、SLO追加が必要か
- 外部サービス障害（銀行系メンテ、決済事業者障害等）は外部依存SLOの検討材料

### Step 5: Datadog Notebook 作成

- 常に `create_datadog_notebook` で新規作成する（edit APIは使わない）
- セル構成は `templates/notebook.md` を参照
- `time_span: "1w"` でデフォルト時間範囲を1週間に設定
- type は `"report"` を指定

## SLO Health Check の3つの観点（Kibela notes/30698 より）

1. SLO未達サービスの確認（status: breached）
   - 対応チケットは作成済みか、進捗はどうか
   - チケット作成先: Linear の Server SLI/SLO 改善プロジェクト

2. SLO未達予備軍の確認（status: warn / error budget 50%以下）
   - チケット化すべきか（事前対応が必要か）

3. SLO追加 & 削除の確認
   - 最近の障害でSLOが反応しなかったものはないか
   - 追加した方が良いSLI/SLOはないか
   - 重要度が低く削除可能なSLOはないか
