---
description: GitHub ActionsワークフローのCI状態をチェック
---

# GitHub CI状態チェック

現在のリポジトリのGitHub Actionsワークフローの実行状態を確認し、CI/CDパイプラインの健全性を監視します。失敗したワークフローやPRのチェック状態を素早く把握できます。

## 現在のリポジトリ状態確認

! git status --porcelain
! git branch --show-current
! git remote get-url origin

## CI状態チェックプロセス

1. **GitHub CLI利用可能性の確認**
   ```bash
   gh --version
   gh auth status
   ```

2. **最新のワークフロー実行状態を取得**
   ```bash
   gh run list --limit 10 --json status,conclusion,name,createdAt,headBranch,workflowName
   ```

3. **現在のブランチのチェック状態**
   ```bash
   gh pr checks --required-only
   ```
   - 現在のブランチがPRに関連付けられている場合のチェック状態
   - 必須チェックの通過状況を確認

4. **失敗したワークフローの詳細表示**
   ```bash
   gh run list --status failure --limit 5 --json conclusion,name,createdAt,headBranch,url,workflowName
   ```

5. **進行中のワークフロー監視**
   ```bash
   gh run list --status in_progress --json name,createdAt,headBranch,workflowName,url
   ```

## 出力情報の整理

### 成功パターン
- ✅ すべてのワークフローが成功
- ✅ 必須チェックがすべて通過
- 📊 最新のワークフロー実行サマリー

### 注意が必要なパターン
- ⚠️ 一部のワークフローが失敗
- ⚠️ 必須チェックが未完了または失敗
- 🔄 長時間実行中のワークフロー

### エラーパターン
- ❌ 複数のワークフローが失敗
- ❌ 必須チェックが失敗してマージブロック
- 🚨 認証エラーまたはリポジトリアクセス権限なし

## トラブルシューティング提案

### ワークフロー失敗時
1. **失敗ログの確認方法**
   ```bash
   gh run view [RUN_ID] --log-failed
   ```

2. **再実行の提案**
   ```bash
   gh run rerun [RUN_ID] --failed-jobs
   ```

3. **よくある失敗パターンの特定**
   - テスト失敗
   - ビルドエラー
   - 依存関係の問題
   - 権限エラー

### PRチェック失敗時
1. **該当PRの詳細確認**
   ```bash
   gh pr view --json checks,statusCheckRollup
   ```

2. **ローカルでの修正提案**
   - テスト実行: `npm test` または `yarn test`
   - リント修正: `npm run lint --fix`
   - 型チェック: `npm run type-check`

## セキュリティ考慮事項

- GitHub CLIの認証状態を確認（`gh auth status`）
- プライベートリポジトリへのアクセス権限を確認
- ワークフロー実行ログに機密情報が含まれていないかチェック
- 外部からのPRの場合、セキュリティ制限を考慮

## 使用例

```bash
# 基本的なCI状態チェック
$ /user:check-github-ci

# 以下のような情報を表示：
# 📊 ワークフロー実行状況 (直近10件)
# ✅ feature/new-api-endpoint: All checks passed
# ⚠️ main: 1 failed, 2 passed
# 🔄 PR #123: 2 pending, 1 success

# 🎯 推奨アクション:
# 1. mainブランチの失敗したワークフローを確認
# 2. PR #123の未完了チェックを監視
```

## 関連コマンド

- **リモート同期**: `/project:sync-remote` - 最新のmainブランチに同期後にCI確認
- **ブランチクリーンアップ**: `/user:clean-branches` - CI失敗のブランチ整理
- **GitHub PR管理**: `gh pr` コマンド群での詳細PR操作

## 高度な使用方法

### 特定ワークフローの監視
```bash
gh run list --workflow="CI" --limit 5
```

### 特定期間のCI成功率分析
```bash
gh run list --created="2024-01-01..2024-01-31" --json conclusion
```

### Slack/Teams通知との連携
CI状態をチームチャットに自動通知する設定の提案も含める。