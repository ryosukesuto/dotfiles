## 役割分担

| ツール | 役割 |
|--------|------|
| Greptile | 既存コード一貫性・cross-repo文脈 |
| Claude Code | PR内ロジック・設計・セキュリティリスク |
| Checkov | 静的解析gating（IaC専用、P0 blockに一本化） |

## IaC観点カタログ

SKILL.md の手順4で `{{REVIEW_CRITERIA}}` に展開する内容。

```
## レビュー観点（IaC固有）

- IAM: 最小権限の原則、roles/editor禁止、roles/ownerは明示管理のみ、allUsers/allAuthenticatedUsers禁止
- WIF: attribute_conditionによるリポジトリ制限を必ず設定
- State: import/moved/removedブロックの宣言的記述
- API: disable_on_destroy = true の設定
- Project: lifecycle.prevent_destroy = true の設定
- 命名: Terraform識別子はsnake_case、リソース名はハイフン区切り
- IAM管理: iam_member（加算的）を使用、iam_binding/iam_policyは禁止
```

## Checkov設定方針

- `framework: terraform` を明示する
- `soft_fail: false` で P0 相当をブロック
- `baseline` ファイル: 新規導入直後は既存違反を凍結し、新規混入のみブロック
  - 初回: `checkov -d . --framework terraform --create-baseline`
  - その後: baseline ファイルをコミットし `baseline:` 行を有効化
- `skip_check`: 誤検知の多いルールを明示除外。コメントで理由を残す

