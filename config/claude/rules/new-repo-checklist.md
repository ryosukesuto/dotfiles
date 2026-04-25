# 新規リポジトリ立ち上げチェックリスト

新しい GitHub リポジトリを作ったあと、AI コーディングエージェントが自走できる土壌（ハーネス）を最低限整えるための手順。チェック順は「依存関係が浅い → 深い」の順。

このチェックリストは個人運用を想定して書いているが、いずれチームに展開して Kibela に転載する。そのため個人ツール名（`/setup-ci-review` 等の slash command）は生で書かず、目的ベースで記述する。

## 前提

- リポジトリ作成済み（`gh repo create` または GitHub UI）
- `main` ブランチが存在する
- Claude Code Action / Greptile / Renovate を導入する org であること
- ローカルに `ghq get` でクローン済み

## 適用範囲

- 適用する: プロダクト・ツール・IaC・自動化スクリプトなど、PR レビューが意味を持つリポ
- 適用しない: 個人の使い捨てメモ、experimental / fork、外部公開しない polyglot scratch
- 部分適用: 公開 OSS（Renovate と CI のみ、Greptile / Claude Code Action は未連携の場合あり）

## 着手順

```
1. 用途の言語化（5分）
2. CLAUDE.md / README.md 最低限整備（15-30分）
3. PR レビュー自動化セットアップ（10-15分）
4. branch protection 設定（5分）
5. 初回 harness-audit でベースライン取得（10分）
6. 依存更新自動化（Renovate）導入（5分）
7. 完了後の運用サイクル登録（任意）
```

合計 1 時間程度を目安に進める。完璧を目指さず、最低限が揃った段階で初回 PR を出して動作確認する。

## 1. 用途の言語化

リポジトリの目的・主要言語・運用主体を 1-2 文で言語化する。CLAUDE.md / README.md / setup-ci-review の `analyze=yes` 等、後段すべての判断がここに依存する。

最低限決めること:

- 何のためのリポジトリか（プロダクト機能・社内ツール・IaC・等）
- 主要言語・フレームワーク
- 主要な運用者（誰がコミットし誰がレビューするか）
- 重要な制約（例: 本番データを扱う、公開リポ、契約上の機密）

## 2. CLAUDE.md / README.md 最低限整備

### CLAUDE.md

Claude Code のような AI エージェント向けに、プロジェクト固有の文脈を最低限渡すファイル。

最初は 30-50 行で十分。盛り込みすぎると context window を消費するだけで効果が薄い。

含めるべき項目:

- リポジトリ概要（1-3 文）
- アーキテクチャ概要（依存方向・レイヤー分割の意図）
- 重要な制約・規約（コミット時の前提、命名規則、プルリクの粒度等）
- セキュリティ上の注意点（あれば）
- 主要なコマンド（テスト、ビルド、lint）

含めないもの:

- ファイル一覧（`find` で取れるので不要）
- API ドキュメント（コード自体や別ドキュメントに任せる）
- 個人作業ログ（個人ノートに分離する）

### README.md

人間向け。新メンバーが最初に読むことを想定。

最低限の構成:

1. プロジェクト名・1 行説明
2. 何をするものか（3-5 行）
3. セットアップ手順
4. 主要なコマンド
5. デプロイ・運用の概要（プロダクトリポなら）

`/init` 系コマンドや AI でテンプレ生成する場合、生成物をそのままコミットしない。「人間が初見で理解できるか」を 1 度自分で読んで確認する。

## 3. PR レビュー自動化セットアップ

Claude Code Action（必須）と Greptile（重要リポのみ）を導入する。具体的には対象リポの `.github/workflows/claude-review.yml` と `.claude/skills/claude-code-review/SKILL.md` を配置する。

判断ポイント:

| 項目 | 判断 |
|---|---|
| Claude Code Action | 全対象リポで有効化 |
| Greptile auto-review on commits（`triggerOnUpdates: true`） | 「プロダクトに重要で追加課金を払う価値がある」リポのみ true。それ以外は false（PR 作成時の初回レビューは走るが push 後の再レビューは手動） |
| Checkov | IaC リポのみ（Terraform 等） |

Claude Code GitHub App のインストール:

- App インストールは workflow 配置と別に必要。`https://github.com/apps/claude` から対象リポに個別インストールしないと、`401 Unauthorized - Claude Code is not installed on this repository` で 3 回リトライ失敗する
- workflow を入れた段階でこの問題が出るので、初回 PR 動作確認時に「App 入れたか？」を最初にチェック

Secret 設定:

- `ANTHROPIC_API_KEY` を Settings > Secrets > Actions に登録
- 個人 API key を入れない。org / team の共有 key を使う

設定後の動作確認:

- 初回 PR では Claude Code Action が `Workflow validation failed` でスキップされる（セキュリティ機構）。動作確認は **マージ後の次の PR** で行う

## 4. branch protection / Required Reviews

main / master ブランチを保護する。AI Approve だけでマージできる状態を作らない。

最低限の設定:

- Require a pull request before merging: ON
- Required approvals: **2 以上**（human + AI の 2 Approve 制を推奨）
  - Claude のコンテキスト補正ルールにより「文脈依存 P0 + PR 本文の申告」で AI Approve に至る経路がある。AI 単独マージを防ぐ
- Require status checks to pass before merging: ON
  - Required Check に Claude Code review / Greptile を入れない（block するとマージ不能になる）
- Restrict who can push to matching branches: ON（必要に応じて）
- Allow force pushes / Allow deletions: OFF

## 5. 初回 harness-audit でベースライン取得

ハーネス監査を 1 度走らせて、6 カテゴリ（コンテキスト・フィードバック・アーキテクチャ・エントロピー・計画と実行の分離・ガードレール）の現状スコアを取る。

成果物:

- `docs/audit-history/{YYYY-MM-DD}.md` にレポート保存（git 管理）
- `<!-- audit-meta: {...} -->` HTML コメントで機械可読なスコアを埋め込む
- 以降の監査は同ディレクトリに追記され、`bin/harness-audit-history` で推移を見られる

初回は「未構成だらけ（スコア 0-1 多数）」になる。これは正常。Quick Wins から段階的に対応する。

## 6. 依存更新自動化（Renovate）

WinTicket org では Renovate 統一。Dependabot は使わない（org 横断で混在するとセキュリティアラートの追跡系統と PR レビュー運用が割れる）。

最小構成:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:best-practices",
    ":dependencyDashboard",
    ":semanticCommitsDisabled"
  ],
  "timezone": "Asia/Tokyo",
  "schedule": ["* 0-2 * * 1"],
  "prHourlyLimit": 2,
  "prConcurrentLimit": 5,
  "labels": ["dependencies"],
  "commitMessagePrefix": "chore(deps):",
  "minimumReleaseAge": "7 days",
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"],
    "prPriority": 10,
    "minimumReleaseAge": "0 days"
  },
  "packageRules": [
    {
      "description": "GitHub Actions - automerge minor/patch/digest",
      "matchManagers": ["github-actions"],
      "groupName": "github-actions",
      "automerge": true,
      "automergeType": "pr",
      "matchUpdateTypes": ["minor", "patch", "digest"]
    }
  ]
}
```

org レベルで Renovate App が install されていない場合は org admin に依頼。設定ファイル追加だけでは動かない。

PR レビュー自動化の `allowed_bots` には `dependabot[bot]` と並べて `renovate[bot]` を必ず入れる（依存更新 PR にもレビューが走る）。

## 7. 完了後の運用サイクル

月次・四半期で回すルーチンを 1 度決めておく。後付けは忘れる。

| 周期 | アクション | 自動化可否 |
|---|---|---|
| 週次 | 自分宛て PR レビュー消化 | 半自動（Linear / pr inbox） |
| 月次 | 未適用リポへの setup-ci-review 適用検討 | 半自動（月次レビュー時に linear-triage Phase 7 で起票） |
| 月次 | Renovate PR の処理（破壊的変更の確認） | 自動レビュー + 手動マージ |
| 四半期 | harness-audit 再実行、スコア推移確認 | 半自動（Linear リマインダ） |

`bin/claude-review-coverage` で未適用リポの一覧、`bin/harness-audit-history` でスコア推移を取れる。

## 整備の優先順位

時間が取れない時は以下の順で削る。

1. **必須**: PR レビュー自動化、branch protection、Renovate
2. **重要**: CLAUDE.md / README.md 整備、初回 harness-audit
3. **任意**: 用途言語化の文書化（頭の中で済ませてよい）、運用サイクルの明文化

セキュリティが弱いまま運用を始めない。1 と 2 の必須項目は新規 PR を出す前に完了させる。

## このチェックリストを更新する場合

実際に新規リポを立ち上げて困った点・抜けていた点があれば、ここに追記する。チームに展開する際は Kibela に転載し、リポ固有のリンク（例: org の Renovate App 申請手順）を実情報で埋める。

## 関連リソース

- リポジトリの監査スクリプト: `bin/claude-review-coverage`、`bin/harness-audit-history`
- Renovate org 方針: `~/dotfiles-private/config/claude/rules/<topic>.local.md`（org 内）
- harness-audit カテゴリ詳細: `~/.claude/skills/harness-audit/checklist.md`
