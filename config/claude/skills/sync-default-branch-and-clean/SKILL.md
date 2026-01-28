---
name: sync-default-branch-and-clean
description: デフォルトブランチを最新化して不要なローカルブランチを削除
user-invocable: true
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

#### lock待機関数

worktree環境では複数の場所でlockが発生するため、git操作前にlockを確認・待機する:

```bash
wait_git_lock() {
  local git_dir git_common_dir count=0
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1

  while [ "$count" -lt 20 ]; do
    # worktree固有dir + 共通dirの両方で *.lock を確認
    if find "$git_dir" "$git_common_dir" -maxdepth 2 -name '*.lock' -print -quit 2>/dev/null | grep -q .; then
      echo "Git lock detected, waiting... ($count)"
      sleep 0.5
      count=$((count + 1))
    else
      return 0
    fi
  done
  echo "Warning: Git lock timeout after 10 seconds"
  return 1
}
```

以降の各gitコマンド（checkout, fetch, pull等）の前に `wait_git_lock` を呼び出す。

#### worktree 内で実行時の安全対策

worktree 内で実行された場合、メインリポジトリに移動してから処理を行う:

```bash
# worktree 内かどうかを判定（.git がファイルの場合は worktree）
if [ -f ".git" ]; then
    # メインリポジトリのパスを取得
    MAIN_REPO=$(git rev-parse --git-common-dir | sed 's|/.git$||')
    echo "worktree 内で実行されました。メインリポジトリに移動します: $MAIN_REPO"
    cd "$MAIN_REPO"
fi
```

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

worktree環境の場合、マージ済みPRに対応するworktreeを削除:

```bash
# worktree一覧を取得（メインworktree以外）
git worktree list | tail -n +2 | while read wt_path wt_commit wt_branch; do
    # ブランチ名を抽出（[branch-name] 形式）
    branch=$(echo "$wt_branch" | tr -d '[]')

    # PRの状態を確認
    pr_state=$(gh pr list --head "$branch" --state all --json state -q '.[0].state' 2>/dev/null)

    if [[ "$pr_state" == "MERGED" ]]; then
        echo "マージ済み: $wt_path ($branch)"
        # 削除候補としてリストアップ
    fi
done
```

削除実行:
```bash
git wt -d <branch|worktree>   # 安全な削除（マージ済みの場合のみ）
git wt -D <branch|worktree>   # 強制削除
```

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

worktree使用時は追加の確認が必要:

```bash
# worktree一覧を確認
git wt

# 別のworktreeでチェックアウト中のブランチは削除不可
# → 先にworktreeを削除する必要がある
git wt -d <branch|worktree>   # 安全な削除
git wt -D <branch|worktree>   # 強制削除
```

削除できないブランチがある場合:
1. `git wt` でどのworktreeが使用中か確認
2. 不要なworktreeを `git wt -d` で削除
3. その後ブランチを削除

## 注意事項

- デフォルトブランチが検出できない場合はエラーを表示
- 未コミット変更がある場合は、事前にコミットまたはstash推奨
- gone ブランチは `-D` で強制削除されるため、未push のコミットがある場合は注意
- worktree使用中のブランチは削除できない（先に `git wt -d` でworktreeを削除）
- worktree 内で実行した場合、自動的にメインリポジトリに移動してから処理を行う
