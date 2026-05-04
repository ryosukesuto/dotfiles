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

引数で PR 番号 / URL が渡されている場合はそちらを優先する。PR が見つからない場合の優先順位:

1. 引数で受け取った PR 番号 / URL があればそれを使う
2. 直前の同一セッション内で操作した PR 番号があれば、AskUserQuestion で「PR #XXX で続行しますか？」と確認
3. 上記いずれも無ければ AskUserQuestion で PR 番号を尋ねる

worktree 横断で作業している場合、`cwd` が main 側だと `gh pr view` は失敗する。`gh pr list --author @me --state open --limit 5` で候補を出して確認する手もある。

### 2. リポジトリ情報の取得

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)
```

### 3. レビューコメントの取得

レビューコメントには3種類ある。すべて取得すること。

- インラインコメント（`reviewThreads`）: コードの特定行に付くコメント。resolve が可能
- review body（`reviews`）: レビュー全体のサマリーコメント。APPROVED / CHANGES_REQUESTED 等の状態を持つ
- issue コメント（`comments`）: PR 全体に対する単発コメント。Greptile などのレビュー bot は inline thread ではなく issue コメントとしてサマリ＋suggestion を一括投稿することがある。resolve 不可

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
      comments(first: 50) {
        nodes {
          id
          databaseId
          body
          author { login }
          createdAt
        }
      }
    }
  }
}'
```

- `reviewThreads`: 未解決（`isResolved: false`）のスレッドのみを対象にする
- `reviews`: `CHANGES_REQUESTED` 状態のレビューを優先的に対応する。`APPROVED` のレビューに含まれる指摘も見落とさないこと
- `comments`: bot 投稿（`greptile-apps[bot]` / `coderabbit[bot]` など）の本文に suggestion が埋め込まれていないか必ず確認する。HTML の `<details>` で折りたたまれていることもあるので、`gh api repos/{owner}/{repo}/issues/comments/{id}` で本文をフルで取得して読む

#### 連続レビューサイクル時のフィルタ

同じ PR に対して push → 新規レビュー → 修正 → push を繰り返す場合、毎回全件読み返すと無駄。`LAST_PUSH_TIME` 以降に追加された分だけを抽出する:

```bash
# 直近 push の時刻を ISO8601 で取得（fallback はセッション開始時刻）
LAST_PUSH_TIME=$(git log -1 --format=%cI HEAD@{push} 2>/dev/null || echo "1970-01-01T00:00:00Z")

gh api graphql -f query='...上のクエリ...' 2>/dev/null | jq --arg since "$LAST_PUSH_TIME" '{
  unresolved_threads: [.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)],
  recent_reviews: [.data.repository.pullRequest.reviews.nodes[] | select(.body != "" and (.submittedAt > $since))],
  recent_comments: [.data.repository.pullRequest.comments.nodes[] | select(.createdAt > $since)]
}'
```

初回実行時は `$since` をエポック相当にして全件取得、2 回目以降は直前 push の時刻でフィルタする。`unresolved_threads` は時刻を問わず全件確認すること（古い未対応スレッドを取りこぼさない）。

#### セキュリティスキャナー bot（Wiz / Snyk 等）の扱い

Wiz `wiz-ed2b67a832` のような scanner bot は本文に finding 件数のサマリしか持たず、詳細は外部コンソールへのリンクのみ。本文を Read しても意味のある情報は得られない。

対処:

- 本文に件数サマリしかない場合は、PR の他のレビュー（claude bot 等）が同じ脆弱性を捕捉していないか確認する。捕捉済みならそちらの修正で finding も解消する想定で進む
- 解消したか確認する手段がローカルに無い場合、修正 push 後の次回 scan 結果まで判断保留と明示する
- 詳細を見ないと判断できない finding（high/critical 等）はユーザーに「Wiz コンソールで詳細を確認しますか？」と聞いて止まる

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

### 7. スレッドの resolve / issue コメントへの返信

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

issue コメント（Greptile などの bot サマリ）には resolve 機能がないため、以下のいずれかで対応を残す:

- 修正コミットのメッセージで対応箇所を明記する（push すれば自動的に bot のコメントから参照できる）
- 必要に応じて PR に通常コメント（`gh pr comment {PR_NUMBER} --body "..."`）で対応サマリを返信する。Greptile のように再レビューを再走できる bot の場合は、再走によって対応済みが反映される

### 8. 結果報告

対応結果をまとめてユーザーに報告:
- 修正したコメント数
- resolve したスレッド数
- 残っている未解決スレッド（あれば）

## Gotchas

- レビューコメントは 3 経路に分かれて格納される。`reviewThreads` / `reviews` / `comments`（issue コメント）すべて取得しないと取りこぼす。経験上、Greptile は inline thread を作らず issue コメントに suggestion をまとめるため、`reviewThreads.totalCount=0` でも `comments` を必ず確認する
- `gh pr view --comments` は PR description + issue コメント + reviews を時系列に統合表示してくれるので、目視確認の最初の一歩として有効。ただし長い HTML コメントはトリミングされるため、確実に本文を読むなら `gh api repos/{owner}/{repo}/issues/comments/{id}` でフル取得する
- `resolveReviewThread` は PR author 権限で実行可能。他人の PR では権限エラーになる場合がある。issue コメント（Greptile bot 等）には resolve 機能がないため、対応サマリは PR コメントで返すか、コミットメッセージで明記する
- 自動レビューボットの本文は `<details>` で折りたたまれていることが多い。`grep -F suggestion` 等で機械的に探すより、本文全体を Read して目視で漏れを確認する方が確実
- リポジトリ名はハードコードせず、`gh repo view` から動的に取得する
- Greptile の suggestion を `git apply` で適用する場合、diff 形式が GitHub の suggestion 形式と異なることがあるので、手動で Edit ツールを使って修正する方が確実
- 複数コメントへの修正を1コミットにまとめる。コメントごとに commit すると履歴が散らかる
- 同一セッション内で同じスキルを連続呼び出しするケース（push → 新規レビュー → 修正 → push のループ）が頻出する。2 回目以降は「直前 push 以降に追加された分」だけをフィルタ表示し、毎回全件読み返さない（`#連続レビューサイクル時のフィルタ` 節参照）
- worktree 横断で作業する場合、`gh pr view` がカレントブランチ判定で失敗することがある。直前の会話文脈に PR 番号があれば AskUserQuestion で「PR #XXX で続行しますか？」と確認してから進む
