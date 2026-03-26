## Datadog Notebook セル構成テンプレート

`create_datadog_notebook` に渡す cells の構成。日付やデータは実行時の調査結果で埋める。

### セル構成

```json
{
  "cells": [
    { "type": "markdown", "data": "ヘッダー（調査期間、対象SLO数）" },
    { "type": "markdown", "data": "## 1. SLO未達サービスの確認\n\nBREACHED/WARN/OK件数\n\n### 可用性SLO（N件）\n\nテーブル\n\n### レイテンシSLO（N件）\n\nテーブル" },
    { "type": "markdown", "data": "### 分析\n\n可用性/レイテンシ別の傾向コメント" },
    { "type": "markdown", "data": "### レイテンシ劣化の詳細（breachedがある場合のみ）\n\nエンドポイント情報、Monitor IDリンク、パターン説明" },
    { "type": "metric", "data": "{メトリクスクエリ}", "title": "{API名} p99 latency", "display_type": "line", "markers": [{"value": "y = {閾値}", "display_type": "error dashed", "label": "SLO threshold ({閾値}ms)"}] },
    { "type": "markdown", "data": "## 2. SLO追加と削除の確認\n\n### #00-alert チャンネル事象一覧\n\n1ヶ月分のテーブル" },
    { "type": "markdown", "data": "### SLOで検知できていない可能性がある事象\n\nテーブル + その他の確認事項" },
    { "type": "markdown", "data": "## 次のアクション\n\n優先度別テーブル + チケット作成先リンク + 参考リンク" }
  ]
}
```

### 注意事項

- Notebook名: `SLO Health Check レポート {YYYY-MM-DD}`
- type: `"report"`
- time_span: `"1w"`
- セル数は10個以内に抑える（多すぎると読みにくい）
- マークダウンのリンクで括弧 `()` を含むテキストは避ける（構文が壊れる）
- `&` を含むURLはDatadog Notebookで `&amp;` にエスケープされてリンク切れするため、クエリパラメータはURL encodeするか最小限にする

### テーブルのフォーマット

breached SLO テーブル:
```
| SLO | SLI | Target | Error Budget |
|-----|-----|--------|-------------|
| [サービス名] エンドポイント名 | XX.XXX% | XX.XX% | -XXX% |
```

障害一覧テーブル:
```
| 日付 | 送信元 | 事象 | 種別 | SLO反応 |
|------|--------|------|------|--------|
| 3/XX | XXXX | XXXX | 外部障害/計画メンテ/一時的/運用起因 | なし/確認必要/- |
```

アクションテーブル:
```
| 優先度 | アクション | 担当候補 |
|--------|----------|----------|
| 高/中/低 | XXXX | 要決定/SRE |
```
