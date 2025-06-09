# CLAUDE.md - Claude Desktop Configuration

このファイルは、Claude Desktopで使用する個人設定やプロジェクト固有の情報を管理します。

## 個人開発環境

### 主要技術スタック
- **言語**: Go, Python (Rye), TypeScript
- **クラウド**: AWS (SSM, S3), GCP (BigQuery, Cloud Run, GCE)
- **インフラ**: Terraform (v1.5.1, v1.10.5), Kubernetes, Docker
- **データ基盤**: DBT, BigQuery, Firestore
- **CI/CD**: GitHub Actions (Workload Identity)

### プロジェクト構成
```
~/src/                              # ghqで管理されるリポジトリのルート
├── github.com/
│   ├── ryosukesuto/               # 個人リポジトリ
│   │   ├── dotfiles/              # 開発環境設定
│   │   └── obsidian-notes/        # Obsidian vault
│   └── team-youtrust/             # 組織リポジトリ
│       ├── infra-gcp/             # GCPインフラ (GitOps)
│       ├── infra-gcp-dwh/         # データウェアハウス
│       └── youtrust-timeline-recommendation/  # レコメンドエンジン
```

## よく使うコマンド

### AWS踏み台サーバー接続
```bash
# 環境別接続
bastion-prod      # 本番環境
bastion-dev       # 開発環境
bastion-staging   # ステージング環境
bastion-select    # インスタンス選択

# MySQL接続（踏み台サーバー内）
mysql -u dbuser_r -p -h read-replica.production.db.local -D youtrust_webapp_production
```

### Terraform開発
```bash
# 必須: フォーマット（コミット前に必ず実行）
terraform fmt -recursive

# ローカル検証
terraform validate

# GitOpsプロジェクトでは terraform plan/apply は使わない
# CI/CDで自動実行される
```

### Python (Rye) 開発
```bash
rye sync                    # 依存関係インストール
rye run python -m src.app   # アプリケーション実行
pytest                      # テスト実行
```

### ディレクトリ移動
```bash
# Ctrl+] でghq管理下のリポジトリを選択
# または直接移動
cd ~/src/github.com/team-youtrust/infra-gcp
```

## プロジェクト別ワークフロー

### infra-gcp (GitOps)
1. **ブランチ戦略**: feature → sandbox → main → production
2. **デフォルトブランチ**: sandbox（mainではない！）
3. **マージ方法**: 必ずSquash Merge
4. **デプロイ**: PR merge時に自動実行

### infra-gcp-dwh
1. **デフォルトブランチ**: sandbox
2. **環境**: production (youtrust-dwh), sandbox (youtrust-sandbox-dwh)
3. **データフロー**: AWS S3 → GCS → BigQuery → Metabase

### timeline-recommendation
1. **バッチ処理**: 5つのステップを順次実行
2. **A/Bテスト**: CONFIG_FILE環境変数で切り替え
3. **デプロイ**: utils/配下のスクリプト使用

## 環境別設定

### BigQuery
- **本番**: youtrust-dwh
- **サンドボックス**: youtrust-sandbox-dwh
- **リージョン**: asia-northeast1

### Terraform バージョン
- infra-gcp: 1.10.5
- infra-gcp-dwh: 1.5.1

### 認証
```bash
# GCP認証
gcloud auth application-default login

# AWS SSO
aws sso login --profile prod
```

## セキュリティ注意事項
- パスワードや秘密鍵は記載しない
- 環境固有の情報は `.env.local` で管理
- GitOpsプロジェクトではローカルでplan/applyしない