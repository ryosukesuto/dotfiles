---
name: fix-review-comments
description: PRのレビューコメント（Greptile・人間）をまとめて対応し、修正push後にスレッドをresolveする。「レビューコメント対応」「review fix」「レビュー修正」等で起動。
user-invocable: true
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - AskUserQuestion
---

# /fix-review-comments - レビューコメント一括対応

PRの未解決レビューコメントを一覧取得し、優先度判断→修正→push→resolveを一括で行う。

## 実行手順

### 1. 対象PRの特定

レビューコメントはPR単位で管理されているため、まずPRを特定する。

```bash
# 現在のブランチに紐づくPRを取得
PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null)
```

PRが見つからない場合はユーザーにPR番号を確認する。

### 2. リポジトリ情報の取得

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)
```

### 3. レビューコメントの取得

レビューコメントには2種類ある。両方を取得すること。

- インラインコメント（`reviewThreads`）: コードの特定行に付くコメント。resolveが可能
- review body（`reviews`）: レビュー全体のサマリーコメント。APPROVED / CHANGES_REQUESTED 等の状態を持つ

```bash
gh api graphql -f query='query {
  repository(owner: "'"$OWNER"'", name: "'"$REPO_NAME"'") {
    pullRequest(number: '"$PR_NUMBER"') {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              body
              author { login }
              createdAt
            }
          }
        }
      }
      reviews(first: 20) {
        nodes {
          body
          state
          author { login }
          comments(first: 20) {
            nodes {
              body
              path
              line
              author { login }
            }
          }
        }
      }
    }
  }
}'
```

- `reviewThreads`: 未解決（`isResolved: false`）のスレッドのみを対象にする
- `reviews`: `CHANGES_REQUESTED` 状態のレビューを優先的に対応する。`APPROVED` のレビューに含まれる指摘も見落とさないこと

### 4. コメントの分析と優先度判断

全コメントに一律対応すると不要な修正が混ざる。ユーザーの判断を仰ぐために分類する。

各コメントを以下の基準で分類:

| 優先度 | 対応 | 例 |
|--------|------|-----|
| 必須対応 | コード修正が必要 | バグ指摘、セキュリティ、ロジックエラー |
| 推奨対応 | 修正した方がよい | 命名改善、バージョン範囲、パフォーマンス |
| 対応不要 | resolve のみ | 質問への回答済み、情報提供のみ、誤検知 |

分類結果をユーザーに提示し、対応方針を確認する:
- 「必須対応」は自動的に修正する
- 「推奨対応」はユーザー判断（デフォルトは対応する）
- 「対応不要」は理由を添えて resolve する

### 5. コード修正

対応が必要なコメントに対して修正を実施:

1. 該当ファイル・行を読んで現状を把握
2. コメントの指摘内容に沿って修正
3. プロジェクトのコーディング規約に従う
4. 関連するテスト・lintを実行して検証

### 6. コミット・push

```bash
git add -A
git commit -m "fix: address review comments

- [対応内容を箇条書き]"
git push
```

### 7. スレッドの resolve

レビュアーが対応状況を一目で把握できるよう、対応済みスレッドは resolve する。修正対応したスレッドと、対応不要と判断したスレッドを resolve する。

```bash
# 各スレッドを resolve
gh api graphql -f query='mutation {
  resolveReviewThread(input: {threadId: "THREAD_ID"}) {
    thread { isResolved }
  }
}'
```

対応不要で resolve する場合は、理由をリプライしてから resolve する:

```bash
# リプライを投稿
gh api graphql -f query='mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: "THREAD_ID",
    body: "対応不要と判断しました。理由: ..."
  }) {
    comment { id }
  }
}'
```

### 8. 結果報告

対応結果をまとめてユーザーに報告:
- 修正したコメント数
- resolve したスレッド数
- 残っている未解決スレッド（あれば）

## Gotchas

- `reviewThreads` はインラインコメント（コードの特定行に付くコメント）のみ返す。review body（レビュー全体のサマリー）は `reviews` で別途取得が必要。両方を必ず取得すること
- review body に指摘が書かれていてインラインコメントが0件のケースがある（自動レビューボットに多い）。`reviewThreads` が空でも `reviews` を確認する
- `resolveReviewThread` は PR author 権限で実行可能。他人の PR では権限エラーになる場合がある。review body のコメントは resolve できないので、PR コメントで対応済みの旨を返信する
- リポジトリ名はハードコードせず、`gh repo view` から動的に取得する
- Greptile の suggestion を `git apply` で適用する場合、diff 形式が GitHub の suggestion 形式と異なることがあるので、手動で Edit ツールを使って修正する方が確実
- 複数コメントへの修正を1コミットにまとめる。コメントごとに commit すると履歴が散らかる
