# 社内ナレッジ検索

## 基本方針
- 社内ナレッジの検索には `mcp__ragent__hybrid_search` を使う
- 日本語の自然文クエリで検索する（短いキーワードより文章の方が精度が高い）

## URL を含むクエリ

ragent はクエリ内の URL を自動検出し、特別な処理を行う。

- Kibela URL (`*.kibe.la`): WebFetch ではなく hybrid_search に URL ごと渡す。`reference` フィールドで完全一致検索を先に試み、ヒットすれば即座に返す
- Slack URL (`*.slack.com/archives/...`): 自動でメッセージ本文+スレッド返信を取得し、コンテキストとして付与する。`SLACK_SEARCH_ENABLED` の設定に関係なく動作する

## パラメータリファレンス

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `query` | string | (必須) | 検索クエリ。自然文推奨。URL を含めると自動検出される |
| `top_k` | integer | 10 | 返却件数 (1-100) |
| `filters` | object | - | メタデータフィルタ。`{"category": "ops"}` のようにキーバリューで指定 |
| `search_mode` | string | "hybrid" | `hybrid` / `bm25` / `vector` |
| `bm25_weight` | number | 0.5 | BM25 スコアの重み (0.0-1.0) |
| `vector_weight` | number | 0.5 | ベクトルスコアの重み (0.0-1.0) |
| `min_score` | number | 0.0 | 最低スコア閾値。ノイズが多いときに引き上げる |
| `fusion_method` | string | "weighted_sum" | `weighted_sum` / `rrf` |
| `include_metadata` | boolean | false | 実行時間・スコア内訳などのメタデータを含める |
| `use_japanese_nlp` | boolean | true | 日本語形態素解析 (kuromoji) を有効化 |
| `enable_slack_search` | boolean | false | Slack 会話も検索対象に含める |
| `slack_channels` | string[] | - | Slack 検索を特定チャネルに絞る（`#` なしのチャネル名） |

## 検索モードの使い分け

- 固有名詞・エラーメッセージなど正確なキーワードで探す → `search_mode: "bm25"` または `bm25_weight` を高めに (0.7)
- 概念・意味で探す（「認証の仕組み」「デプロイ手順」） → デフォルトの hybrid で十分
- キーワードが分からず意味だけで探す → `vector_weight` を高めに (0.7)

## Slack 検索のコツ

- `enable_slack_search: true` を付けると、ドキュメント検索とは別にSlack会話を並行検索する
- 特定チャネルに絞りたい場合は `slack_channels: ["infra", "incident"]` を指定
- Slack URL をクエリに含めると、そのメッセージのスレッド全体を取得できる（`enable_slack_search` 不要）
