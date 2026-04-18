## 業界動向サマリ（2026年）

Advisory → Gating への移行期。現時点での推奨構成は二層。

- Claude / Greptile: 助言層（advisory）。ブロックしない
- Checkov: gating層（block）。IaC専用、P0相当の静的解析のみ

Greptile は「コード生成エージェントと承認エージェントの分離」を原則とし、自己承認に反対している。
`statusCheck: true` は状態表示用の設定。これを Required Check に変えると block 相当になるため注意。

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

## Renovate Tier定義

T0〜T4 の詳細は `templates/renovate-tier-policy.md` と整合している。

| Tier | 対象 | automerge | 承認 |
|------|------|-----------|------|
| T0 | devDeps / 型定義 / Lint / GitHub Actions minor-patch-digest | yes | 不要 |
| T1 | Docker base image patch / runtime deps patch | yes（minimumReleaseAge 3-7日） | 不要 |
| T2 | Terraform provider minor / runtime minor | no | CODEOWNERSから1名 |
| T3 | major bump全般 / ORM / Terraform provider major | no | CODEOWNERS 1名 + 動作確認 |
| T4 | 決済・認証・残高・KYC関連 / Kubernetes major | no | 起案者以外2名 |

## Checkov設定方針

- `framework: terraform` を明示する
- `soft_fail: false` で P0 相当をブロック
- `baseline` ファイル: 新規導入直後は既存違反を凍結し、新規混入のみブロック
  - 初回: `checkov -d . --framework terraform --create-baseline`
  - その後: baseline ファイルをコミットし `baseline:` 行を有効化
- `skip_check`: 誤検知の多いルールを明示除外。コメントで理由を残す

## formal review 運用

`claude-review-formal.yml` を使う場合、GitHub Apps のトークンに `pull-requests: write` が必要。
GITHUB_TOKEN（デフォルト）は同一ジョブからの `pr review --approve` に対応しているが、
Branch Protection の「Required review from code owners」と組み合わせると意図しない動作になることがある。
導入前に Branch Protection の設定と照合すること。
