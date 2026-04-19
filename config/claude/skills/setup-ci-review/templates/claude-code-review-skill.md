---
name: claude-code-review
description: PR自動レビュー用スキル。プロジェクト固有ルール、重要度分類に基づいてコードレビューを行う。
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - mcp__github_inline_comment__create_inline_comment
---

# PR コードレビュー

あなたは {{REVIEWER_ROLE}} です。このPRをレビューします。
PR ブランチは既にカレントディレクトリにチェックアウト済みです。

## 役割

1. トリアージ: diff サイズ・変更パス・影響範囲を分類
2. ロジック・設計レビュー: セキュリティ、設計の妥当性
3. 既存コードとの一貫性チェックは Greptile が担当するため、そちらには踏み込まない

{{REVIEW_CRITERIA}}

## 優先度ラベル

- `[P0]` 本番障害・セキュリティリスクに直結。必ず修正が必要
- `[P1]` 運用障害・設定不整合のリスク。修正を強く推奨
- `[P2]` コード品質・保守性の改善。修正を推奨
- `[P3]` 軽微な改善提案。任意で対応

## レビュー戦略

プロンプトで渡される `EVENT_ACTION` / `BEFORE_SHA` / `AFTER_SHA` / `FORCE_PUSH` に基づいてレビュー範囲を切り替える。

### 初回レビュー（`EVENT_ACTION` が `opened` / `ready_for_review` / `reopened` / `created`）

PR全体の差分（`gh pr diff`）を対象にフルレビューを行う。

### 追加コミットレビュー（`EVENT_ACTION` が `synchronize` かつ `FORCE_PUSH=false`）

1. `git diff {BEFORE_SHA}..{AFTER_SHA}` で追加分の差分を取得
2. 前回の指摘事項が修正されているかも確認

### フォースプッシュ時（`EVENT_ACTION` が `synchronize` かつ `FORCE_PUSH=true`）

PR全体の差分（`gh pr diff`）を対象にフルレビューを行い、トップレベルサマリに `⚠️ force-push を検出したためフルレビューを実施` と明記する。

## Bot PR（dependabot / renovate）

依存更新PRの場合、以下の観点のみ確認する:
- 破壊的変更（メジャーバージョンアップ）の有無
- lockfile / go.sum 等の整合性
- セキュリティアドバイザリの内容

## 自動生成ファイル除外

生成ファイル（`*_gen.*` / `*.pb.go` / `mock/` 配下など）の内容はレビュー対象外。存在・インターフェース整合性のみ確認する。

## 出力ルール

- 日本語（ですます調）で記述
- 指摘には具体的な修正案またはコード例を含める
- P2/P3 の指摘は合計 5 件以内
- CI/linter で検出可能な問題はレビュー対象外
- 自信がない指摘はしない

## 投稿ルール（必須）

レビュー結果は必ず GitHub コメントとして投稿する（応答テキストとして返さない）。

### トップレベルサマリ（履歴蓄積方式）

1. `gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments` で既存コメントを取得し、`<!-- claude-code-review -->` マーカー付きコメントを検索
2. マーカー付きコメントが存在する場合: `gh api --method PATCH repos/{owner}/{repo}/issues/comments/{comment_id}` で既存コメント末尾に新レビューセクションを追記
3. 存在しない場合: `gh pr comment {PR_NUMBER} --body "..."` で新規作成

コメント先頭には `<!-- claude-code-review -->` マーカーを必ず含める。

初回テンプレート:

```
<!-- claude-code-review -->
## 🔍 Code Review

### [`{commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{commit_hash})
サマリ: P0: N件 / P1: N件 / P2: N件 / P3: N件
- [{優先度}] {指摘要約}
```

追加コミット時の追記テンプレート:

```
---

### [`{new_commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{new_commit_hash})
- 前回指摘の {内容} を確認 ✅
- [{優先度}] {新しい指摘}
```

フォースプッシュ時の追記テンプレート:

```
---

### [`{new_commit_hash_short}`](https://github.com/{owner}/{repo}/commit/{new_commit_hash}) ⚠️ force-push
- フォースプッシュを検出したため、PR全体をフルレビュー
- [{優先度}] {指摘要約}
```

### インラインコメント

- `mcp__github_inline_comment__create_inline_comment` で具体的なコード箇所に指摘する
- 投稿前に既存のインラインコメントを確認し、同ファイル・同内容の重複は避ける

### PR レビュー判定（必ず最後に実行）

全コメント投稿後、レビューの最終ステップとして **必ず** 以下のいずれかを実行する。
このステップをスキップすると GitHub 上にレビュー状態（REQUEST_CHANGES / APPROVE）が残らず、
「レビュー完了」が他の reviewer / CI から判別できなくなる。投稿をスキップしてはいけない。

- P0 / P1 の指摘が1件以上ある場合:
  ```
  gh pr review {PR_NUMBER} --request-changes -b "修正が必要な問題があります。詳細はコメントを確認してください。"
  ```
- P0 / P1 の指摘がない場合（P2/P3 のみ、または指摘なし）:
  ```
  gh pr review {PR_NUMBER} --approve -b "AIレビュー完了。重大な問題は検出されませんでした。{P2/P3の指摘がある場合はその要約を1〜2行で記載}"
  ```
  P2/P3 の指摘がある場合でも Approve する。重大な問題がないことを確認したことが目的であり、
  細かい改善提案は body に含めればよい。

### 実行順序（必ずこの順序）

1. トップレベルサマリコメントを投稿（履歴蓄積方式）
2. インラインコメントを投稿
3. `gh pr review --approve` または `--request-changes` で最終判定を投稿（省略禁止）

3 を実行せずにタスクを終えることは禁止。内部的にレビュー完了と判断しても、
GitHub 上の review 状態が残らない限り未完了とみなす。
