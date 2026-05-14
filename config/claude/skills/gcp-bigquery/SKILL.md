---
name: gcp-bigquery
description: >-
  BigQuery のデータセット・テーブル・ジョブ管理と、BigQuery ML / Gemini との統合をカバーする。
  BigQuery を触るとき、SQL クエリを実行するとき、BigQuery リソースを管理するとき、組み込みの
  ML 機能を使うときに起動する。データ分析・データ取り込み・BigQuery 上の AI アプリ開発でも有効。
---

> Adapted from [google/skills](https://github.com/google/skills) (Apache-2.0). 日本語翻訳と frontmatter 調整を加えている。原文ライセンスは同ディレクトリの `LICENSE` を参照。

# BigQuery Basics

BigQuery は SQL と Python で大規模データを高速解析できるサーバーレスかつ AI 対応のデータプラットフォーム。コンピュートとストレージを分離してそれぞれ独立にスケールでき、機械学習・地理空間解析・BI 機能を組み込みで提供する。

## セットアップと基本操作

1.  BigQuery API を有効化:
    ```bash
    gcloud services enable bigquery.googleapis.com --quiet
    ```

2.  データセットを作成:
    ```bash
    bq mk --dataset --location=US my_dataset
    ```

3.  テーブルを作成:

    `schema.json` にテーブルスキーマを定義する:

    ```json
    [
      {
        "name": "name",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "post_abbr",
        "type": "STRING",
        "mode": "NULLABLE"
      }
    ]
    ```

    `bq` でテーブルを作成:

    ```bash
    bq mk --table my_dataset.mytable schema.json
    ```

4.  クエリを実行:
    ```bash
    bq query --use_legacy_sql=false \
    'SELECT name FROM `bigquery-public-data.usa_names.usa_1910_2013` \
    WHERE state = "TX" LIMIT 10'
    ```

## リファレンス一覧

詳細な手順・コマンドは references/ 配下を参照。原文（英語）のまま vendoring している。

- [Core Concepts](references/core-concepts.md): ストレージ種別、分析ワークフロー、BigQuery Studio の機能
- [CLI Usage](references/cli-usage.md): `bq` コマンドでのデータ・ジョブ管理操作
- [Client Libraries](references/client-library-usage.md): Python / Java / Node.js / Go クライアントライブラリの使い方
- [MCP Usage](references/mcp-usage.md): BigQuery リモート MCP サーバーと Gemini CLI extension
- [Infrastructure as Code](references/iac-usage.md): データセット・テーブル・予約の Terraform 例
- [IAM & Security](references/iam-security.md): ロール、権限、データガバナンスのベストプラクティス

リファレンスに無い製品情報が必要な場合は Developer Knowledge MCP の `search_documents` を使う。

## 関連スキル

- [BigQuery AI & ML Skill](https://github.com/google/adk-python/tree/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml): BigQuery の AI / ML 機能をカバーする SKILL.md
- [BigQuery AI & ML References](https://github.com/google/adk-python/tree/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references): 上記スキルが参照する各リファレンスファイル
  - [bigquery_ai_classify.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_classify.md)
  - [bigquery_ai_detect_anomalies.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_detect_anomalies.md)
  - [bigquery_ai_forecast.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_forecast.md)
  - [bigquery_ai_generate.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_generate.md)
  - [bigquery_ai_generate_bool.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_generate_bool.md)
  - [bigquery_ai_generate_double.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_generate_double.md)
  - [bigquery_ai_generate_int.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_generate_int.md)
  - [bigquery_ai_if.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_if.md)
  - [bigquery_ai_score.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_score.md)
  - [bigquery_ai_search.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_search.md)
  - [bigquery_ai_similarity.md](https://github.com/google/adk-python/blob/main/src/google/adk/tools/bigquery/skills/bigquery-ai-ml/references/bigquery_ai_similarity.md)
