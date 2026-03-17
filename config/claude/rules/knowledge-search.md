# 社内ナレッジ検索

## Kibela URL への対応
- `*.kibe.la` のURLが提示された場合、WebFetchではなく `mcp__ragent__hybrid_search` を使用する
- URLからタイトルやキーワードを推測してクエリを構成する
- ノートIDやパスがわかる場合は filters に含める

## ragent hybrid_search の使い方
- 日本語の自然文クエリで検索する（短いキーワードより文章の方が精度が高い）
- 必要に応じて `include_metadata: true` でメタデータを取得する
- Slack の会話も含めたい場合は `enable_slack_search: true` を指定する
