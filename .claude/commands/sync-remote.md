---
description: 起点ブランチに戻ってリモートと同期
---

# 起点ブランチへの復帰と同期

featureブランチから起点となるブランチ（sandbox、main等）に戻り、リモートの最新状態に同期します。開発作業を一時中断して、最新の変更を取り込む際に使用します。

## 現在の状態確認
! git status --porcelain
! git branch --show-current
! git log --oneline -1 HEAD

## 同期プロセスの実行

1. **現在のfeatureブランチでの変更を保存**
   - 未コミットの変更がある場合は一時的にstashに保存またはコミット
   - 現在のブランチ名を記録

2. **起点ブランチの判定**
   - デフォルト: `sandbox`
   - mainブランチから派生している場合: `main`
   - その他のベースブランチを検出

3. **起点ブランチに切り替え**
   ```bash
   git checkout sandbox  # または main
   ```

4. **リモートから最新の変更を取得**
   ```bash
   git fetch origin --prune
   git pull --ff-only origin sandbox  # fast-forward onlyで安全に更新
   ```

5. **結果の確認と次のアクション提示**
   - 更新内容のサマリー表示
   - 元のfeatureブランチに戻る方法を提示
   - 必要に応じてfeatureブランチのリベース方法を提案

## 注意事項
- 起点ブランチではfast-forward onlyで更新（強制的な変更を防ぐ）
- featureブランチに未コミットの変更がある場合は事前に保存
- 起点ブランチが更新された後、featureブランチのリベースが必要な場合がある
- `--prune`オプションでリモートで削除されたブランチの追跡情報を自動削除

## 使用例

```bash
# 現在feature/new-moduleブランチで作業中
$ /project:sync-remote

# 以下のような動作：
# 1. 現在のブランチ名を記録: feature/new-module
# 2. sandboxブランチに切り替え
# 3. origin/sandboxから最新を取得
# 4. "元のブランチに戻るには: git checkout feature/new-module"
```

## 関連コマンド
- **不要なブランチの削除**: `/user:clean-branches` コマンドを使用してください
- **featureブランチのリベース**: 起点ブランチ更新後に必要に応じて実行