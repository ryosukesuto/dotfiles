---
description: デフォルトブランチに移動して最新状態に同期
---

# デフォルトブランチとの同期

デフォルトブランチ（main/master）に切り替えて、リモートの最新状態に同期します。

## 現在の状態確認
! git status --porcelain
! git branch --show-current
! git remote -v

## 同期プロセスの実行

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
   - 必要に応じてstashに保存するか確認

4. **デフォルトブランチに切り替え**
   ```bash
   git checkout $DEFAULT_BRANCH
   ```

5. **リモートから最新の変更を取得**
   ```bash
   git fetch $REMOTE --prune
   ```

6. **最新状態に更新**
   ```bash
   # リベースでクリーンに更新
   git pull --rebase $REMOTE $DEFAULT_BRANCH
   ```

7. **結果の確認**
   - 正常に同期できた場合は更新内容をサマリー表示
   - コンフリクトがある場合は解決方法を提示

## 注意事項
- 未コミットの変更がある場合は、事前にコミットまたはstash推奨
- マージコミットを避けるため、常にリベースを使用
- `--prune`オプションでリモートで削除されたブランチの追跡情報を自動削除
- デフォルトブランチが検出できない場合はエラーを表示

## 関連コマンド
- **不要なブランチの削除**: `/user:clean-branches` コマンドを使用してください
- **GitHub CI状態確認**: `/user:check-github-ci` コマンドを使用してください
