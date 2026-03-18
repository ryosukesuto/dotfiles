---
name: sync-default-branch-and-clean
description: デフォルトブランチを最新化して不要なローカルブランチを削除
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(git-wt:*)
---

# /sync-default-branch-and-clean - デフォルトブランチの同期とクリーニング

デフォルトブランチ（main/master）に切り替えて最新状態に同期し、マージ済みのworktreeとローカルブランチを安全に削除します。

## 現在の状態確認
```bash
git status --porcelain
git branch --show-current
git branch -vv
git remote -v
```

## 実行プロセス

### フェーズ0: lock待機とworktree安全対策

詳細実装は `${CLAUDE_SKILL_DIR}/reference.md` の「lock待機関数」「worktree 内で実行時の安全対策」を参照。

- lock待機: `wait_git_lock` 関数を定義し、各gitコマンド前に呼び出す（20回リトライ、0.5秒間隔）
- worktree検出: `.git` がファイルなら worktree 内と判定し、`git rev-parse --git-common-dir` でメインリポジトリに移動

### フェーズ1: デフォルトブランチの同期

1. デフォルトブランチを検出
```bash
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)

if [ -z "$DEFAULT_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    DEFAULT_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    DEFAULT_BRANCH="master"
  fi
fi
```

2. リモート名を検出
```bash
REMOTE=$(git remote | grep -E '^origin$' || git remote | head -n1)
```

3. 未コミットの変更を確認
4. デフォルトブランチに切り替え: `wait_git_lock && git checkout $DEFAULT_BRANCH`
5. リモートから最新の変更を取得: `wait_git_lock && git fetch $REMOTE --prune`
6. 最新状態に更新: `wait_git_lock && git pull --rebase $REMOTE $DEFAULT_BRANCH`

### フェーズ2: 不要なworktreeの削除

詳細実装は `${CLAUDE_SKILL_DIR}/reference.md` の「フェーズ2: 不要なworktreeの削除（詳細）」を参照。

worktree環境の場合、`gh pr list --state all` でPR状態を確認し、`MERGED` のworktreeを削除候補としてリストアップ。
削除は `git wt -d`（安全）または `git wt -D`（強制）で実行する。

### フェーズ3: 不要なローカルブランチの削除

7. 削除対象ブランチの分析
```bash
# マージ済みブランチを確認
MERGED_BRANCHES=$(git branch --merged | grep -v "\*" | grep -v "^  main$" | grep -v "^  master$" | sed 's/^ *//')

# リモートで削除されたブランチを確認（gone）
GONE_BRANCHES=$(git branch -vv | grep ': gone]' | awk '{print $1}')
```

8. 削除候補の分類と表示
   - 安全に削除可能: マージ済みまたはリモートで削除済み（gone）
   - 注意が必要: 未マージだがリモートに存在しないブランチ
   - 保持: デフォルトブランチ、現在のブランチ、worktree使用中のブランチ

9. 段階的な削除実行
```bash
# マージ済みブランチを削除
for branch in $MERGED_BRANCHES; do
  git branch -d "$branch"
done

# リモートで削除されたブランチを削除
for branch in $GONE_BRANCHES; do
  git branch -D "$branch"
done
```

## 安全性の考慮

- 保護されるブランチ: main、master、現在のブランチ
- 未コミット変更: 実行前に警告を表示、続行確認
- 削除方針:
  - マージ済みブランチ: `-d` で安全に削除
  - gone ブランチ: `-D` で強制削除

## worktree環境での注意

詳細手順は `${CLAUDE_SKILL_DIR}/reference.md` の「worktree環境での注意」を参照。

別worktreeで使用中のブランチは削除不可。先に `git wt -d` でworktreeを削除してからブランチを削除する。

## 注意事項

- デフォルトブランチが検出できない場合はエラーを表示
- 未コミット変更がある場合は、事前にコミットまたはstash推奨
- gone ブランチは `-D` で強制削除されるため、未push のコミットがある場合は注意
- worktree使用中のブランチは削除できない（先に `git wt -d` でworktreeを削除）
- worktree 内で実行した場合、自動的にメインリポジトリに移動してから処理を行う

## Gotchas

(運用しながら追記)
