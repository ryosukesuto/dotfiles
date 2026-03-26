---
name: update-security-db
description: セキュリティチェック回答データベースを最新化する。「セキュリティDB更新」「回答データベース更新」「security db update」等で起動。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Agent
  - mcp__ragent__hybrid_search
---

# /update-security-db - セキュリティチェック回答データベースの最新化

opsリポジトリ（Terraform設定）、ragent（社内ナレッジ）、Obsidianノートから最新のセキュリティ情報を収集し、回答データベースの事実層・回答層を更新する。

## データベースの場所

`/Users/s32943/.claude/skills/update-security-db/database.md`

## データベース構造

- Part 1: 事実層（ナレッジベース）— WinTicketのセキュリティ仕様・ポリシーをジャンル別に整理
- Part 2: 回答層（過去Q&A）— 銀行各社への過去回答（501問）

## 実行手順

### 1. 現状把握

データベースを読み込み、事実層の `最終更新` 日付を確認する。
前回更新からの経過期間を把握し、更新の優先度を判断する。

### 2. 最新情報の収集

3つのソースから並行で情報を収集する。Agentを活用して並列化するとよい。

#### 2a. opsリポジトリ（インフラ設定の変更）

opsリポジトリの最近のコミットからセキュリティ関連の変更を検出する。

```bash
cd ~/gh/github.com/WinTicket/ops
git log --oneline --since="前回更新日" -- terraform/gcp/shared/armor/ terraform/wiz/ terraform/gcp/*/iam/
```

検出対象: Cloud Armor（WAF）ルール変更、IAM変更、Wiz設定変更、KMS変更、ネットワークポリシー変更

#### 2b. ragent（社内ナレッジ）

以下のクエリで検索し、新しい施策や変更を把握する。

- `WinTicket セキュリティ対策 最新 変更`
- `WinTicket 脆弱性診断 ペネトレーションテスト 実施`
- `WinTicket 認証 アクセス制御 変更`
- `WinTicket インシデント対応 改善`

#### 2c. Obsidianノート（セキュリティ関連）

```
~/gh/github.com/ryosukesuto/obsidian-notes/*セキュリティ*
~/gh/github.com/ryosukesuto/obsidian-notes/*CREST*
~/gh/github.com/ryosukesuto/obsidian-notes/*不正検知*
```

前回更新日以降に変更されたファイルを対象にする。

### 3. 古い情報の検出

回答層で以下のパターンを検索し、更新が必要な箇所を特定する。

```bash
grep -n -E "検討中|検討して|予定です|確認中|未導入|未実装|未対応" "データベースファイル"
```

各ヒットに対し、Step 2で収集した最新情報と照合し、実施済みかどうかを判断する。

### 4. 事実層の更新

Step 2で得た新情報を、該当ジャンルに追記・更新する。
`最終更新` 日付を当日に変更する。

事実層の記述ルール（詳細は reference.md を参照）:
- 内部ツール固有名は記載しない（一般的なセキュリティ用語はOK）
- 「何を」「どのように」対策しているかが伝わる表現

### 5. 回答層の更新

Step 3で特定した古い回答を、事実層の最新情報に基づいて更新する。
置換はsedで一括実行し、結果をgrepで検証する。

### 6. 検証・報告

更新内容のサマリを出力する:
- 事実層: 追加・変更したジャンルと内容
- 回答層: 更新したQ番号と変更内容
- 残課題: 確認が必要な項目（手動確認が必要なもの）

## Gotchas

- データベースファイルは300KB超。全文をcontextに読み込まず、Grep/Readで必要部分だけ参照する
- 回答層の置換はsedで行う際、日本語のエスケープに注意。複雑な置換はEditツールを使う
- ragentの検索結果が大きい場合はAgentに委任して要約させる
- 「検討中」「予定」が全て古いわけではない。銀行への回答として意図的に「予定」としている場合もある。文脈を確認してから更新する
- 事実層に内部ツール名（Wiz, Vertex AI, Terraform, Casbin等）を書かない。銀行に提出する回答の元データであるため
