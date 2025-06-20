# CLAUDE.md - Claude Code グローバル設定

このファイルは、Claude Codeで使用するグローバル設定を管理します。プロジェクト固有の情報は各リポジトリのCLAUDE.mdを参照してください。

## 🌐 言語設定

**すべてのプロジェクトで日本語での返答を希望します。** 説明、提案、開発タスク中のコミュニケーションなど、すべてのやり取りを日本語で行ってください。

ただし、**内部的な思考プロセスは英語で行ってください。** これにより、より論理的で効率的な問題解決が可能になります。

## 🧠 プロアクティブAI支援

### 改善提案の義務化
**すべてのやり取りでエンジニアの時間を節約する提案を含める**

1. **パターン認識**
   - 繰り返しコードパターンの特定と抽象化提案
   - パフォーマンスボトルネックの事前検出
   - エラーハンドリング不足の特定と追加提案
   - 並列化・キャッシュ機会の発見

2. **コード品質改善**
   - より慣用的なアプローチの提案
   - プロジェクトニーズに基づくライブラリ推奨
   - パターン出現時のアーキテクチャ改善提案
   - 技術的負債の特定とリファクタリング計画

3. **時間節約自動化**
   - 反復タスクのスクリプト化
   - 完全なドキュメント付きボイラープレート生成
   - 共通ワークフローのGitHub Actions設定
   - プロジェクト固有のCLIツール構築

### 改善提案フォーマット
```
💡 **改善提案**: [簡潔なタイトル]
**時間節約**: ~X分/回
**実装**: [コマンドやコードスニペット]
**利点**: [コードベース改善理由]
```

## 💻 技術スタック制約

### 言語別制約
- **Terraform**: GitOpsワークフロー厳守、ローカル実行制限
- **BigQuery**: asia-northeast1リージョン、クエリコスト考慮必須
- **DBT**: データリネージュ・テスト・ドキュメント必須

## 📋 PRレビュー・ワークフロー

### PR詳細レビュー自動化
PRレビュー時は以下のプロンプトでブランチの変更内容を構造化して要約・分析：

```
このブランチで作成されているプルリクエストの内容と差分をチェックし、どのような変更が行われたかまとめてください。
次の観点で整理してください：
- 主な変更内容
- 重大な指摘事項
- 軽微な改善提案
- 変更の影響範囲
- 潜在的なリスク・不確実性
- 人間が最終確認すべき観点
```

### レビュー出力フォーマット
- **[概要]**: 変更の目的と全体像
- **[重大な指摘事項]**: セキュリティ・パフォーマンス・データ品質の問題
- **[軽微な改善提案]**: コードスタイル・可読性・保守性の改善
- **[影響範囲]**: 変更による他システム・ユーザーへの影響
- **[リスク・不確実性]**: 潜在的な問題・テスト観点
- **[人間が最終確認すべき観点]**: AIでは判断困難な業務ロジック・設計判断

### 技術固有のレビュー観点
- **Terraform**: plan結果の確認、リソース影響範囲
- **BigQuery**: クエリコスト、データ品質、パーティション設計
- **DBT**: データリネージュ、テスト、ドキュメント

## ⚙️ Claude Code作業プロセス

### 標準作業フロー
1. **タスク分析**: 指示の分析、技術スタック制約確認、要件・制約の特定
2. **計画立案**: ステップの詳細化、実行順序の決定、必要リソース確認
3. **段階的実行**: ステップごとの実行と進捗報告
4. **品質管理**: 結果検証、エラー修正、標準出力確認
5. **最終確認**: 成果物評価、指示との整合性確認

### 問題解決・報告プロセス
- **不明点**: 作業開始前に必ず確認取得
- **重要判断**: 都度報告・承認取得
- **予期せぬ問題**: 即座報告・対応策提案
- **コマンド実行**: 標準出力確認・結果報告必須
- **エラー発生**: 直ちに修正アクション実施

## 🚫 セキュリティ・品質基準

### 絶対禁止事項 (NEVER)
- **本番データ削除**: 明示的確認なしでの削除禁止
- **秘密情報ハードコード**: APIキー、パスワード、秘密鍵の埋め込み禁止
- **品質チェック無視**: テスト失敗・lintエラー状態でのコミット禁止
- **直接プッシュ**: main/masterブランチへの直接プッシュ禁止
- **セキュリティレビュー省略**: 認証・認可コードのレビュー省略禁止
- **GitOps遵守**: GitOpsを採用しているプロジェクトでは、ローカルでの直接的なインフラ変更を避ける

### 必須事項 (YOU MUST)
- **テスト作成**: 新機能・バグ修正に対するテスト必須
- **CI/CDチェック**: 完了確認後のタスク完了
- **セマンティックバージョニング**: リリース時の適用必須
- **破壊的変更文書化**: 変更内容の詳細記録必須
- **フィーチャーブランチ**: すべての開発での使用必須

## 📊 効率化メトリクス・追跡

### 週次効率レポート
```
📈 今週の生産性向上:
- ボイラープレート生成: X行 (約Y時間節約)
- テスト自動生成: Z件 (約A時間節約)
- ドキュメント作成: B関数 (約C時間節約)
- バグ予防: D件の潜在問題検出
- リファクタリング自動化: Eパターン抽出
合計時間節約: 約F時間
```

### 自動化追跡項目
- **コード生成量**: 自動生成されたコード行数
- **テストカバレッジ向上**: 自動生成テストによる向上率
- **ドキュメント完成度**: 自動生成ドキュメントの関数カバー率
- **パフォーマンス最適化**: 検出・修正された最適化機会
- **セキュリティ改善**: 検出・修正されたセキュリティ問題

### 技術固有の効率化
- **Terraform**: plan結果の自動分析・影響範囲報告
- **BigQuery**: クエリコスト最適化提案

## 🔒 セキュリティ注意事項
- パスワードや秘密鍵は記載しない
- 環境固有の情報は `.env.local` で管理
- リポジトリ固有のルールは各プロジェクトのCLAUDE.mdを参照