---
description: デフォルトブランチを最新化して不要なローカルブランチを削除
---

# デフォルトブランチの同期とクリーニング

デフォルトブランチ（main/master）に切り替えて最新状態に同期し、不要なローカルブランチを安全に削除します。

## 現在の状態確認
! git status --porcelain
! git branch --show-current
! git branch -vv
! git remote -v

## 実行プロセス

### フェーズ1: デフォルトブランチの同期

1. **デフォルトブランチを検出**
   ```bash
   # リモートのデフォルトブランチを取得
   DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)

   # 失敗した場合は一般的なブランチ名を試す
   if [ -z "$DEFAULT_BRANCH" ]; then
     if git show-ref --verify --quiet refs/heads/main; then
       DEFAULT_BRANCH="main"
     elif git show-ref --verify --quiet refs/heads/master; then
       DEFAULT_BRANCH="master"
     fi
   fi

   echo "デフォルトブランチ: $DEFAULT_BRANCH"
   ```

2. **リモート名を検出**
   ```bash
   # originが存在する場合は優先、なければ最初のリモートを使用
   REMOTE=$(git remote | grep -E '^origin$' || git remote | head -n1)
   echo "使用するリモート: $REMOTE"
   ```

3. **未コミットの変更を確認**
   - ローカルに未コミットの変更がある場合は警告を表示
   - 続行するかどうか確認

4. **デフォルトブランチに切り替え**
   ```bash
   git checkout $DEFAULT_BRANCH
   ```

5. **リモートから最新の変更を取得**
   ```bash
   # --pruneでリモートで削除されたブランチの追跡情報も削除
   git fetch $REMOTE --prune
   ```

6. **最新状態に更新**
   ```bash
   # リベースでクリーンに更新
   git pull --rebase $REMOTE $DEFAULT_BRANCH
   ```

### フェーズ2: 不要なローカルブランチの削除

7. **削除対象ブランチの分析**
   ```bash
   # マージ済みブランチを確認
   MERGED_BRANCHES=$(git branch --merged | grep -v "\*" | grep -v "^  main$" | grep -v "^  master$" | grep -v "^  sandbox$" | sed 's/^ *//')

   # リモートで削除されたブランチを確認（gone）
   GONE_BRANCHES=$(git branch -vv | grep ': gone]' | awk '{print $1}')

   echo "=== 削除候補ブランチ ==="
   echo "マージ済み:"
   echo "$MERGED_BRANCHES"
   echo ""
   echo "リモートに存在しない（gone）:"
   echo "$GONE_BRANCHES"
   ```

8. **削除候補の分類と表示**
   - **安全に削除可能**: マージ済みまたはリモートで削除済み（gone）
   - **注意が必要**: 未マージだがリモートに存在しないブランチ
   - **保持**: デフォルトブランチ、現在のブランチ

9. **段階的な削除実行**
   ```bash
   # マージ済みブランチを削除
   for branch in $MERGED_BRANCHES; do
     echo "削除: $branch (マージ済み)"
     git branch -d "$branch"
   done

   # リモートで削除されたブランチを削除
   for branch in $GONE_BRANCHES; do
     # マージ済みブランチと重複しないものだけ処理
     if ! echo "$MERGED_BRANCHES" | grep -q "^$branch$"; then
       echo "削除: $branch (リモートに存在しない)"
       git branch -D "$branch"  # gone の場合は -D で強制削除
     fi
   done
   ```

10. **削除結果のサマリー**
    - 削除されたブランチのリスト
    - 残存ブランチとその理由
    - 現在のブランチ状況

## 安全性の考慮

- **保護されるブランチ**: main、master、sandbox、現在のブランチ
- **未コミット変更**: 実行前に警告を表示、続行確認
- **削除方針**:
  - マージ済みブランチ: `-d` で安全に削除
  - gone ブランチ: `-D` で強制削除（リモートで削除済みのため）
- **エラーハンドリング**: 各ステップでエラーがあれば停止して状況を報告

## 注意事項

- デフォルトブランチが検出できない場合はエラーを表示
- 未コミット変更がある場合は、事前にコミットまたはstash推奨
- gone ブランチは `-D` で強制削除されるため、未push のコミットがある場合は注意
- マージコミットを避けるため、デフォルトブランチの更新は常にリベースを使用

## 使用例

このコマンドを実行すると：
1. デフォルトブランチに切り替えて最新化
2. リモートで削除されたブランチの追跡情報を削除
3. マージ済みブランチとgoneブランチを自動削除
4. クリーンな状態のデフォルトブランチで作業再開可能

## 関連コマンド

- **ブランチ削除のみ**: `/user:clean-branches` コマンドを使用してください
- **同期のみ**: `/user:sync-default-branch` コマンドを使用してください
- **GitHub CI状態確認**: `/user:check-github-ci` コマンドを使用してください
