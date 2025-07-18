# Claude Code グローバル設定

このファイルは、Claude Codeで使用するコア設定を管理します。

## 🎯 基本原則

### 言語設定
- **日本語コミュニケーション**: すべての返答は日本語
- **英語思考プロセス**: 内部的な問題解決は英語で実行

### 作業アプローチ
- **ToDoリスト必須**: 作業開始時に必ず計画を可視化
- **段階的実装**: 複雑なタスクは適切な粒度に分解
- **MVP方式**: 改善項目は重要度順に一つずつ実装

## ⚡ よく使う指示パターン

### Terraform作業時
1. `terraform plan`実行 → 影響範囲確認
2. variables.tf更新 → README.md更新確認  
3. IAM変更 → セキュリティレビュー必須

### PR作成時
1. 単一改善項目に限定
2. 完了基準の明確化
3. 次のPR計画を記載

### リファクタリング時
1. 改善項目リストの作成と優先度付け
2. 🚨セキュリティ > ⚠️パフォーマンス > 💡保守性 > 📝可読性
3. 前のPRがマージされてから次の項目に着手

### thコマンドでの作業報告
1. `th "作業内容"`でObsidianデイリーノートに自動記録
2. タイムスタンプ付きでメモセクションに追加
3. 完了タスクや進行状況を簡潔に記載
4. 重要な発見や次のステップをメモ

## 🔗 詳細設定

### よく使う情報
- **[クイックリファレンス](quick-reference.md)** - 頻出パターンと即座に使える指示
- **[Terraformワークフロー](terraform-workflow.md)** - Terraform特化の詳細手順

### 専門ワークフロー  
- [PRレビュープロセス](review-process.md)
- [ドキュメント更新チェック](documentation-checks.md)
- [段階的リファクタリング戦略](refactoring-strategy.md)

### 開発環境
- [技術スタック制約](tech-constraints.md)  
- [セキュリティ基準](security-guidelines.md)
- [効率化メトリクス](efficiency-metrics.md)

## 📝 重要な注意事項
- パスワードや秘密鍵は記載しない
- 環境固有の情報は `.env.local` で管理
- 日時関連作業では必ず `date "+%Y-%m-%d (%a) %H:%M"` で確認