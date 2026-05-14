---
name: service-debug
description: kubectlでのサービス調査・ボトルネック調査のガイドライン。「サービス調査」「kubectl」「ボトルネック」「Spanner」等で起動。
user-invocable: false
allowed-tools:
  - Bash(kubectl:*)
  - mcp__datadog-mcp__search_datadog_logs
  - mcp__datadog-mcp__search_datadog_events
  - mcp__datadog-mcp__search_datadog_spans
  - Agent
---

## 起動時の context 確定

調査を始める前に、以下4点をユーザーから確定させる。曖昧なまま kubectl を叩き始めると無駄な探索を増やす。明らかに答えが分かるものは聞かない。

1. 症状は？ — `レイテンシ高い / エラー率上昇 / Pod再起動 / OOM / 突発ダウン / その他（自由記述）`
2. 対象サービスは？ — `namespace/service` 形式。不明なら「サービス一覧コマンドで検索する」と返答
3. 環境は？ — `prd / stg / dev`。kubectl context と Datadog `env` tag に直結
4. 時間範囲は？ — `直近1h以内` なら kubectl events で取れる、それ以上前は Datadog 必須

複数まとめて `AskUserQuestion` で1往復で取る。1〜2問だけ未確定なら聞かずに合理的な仮定で進める（例：症状が明示済みで環境が prd 一択なら3を聞かない）。

context が揃った後、以下のフローに進む。

## デバッグ & 調査

### サービス名検索（対象が不明な場合）
```bash
# サービス一覧（namespace/service形式）
kubectl get services -A --no-headers | awk '{print $1"/"$2}'

# サービス名で検索
kubectl get services -A --no-headers | awk '{print $1"/"$2}' | grep {keyword}
```

### よくあるボトルネック
- `GetUserStage`: broker-serverで発生、Spannerレイテンシが原因のことが多い

### Pod再作成の検知（RESTARTS では見えない）

ノードdrain時のPod再作成は `RESTARTS` に反映されない。`creationTimestamp` で検知する:

```bash
# Pod作成時刻でソート（AGEが異常に新しいPodがdrain痕跡）
kubectl get pods -n default -l app={service} \
  --sort-by='.status.startTime' \
  -o custom-columns='NAME:.metadata.name,START:.status.startTime,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName'

# ノードのAGE確認（ローリングアップデート進行状況）
kubectl get nodes -l node.kubernetes.io/instance-type={instance_type} \
  --sort-by='.metadata.creationTimestamp' \
  -o custom-columns='NAME:.metadata.name,CREATED:.metadata.creationTimestamp'

# PDB確認（drain時の同時evict制限）
kubectl get pdb -n default | grep {service}

# podAntiAffinity確認（同一ノード集中防止）
kubectl get deployment {service} -n default \
  -o jsonpath='{.spec.template.spec.affinity}' | python3 -m json.tool
```

### Killingイベントの確認

```bash
# 直近1h（kubectl eventsの保持期間）
kubectl get events -n default --sort-by='.lastTimestamp' | grep -E '(Killing|Evicted).*{service}'

# 1h以前 → Datadog search_datadog_events を使用
# query: "env:production (Killing OR Evicted) {service}"
```

### 並列調査パターン
マルチサービス調査時は並列実行を活用:
- 「{service1}と{service2}を並列で調査して」
- 「Agentで{調査A}をしながら、{調査B}を調べて」

Claude Codeは複数のTask Agentを同時に起動できる。

## Gotchas

(運用しながら追記)
