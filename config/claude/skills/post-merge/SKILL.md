---
name: post-merge
description: PRマージ後の後片付け。Linear Issue更新、デフォルトブランチ同期、ブランチ/worktree削除。「マージしました」「マージした」「merged」「マージ後」「後片付け」等で起動。
user-invocable: true
allowed-tools:
  - Bash(git:*)
  - Bash(git-wt:*)
  - Bash(gh:*)
  - mcp__linear-server__get_issue
  - mcp__linear-server__save_issue
  - AskUserQuestion
---

# /post-merge - マージ後の後片付け

PRマージ後に必要な3つの処理を一括実行する。手動でやると漏れやすいLinear更新とブランチ削除を確実に行う。

## フロー概要

```
Phase 1: Linear Issue更新
Phase 2: デフォルトブランチに切替・同期
Phase 3: ブランチ/worktree削除
```

## Phase 1: Linear Issue更新

マージしたPRに紐づくLinear Issueのステータスを更新する。Issue側の状態を放置すると週次レビューで差分が出る。

### 手順

1. 現在のブランチ名から `PF-XXXX` を抽出:
   ```bash
   BRANCH=$(git branch --show-current)
   ISSUE_ID=$(echo "$BRANCH" | grep -oE 'PF-[0-9]+' | head -1)
   ```

2. ブランチ名にIDがない場合、直近のPRから取得:
   ```bash
   gh pr list --head "$BRANCH" --state merged --json body,title,headRefName --jq '.[0]'
   ```
   → タイトル、body、ブランチ名から `PF-XXXX` を探す

3. IDが見つかった場合:
   - `get_issue` でIssue詳細を取得
   - ステータスがDone/Cancelledでなければ `save_issue(id: "PF-XXXX", state: "Done")` で更新
   - ユーザーに更新結果を報告

4. IDが見つからない場合:
   - ユーザーに確認（Issue IDを指定 / スキップ）

## Phase 2: デフォルトブランチに切替・同期

作業ブランチからデフォルトブランチに戻り、リモートの最新状態に同期する。

### 手順

1. 未コミットの変更を確認（あれば警告）
2. デフォルトブランチを検出:
   ```bash
   DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
   ```
3. worktree内の場合はメインリポジトリに移動:
   ```bash
   if [ -f ".git" ]; then
     MAIN_REPO=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$||')
     cd "$MAIN_REPO"
   fi
   ```
4. デフォルトブランチに切替: `git checkout $DEFAULT_BRANCH`
5. リモート同期: `git fetch origin --prune && git pull --rebase origin $DEFAULT_BRANCH`

## Phase 3: ブランチ/worktree削除

マージ済みブランチとworktreeを削除する。放置するとworktreeが増え続けてディスクを圧迫する。

### 手順

1. マージ元のブランチ名を特定（Phase 1で取得済み）

2. worktreeが存在する場合は先に削除:
   ```bash
   git worktree list | grep "$BRANCH"
   # 存在すれば:
   git-wt -d "$BRANCH"
   ```

3. ローカルブランチを削除:
   ```bash
   git branch -d "$BRANCH"
   ```
   `-d` で失敗する場合（未マージ扱い）はユーザーに確認してから `-D` で強制削除

4. 完了報告:
   ```
   後片付け完了:
   - Linear: PF-XXXX → Done
   - ブランチ: feature/xxx 削除済み
   - worktree: .worktrees/feature/xxx 削除済み
   - 現在: main (最新)
   ```

## Gotchas

- worktree内で実行した場合、Phase 2で `cd` するためClaude Codeのcwdが変わる。Phase 3はメインリポジトリで実行される
- `git branch -d` はデフォルトブランチにマージされていないと失敗する。`git pull --rebase` 後に実行すること
- PRがsquash mergeされた場合、`-d` が「未マージ」と判定することがある。`gh pr view` でmerged確認後なら `-D` で安全
