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

### 並列調査パターン
マルチサービス調査時は並列実行を活用:
- 「{service1}と{service2}を並列で調査して」
- 「Agentで{調査A}をしながら、{調査B}を調べて」

Claude Codeは複数のTask Agentを同時に起動できる。
