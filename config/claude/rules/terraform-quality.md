---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
---

# Terraform コード品質ルール

`.tf` / `.tfvars` を書く/レビューするときに守る最低限のガイドライン。terraform-best-practices.com と HashiCorp recommended practices から実害につながりやすいものを抜粋している。

destroy 時の共有 IAM binding 巻き込み事故は別ファイル (`~/.claude/rules/terraform-iam-destroy.md`) を参照。

## terraform fmt 必須

`terraform fmt` の出力と一致しないコードはマージ禁止。ローカルでは PostToolUse hook (`bin/claude-terraform-after-edit`) が違反時に `exit 2` で Claude に修正を促す。

```bash
terraform fmt -check -diff   # 差分確認
terraform fmt -recursive     # 配下を全て整形
```

## ファイル構成

1 ファイルに詰め込まない。標準分割:

| ファイル | 内容 |
|---|---|
| `main.tf` | 主要なリソース定義 |
| `variables.tf` | `variable` 宣言 |
| `outputs.tf` | `output` 宣言 |
| `versions.tf` | `terraform` / `required_providers` ブロック |
| `locals.tf` | 計算済み値 |
| `providers.tf` | provider configuration |

リソース数が多いときは責務単位で `network.tf` `iam.tf` などに分割する。

## 命名

- リソース名・変数名: `snake_case` (camelCase / kebab-case 禁止)
- リソース名にリソース type を繰り返さない: `aws_instance.web` (✓) / `aws_instance.web_instance` (✗)
- モジュール内に同種リソースが 1 つしかないなら `main` を使う: `resource "aws_vpc" "main"`
- 複数の同種リソースは `for_each` で意味のあるキーを使う

## バージョン固定

`versions.tf` で terraform 本体と provider の version を必ず固定する。

```hcl
terraform {
  required_version = "~> 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
  }
}
```

- `>=` だけ書かない (新版で破壊的変更を踏む)
- lock file (`.terraform.lock.hcl`) は必ずコミット

## 変数定義

```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Only t3 family is allowed."
  }
}
```

- `description` 必須
- `type` を必ず指定
- 機密変数は `sensitive = true`
- バリデーション可能なら `validation` ブロックで前提を強制

## 出力定義

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
```

- `description` 必須
- 機密値は `sensitive = true` (出力先のログに残らない)

## State 管理

- remote backend (S3 + DynamoDB lock / GCS / Terraform Cloud) を必ず使う
- ローカル state はチーム開発で禁止
- `*.tfstate*` は `.gitignore`、コミット禁止 (Read 制限済み)
- state ファイルには平文の secret が入る。S3 SSE / GCS CMEK で暗号化する

## モジュール設計

- 1 モジュール 1 責務 (VPC / EKS / RDS など)
- module 内で provider を宣言しない (caller 側で渡す)
- `count` よりも `for_each` を優先する。`count` は削除時に index ズレで他リソースが破壊される

```hcl
# Bad: count で順序依存
resource "aws_iam_user" "u" {
  count = length(var.users)
  name  = var.users[count.index]
}

# Good: for_each で名前を key に
resource "aws_iam_user" "u" {
  for_each = toset(var.users)
  name     = each.value
}
```

## 安全性

- secret をコードに埋めない。`var.password` も `default` を持たない
- `lifecycle { prevent_destroy = true }` を重要リソース (本番 RDS, ELB, KMS key 等) に付ける
- `lifecycle.ignore_changes` は範囲を最小にする。`all` は避ける
- IAM binding の destroy は共有所有問題に注意 → `terraform-iam-destroy.md` 参照
- `provider` の `default_tags` で `Owner` / `Environment` / `ManagedBy = terraform` を強制する

## よくある指摘の回避パターン

### locals で複雑な計算を切り出す

```hcl
# Bad: resource 引数の中で長い式
resource "aws_security_group_rule" "x" {
  cidr_blocks = [for c in var.cidrs : c if startswith(c, "10.")]
}

# Good: locals に名前を付ける
locals {
  internal_cidrs = [for c in var.cidrs : c if startswith(c, "10.")]
}

resource "aws_security_group_rule" "x" {
  cidr_blocks = local.internal_cidrs
}
```

### depends_on は最後の手段

明示的な参照 (`resource.attribute`) で依存関係が自動解決されるなら `depends_on` を使わない。参照で表現できない依存 (副作用順序等) だけに限定する。

### dynamic block の濫用を避ける

`dynamic` は本当に動的に block 数が変わる場合のみ。静的に書けるなら書く。読みやすさが優先。

## 例外と判断軸

- 既存モジュールの命名違反は専用 PR でまとめて直す
- `# tflint-ignore:` / `# checkov:skip=` 等の suppress は理由コメント必須
- 1 ファイル完結の小さなスクリプト (10 行以下、出力なし変数なし) なら `variables.tf` / `outputs.tf` 不要

## 関連

- destroy 時の共有 IAM binding 巻き込み: `~/.claude/rules/terraform-iam-destroy.md`
- shell の同等ルール: `~/.claude/rules/shell-quality.md`
- go の同等ルール: `~/.claude/rules/go-quality.md`
- terraform best practices: https://www.terraform-best-practices.com/
- HashiCorp recommended practices: https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices
