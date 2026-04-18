# Greptile コードレビュールール（IaC）

## 優先度ラベル

- [P0] 本番障害・セキュリティリスクに直結
- [P1] 運用障害・設定不整合のリスク
- [P2] コード品質・保守性の改善

## 出力形式

- 日本語（ですます調）で記述
- 指摘には具体的な修正案またはコード例を含める
- P2 の指摘は合計 5 件以内

## レビュー観点（IaC固有）

- IAM: 最小権限の原則、roles/editor禁止、roles/ownerは明示管理のみ、allUsers/allAuthenticatedUsers禁止
- WIF: attribute_conditionによるリポジトリ制限を必ず設定
- State: import/moved/removedブロックの宣言的記述
- API: disable_on_destroy = true の設定
- Project: lifecycle.prevent_destroy = true の設定
- 命名: Terraform識別子はsnake_case、リソース名はハイフン区切り
- IAM管理: iam_member（加算的）を使用、iam_binding/iam_policyは禁止

<!-- ここにリポジトリ固有の観点を追記 -->
