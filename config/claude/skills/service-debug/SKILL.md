---
name: service-debug
description: kubectlでのサービス調査・ボトルネック調査のガイドライン。「サービス調査」「kubectl」「ボトルネック」「Spanner」等で起動。
user-invocable: false
---

## デバッグ & 調査

### 調査開始時のコンテキスト取得
サービス名が不明確、またはマルチサービス調査時は最初に実行:
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
