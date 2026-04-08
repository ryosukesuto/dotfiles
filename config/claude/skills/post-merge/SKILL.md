---
name: post-merge
description: PRマージ後の後片付け。Linear Issue/プロジェクト更新、デフォルトブランチ同期、ブランチ/worktree削除。「マージしました」「マージした」「merged」「マージ後」「後片付け」等で起動。
user-invocable: true
allowed-tools:
  - Bash(git:*)
  - Bash(git-wt:*)
  - Bash(gh:*)
  - mcp__linear-server__get_issue
  - mcp__linear-server__save_issue
  - mcp__linear-server__get_project
  - mcp__linear-server__list_issues
  - mcp__linear-server__save_project
  - mcp__linear-server__save_status_update
  - mcp__linear-server__get_status_updates
  - AskUserQuestion
---

# /post-merge - マージ後の後片付け

PRマージ後に必要な3つの処理を一括実行する。手動でやると漏れやすいLinear更新とブランチ削除を確実に行う。

## フロー概要

```
Phase 1: Linear Issue更新
Phase 2: プロジェクト進捗確認・更新
Phase 3: デフォルトブランチに切替・同期
Phase 4: ブランチ/worktree削除
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

## Phase 2: プロジェクト進捗確認・更新

Done にした Issue がプロジェクトに属している場合、プロジェクト側の状態も最新化する。Issue だけ閉じてプロジェクトの進捗が放置されると、週次レビューまで実態と乖離する。

### 前提条件

Phase 1 で Issue を Done にできた場合のみ実行。Issue が見つからなかった / スキップした場合は Phase 3 へ進む。

### 手順

1. Phase 1 で取得した Issue の `project` フィールドを確認
   - プロジェクトに属していなければスキップ

2. プロジェクトの残タスクを確認:
   ```
   mcp__linear-server__list_issues(
     project: <projectId>,
     limit: 100
   )
   ```
   - Done / Canceled 以外の Issue 数をカウント

3. 残タスク状況をユーザーに報告:
   ```
   プロジェクト「○○」の進捗:
   - 完了した Issue: PF-XXXX（今回）
   - 残タスク: X件（In Progress: Y, Todo: Z）
   ```

4. 全 Issue が完了している場合:
   - `get_project(id: <projectId>)` でプロジェクト詳細を取得
   - ユーザーに Completed への更新を提案:
     ```
     プロジェクト「○○」の全タスクが完了しています。Completedにしますか？
     ```
   - 承認後、`save_project(id: <projectId>, state: "completed")` で更新

5. Status Update の投稿（任意）:
   - `get_status_updates(type: "project", project: <projectId>, limit: 1)` で直近の Update を確認
   - 直近 Update から 3日以上経過している場合、Update 投稿を提案
   - ユーザーが希望すれば、linear-triage の Update フォーマットに準拠して `save_status_update` で投稿
   - 急がない場合はスキップ（週次の /linear-triage でまとめて更新できる）

## Phase 3: デフォルトブランチに切替・同期

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

## Phase 4: ブランチ/worktree削除

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
   - プロジェクト「○○」: 残タスク X件 / Status Update 投稿済み
   - ブランチ: feature/xxx 削除済み
   - worktree: .worktrees/feature/xxx 削除済み
   - 現在: main (最新)
   ```

## Gotchas

- worktree内で実行した場合、Phase 3で `cd` するためClaude Codeのcwdが変わる。Phase 4はメインリポジトリで実行される
- `git branch -d` はデフォルトブランチにマージされていないと失敗する。`git pull --rebase` 後に実行すること
- Phase 2 の `save_project(state: "completed")` はプロジェクトをアーカイブする操作。全タスク完了を確認し、必ずユーザー承認を経てから実行する
- PRがsquash mergeされた場合、`-d` が「未マージ」と判定することがある。`gh pr view` でmerged確認後なら `-D` で安全
