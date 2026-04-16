---
name: cleanup-branches
description: オープン/ドラフトPRに紐づいていないリモートブランチを一括削除する。「ブランチ整理」「stale branches」「リモートブランチ削除」「不要ブランチ」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /cleanup-branches - 不要リモートブランチの一括削除

マージ済み・クローズ済みPRのブランチなど、オープン/ドラフトPRに紐づいていないリモートブランチを検出して削除する。

## 実行手順

### 1. 不要ブランチの検出

以下の3つのデータを取得し、差分を取る。

```bash
# オープン/ドラフトPRのブランチ一覧（重複排除）
pr_branches=$(gh pr list --state open --json headRefName --jq '.[].headRefName' | sort -u)

# デフォルトブランチ名
default_branch=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

# リモートブランチ一覧（デフォルトブランチ除外）
remote_branches=$(git ls-remote --heads origin | awk '{print $2}' | sed 's|refs/heads/||' | grep -v "^${default_branch}$" | sort)

# PR に紐づいていないブランチ = 削除対象
stale_branches=$(comm -23 <(echo "$remote_branches") <(echo "$pr_branches"))
```

### 2. 結果をユーザーに報告

削除対象の件数とプレフィックス別の内訳を表示する。件数が0なら「整理済みです」で終了。

```bash
# プレフィックス別集計
echo "$stale_branches" | sed 's|/.*||' | sort | uniq -c | sort -rn
```

### 3. 削除範囲の確認

AskUserQuestionで削除範囲を確認する。選択肢:
- 全件一括削除
- 一覧を出力して手動選択
- キャンセル

ユーザーが確認するまで削除を実行しない。共有リポジトリのリモートブランチ削除は不可逆操作のため。

### 4. 一括削除の実行

```bash
echo "$stale_branches" | xargs -I {} -P 10 git push origin --delete {}
```

10並列で実行し、大量ブランチでも待ち時間を短縮する。

### 5. 結果確認

削除後に再度チェックし、残りのブランチがないか確認する。並列実行時の競合で失敗したブランチがあればリトライする。

## Gotchas

- `gh pr list --state open` はドラフトPRも含む。`--draft` フラグを追加しても結果は同じ（openのサブセット）
- `xargs -P 10` の並列pushでSSH接続が競合し、一部ブランチの削除が失敗することがある。削除後に必ず残存チェック→リトライする
- `git branch -r` ではなく `git ls-remote --heads origin` を使う。ローカルのリモート追跡ブランチはfetch/pruneの状態に依存するため、リモートの実態と乖離する可能性がある
