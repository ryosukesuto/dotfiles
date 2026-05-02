---
name: infra-workflow
description: Terraform・AWS CLI作業時のガイドライン。「Terraform」「terraform plan」「AWS CLI」「IaC」等で起動。
user-invocable: false
paths:
  - "**/*.tf"
  - "**/terragrunt.hcl"
  - "**/.envrc"
allowed-tools:
  - Bash(terraform:*)
  - Bash(aws:*)
  - Read
  - Glob
---

# インフラ作業ワークフロー

## Terraform作業時
1. 変更ファイル確認 → 影響範囲の予測と文書化
2. variables.tf更新 → README.md更新確認
3. IAM変更 → セキュリティレビュー必須
4. PR作成前 → mainブランチ（デフォルトブランチ）でローカルと同期
5. PR作成後 → CI/CDのterraform planで結果確認

## destroy / IAM 変更を含む PR の追加チェック

`google_*_iam_member` (non-authoritative) や `google_logging_project_sink` を destroy する場合、共有所有問題で他 stack を巻き込む事故が起きやすい。詳細手順とチェックリストは `~/.claude/rules/terraform-iam-destroy.md` を参照する（global rule として autoload 済み）。

## AWS CLI作業時
1. フェデレーションポータルにログイン
2. 対象AWSアカウントの `...` → `一時的な認証情報を取得`
3. `環境変数の設定` の `コピー` をクリック
4. ターミナルで貼り付けて実行（環境変数がセットされる）
5. AWS CLIコマンドを実行（プロファイル指定不要）

注意: 一時的な認証情報のため、有効期限切れ時は再取得が必要

## Gotchas

(運用しながら追記)
