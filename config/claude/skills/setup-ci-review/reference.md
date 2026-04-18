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

## Claude Code workflow の成熟度レベル

setup-ci-review が生成する `claude-review.yml` は WinTicket/server で実運用されている構成をベースにしている。以下の機能が組み込まれている。

### コア機能（常に有効）

- `pull_request` トリガー（opened / synchronize / reopened / ready_for_review）
- `issue_comment` トリガー: `@claude` を含むコメントで手動再レビュー（MEMBER/OWNER/COLLABORATOR 限定）
- `gh pr checkout` step: issue_comment 時にPR branchに切り替え
- force-push 検出: `git merge-base --is-ancestor` で判定、フル/増分を切り替え
- `allowed_bots`: dependabot/renovate の bot PR もレビュー対象
- `display_report: true` + Workflow Summary
- インラインコメント投稿: `mcp__github_inline_comment__create_inline_comment`
- 履歴蓄積型トップレベルコメント: `<!-- claude-code-review -->` マーカー付きコメントに追記
- PR review 判定: P0/P1 ありで `--request-changes`、無ければ `--comment`
- WebSearch / WebFetch（pkg.go.dev / github.com / raw.githubusercontent.com）: 外部ドキュメント参照

### モデル選択

デフォルトは `--model claude-opus-4-7`（深い設計レビュー）。
軽量運用したい場合は `--model claude-sonnet-4-6` に切り替える。

### action バージョン固定理由

`cd77b50d2b0808657f8e6774085c8bf54484351c`（v1.0.72）を使用。

- v1.0.101 以降は `mcp__github_inline_comment__create_inline_comment` が削除され、インラインコメント投稿ができない
- v1.0.72 では `id-token: write` 必須だが ANTHROPIC_API_KEY 直接認証と併用可能
- サプライチェーン対策として SHA pin（タグ参照禁止）

### allowedTools の設計思想

```
mcp__github_inline_comment__create_inline_comment  # インラインコメント
Bash(gh pr comment:*)                              # 新規トップレベルコメント
Bash(gh pr diff:*)                                 # 差分取得
Bash(gh pr view:*)                                 # PR情報取得
Bash(gh pr review --request-changes:*)             # P0/P1 時
Bash(gh pr review --comment:*)                     # P0/P1 無しの時
Bash(gh api repos/*/issues/*/comments:*)           # 既存コメント一覧取得
Bash(gh api --method PATCH repos/*/issues/comments/*:*)  # 既存コメント追記
Bash(find|cat|grep|ls|git diff|git log:*)          # コードベース探索
WebSearch                                          # 外部検索
WebFetch(domain:pkg.go.dev|github.com|raw.githubusercontent.com)  # ドキュメント取得
```

`gh pr review --approve` はあえて入れない（AIによる自動APPROVEは運用上避けるため）。

## デバッグのヒント

Claude が「何も投稿せずに完了」する場合のチェックリスト:

1. action バージョンが v1.0.72 か（SHA `cd77b50d...`）
2. `--allowedTools` に `mcp__github_inline_comment__create_inline_comment` が含まれているか
3. `permissions.pull-requests: write` と `permissions.id-token: write` があるか
4. prompt に「投稿ルール（必須）」セクションがあり、`gh pr comment` / `gh pr review` の具体的なコマンドが書かれているか
5. `--max-turns` が 30 以上あるか（15 だと投稿前にturn切れすることがある）
6. `issue_comment` トリガーの場合、`gh pr checkout` step が実行されているか（default branch のままだと diff が空になる）

Workflow が `Workflow validation failed` で失敗する場合:

- v1.0.72 のセキュリティ機能で PR branch と main の workflow 差分をチェックしている
- workflow 変更 PR 自身では動作しない（マージ後の別 PR で動作確認）
