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

## destroy完了は実機で確認する

apply の exit code が green でも、一部リソースの destroy がタイムアウトや依存関係の順序待ちで失敗し、実リソースが残存したまま気づかないことがある。ECS Service が `DRAINING` 状態からの削除待ちで 20 分タイムアウトし、依存する Capacity Provider・Cluster の destroy がまとめて失敗するが、後続の apply（他リソースのみ変更）は無関係に成功して green に見える、という事例がある。

destroy を含む Terraform PR・Linear Issue では、完了条件に次を明示的な1項目として含める。

- destroy 対象がある場合、apply 完了後に `aws ec2 describe-instances` / `aws ecs describe-clusters` 等の CLI で対象リソースが実際に存在しないことを確認する
- コード上・Linear の記述が完了に見えることと、実機の状態が一致しているかは別に確認する

2026-07-27、CyberAgentCard/processing-infrastructure PFIF-123 で確認。旧 tier1/tier2 レイヤーの整理 Issue が Done 化された後、tier2 側の destroy が ECS Service の DRAINING タイムアウトで一部失敗していたことが判明。ECS Cluster・Capacity Provider・ASG・EC2 3台・IAM ロール3件の計12リソースが AWS 上に残存していた。AWS CLI での突合で発覚し、apply を再トリガーして是正した。

## AWS CLI作業時
1. フェデレーションポータルにログイン
2. 対象AWSアカウントの `...` → `一時的な認証情報を取得`
3. `環境変数の設定` の `コピー` をクリック
4. ターミナルで貼り付けて実行（環境変数がセットされる）
5. AWS CLIコマンドを実行（プロファイル指定不要）

注意: 一時的な認証情報のため、有効期限切れ時は再取得が必要

## Gotchas

(運用しながら追記)
