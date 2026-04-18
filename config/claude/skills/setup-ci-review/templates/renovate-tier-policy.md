# Renovate Tier Policy

リスクに応じた5段階のTier分類でautomerge範囲を管理する。

## Tier定義

### T0: 即時automerge

対象: devDeps、型定義、Lint/Formatter、GitHub Actions minor/patch/digest
条件: CI全通過
承認: 不要（Renovate自身がマージ）

### T1: 老化 + automerge

対象: Docker base image patch、非破壊的なruntime deps patch
条件: CI全通過、minimumReleaseAge: 3-7 days、Terraform plan不要
承認: 不要（Renovate自身がマージ）
補助統制: 週次の発見統制（マージ済みPR一覧の後追いレビュー）

### T2: Bot check + 人間1 approve

対象: Terraform provider minor、Go/Nodeランタイム minor、DBドライバ minor
条件: Terraform planクリーン、CI全通過、minimumReleaseAge: 7 days
承認: CODEOWNERSから1名

### T3: Bot check + 人間1 approve + スモークテスト

対象: major bump全般、ORMライブラリ、Terraform provider major
条件: stgでの動作確認、ロールバック手順の明記
承認: CODEOWNERSから1名 + 動作確認記録

### T4: maker-checker（人間2 approve）

対象: 決済・認証・残高・KYC関連ライブラリ、Kubernetes manifest major
条件: stg検証、リリース計画、ロールバック手順
承認: 起案者以外の2名（J-SOX maker-checker相当）

## 予防統制

- CI全通過を必須（unit test、lint、vulnerability scan）
- minimumReleaseAgeによる老化期間（最低3日）
- pinDigestsによる再現性担保
- Security系は常時prPriority: 10で優先処理

## 発見統制

- 週次でautomergeされたRenovate PR一覧をSlack等に自動投稿
- 四半期ごとにRenovate起因の障害の有無をレビュー
- audit trail: GitHub ActionsログとPRのマージ記録を保持

## 適用リポジトリ

- リポジトリ: {{REPO_NAME}}
- CODEOWNERS: 各パスのオーナーが T2〜T4 のapproverを担う
- 最終更新: {{DATE}}

## J-SOX整合性チェックリスト

- [ ] opsリポジトリが財務報告関連システムのscope内か確認
- [ ] scope内の場合、automerge運用が変更管理統制のルールと矛盾しないか確認
- [ ] 発見統制の記録場所を定義（Linear / Slack履歴 / Notion）
- [ ] automergeされたPRの一覧と判断理由を監査対応時に提示できる形式を確保
