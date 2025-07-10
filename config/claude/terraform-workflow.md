# Terraformワークフロー

Terraformプロジェクトでの作業に特化した設定とワークフロー。

## 🏗️ Terraform作業の基本フロー

### 1. 変更作業完了時
- `terraform plan`の実行と結果確認
- 影響を受けるリソースの特定と文書化
- IAM権限やセキュリティ影響の評価
- 環境別設定の差異確認

### 2. プッシュ前確認
- `git diff --name-only`でTerraformファイルの変更確認
- variables.tf、outputs.tfの説明更新
- README.mdのリソース構成図更新
- terraform planの結果をPR説明に含める

### 3. ドキュメント更新が必要なパターン

#### Terraform プロジェクト（重点対象）
1. **リソース定義変更** → README.mdのリソース構成図・説明更新
2. **variables.tf更新** → 入力変数の説明とデフォルト値の文書化
3. **outputs.tf追加/変更** → 出力値の用途と使用例の記載
4. **provider設定変更** → バージョン要件とセットアップ手順の更新
5. **modules追加/変更** → モジュールの仕様と使用方法の文書化
6. **環境別設定ファイル** → 環境固有の設定手順と注意事項の記載
7. **IAMポリシー/ロール変更** → 必要な権限とセキュリティ考慮事項の説明

## 🚀 Pre-push Hook（Terraform特化）

```bash
#!/bin/sh
# Terraformプロジェクト用ドキュメント更新チェック

# Terraform関連ファイルパターン
tf_patterns="\.tf$|\.tfvars$|\.tfvars\.json$|terraform\.lock\.hcl$"
config_patterns="\.terraformrc$|\.terraform\.d/.*|modules/.*"

# 変更されたファイルを確認
changed_tf_files=$(git diff --name-only HEAD~1 | grep -E "$tf_patterns")
changed_config_files=$(git diff --name-only HEAD~1 | grep -E "$config_patterns")

if [ -n "$changed_tf_files" ] || [ -n "$changed_config_files" ]; then
    echo "🏗️  Terraform関連ファイルの変更を検出しました："
    
    if [ -n "$changed_tf_files" ]; then
        echo ""
        echo "📄 Terraformファイル:"
        echo "$changed_tf_files" | sed 's/^/  - /'
    fi
    
    echo ""
    echo "📚 以下のドキュメント更新を確認してください："
    echo "  ✅ README.md - リソース構成図・説明"
    echo "  ✅ variables.tf - 入力変数の説明"
    echo "  ✅ outputs.tf - 出力値の用途"
    echo "  ✅ provider要件 - バージョン・セットアップ手順"
    echo "  ✅ IAM権限 - 必要な権限とセキュリティ考慮事項"
    echo ""
    echo "💡 Terraformプロジェクトでは特に以下が重要です："
    echo "  - terraform planの実行結果"
    echo "  - 影響範囲の説明"
    echo "  - 環境別の設定手順"
    echo ""
    echo "継続しますか？ (Enter: 継続 / Ctrl+C: 中止)"
    read confirmation
fi
```

## 📝 Terraform固有の文書化品質基準

- **リソース依存関係の図解**
- **入力変数のvalidationルールと例**
- **出力値の用途と他モジュールでの使用例**
- **デプロイ手順と注意事項**
- **環境間の設定差異説明**

## 🔧 効率化のコツ

### 段階的更新
- terraform planと並行してドキュメントを更新
- モジュール設計時は事前にREADME構造を検討
- リソース追加時は依存関係図も同時更新

### テンプレート活用
- 新しいTerraformモジュール用のREADMEテンプレート
- variables.tf説明用のドキュメントテンプレート
- IAM権限チェックリスト

### レビュー観点
- terraform planの結果理解
- リソース影響範囲の説明
- 環境間の設定差異説明
- セキュリティ・コスト影響の記載

## 🚫 重要な制約事項

- **GitOpsワークフロー厳守**: ローカル実行制限
- **BigQuery**: asia-northeast1リージョン、クエリコスト考慮必須
- **dbt**: データリネージュ・テスト・ドキュメント必須