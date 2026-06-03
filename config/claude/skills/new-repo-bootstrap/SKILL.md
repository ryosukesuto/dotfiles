---
name: new-repo-bootstrap
description: 新規GitHubリポジトリ作成直後のbootstrap作業を順次実行するorchestrator skill。用途言語化→CLAUDE.md/README.md整備→PRレビュー自動化(setup-ci-review)→チーム権限割り当て→branch protection→harness-audit→Renovate(setup-renovate)→運用サイクル登録の8ステップを対話的に進める。各ステップで[実行/スキップ/中断]を確認しながら、AIコーディングエージェントが自走できるハーネスを最低1時間で揃える。「新規リポセットアップ」「リポ立ち上げ」「new-repo-bootstrap」「repo bootstrap」「ハーネス整備」等で起動。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
---

# /new-repo-bootstrap - 新規リポジトリのbootstrap

`new-repo-checklist.md` の8ステップ全体を対話的に進める。各ステップに対応する sub-skill があれば invoke し、無ければ手順を提示してユーザー操作を待つ。

## 設計

このskillは「指揮者」であり、実体的な作業の大半はsub-skillに委譲する:

| ステップ | 担当 | 種類 |
|---|---|---|
| 1. 用途の言語化 | この skill (AskUserQuestion で収集) | inline |
| 2. CLAUDE.md / README.md 最低限整備 | この skill (`/init` 案内) | inline |
| 3. PR レビュー自動化 | `setup-ci-review` skill | invoke |
| 4. チーム権限割り当て | この skill (gh CLI) | inline |
| 5. branch protection | この skill (gh CLI) | inline |
| 6. 初回 harness-audit | `harness-audit` skill | invoke |
| 7. Renovate 導入 | `setup-renovate` skill | invoke |
| 8. 運用サイクル登録 | この skill (Linear 案内) | inline |

inline ステップでも詳細手順は `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md` を参照する。skillは「順序付け」「状態管理」「sub-skill間の引き継ぎ」に責務を絞る。

## 実行手順

### 0. 前提確認

```bash
REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
  || git remote get-url origin | sed -E 's#^git@github\.com:##; s#^https?://github\.com/##; s#\.git$##')
ORG="${REPO_NAME%%/*}"
echo "repo=$REPO_NAME org=$ORG"
```

`REPO_NAME` が取得できなければ「cwd がGitリポジトリでない」可能性。skillを中断してユーザーに対応を促す。

`ORG` は後続のチーム権限割り当てとorg固有設定（`SKILL.local.md` 群）のロード判定に使う。

### 1. 起動モード確認

ユーザーが「最初から全部」を希望しているか、特定ステップから再開したいかを `AskUserQuestion` で確認:

- `full`: ステップ1から順に全部
- `resume`: 特定ステップから再開（途中まで進んでいる場合）
- `cherry`: 特定の1-2ステップだけ実行（既存リポへの追加適用）

`resume` / `cherry` の場合は次にどのステップを実行するか選択させる。

### 2. ステップ別実行

各ステップの冒頭で `AskUserQuestion` を出して `[実行 / スキップ / 中断]` を確認する。
ユーザーが「中断」を選んだ時点でorchestrator全体を停止する。再開時はステップ1の起動モードで `resume` を選ぶ。

#### ステップ1: 用途の言語化

`AskUserQuestion` で以下を1回でまとめて収集（往復を増やさない）:
- リポジトリの目的（プロダクト機能 / 社内ツール / IaC / 自動化スクリプト / 等）
- 主要言語・フレームワーク
- 主要な運用者・オーナーチーム
- 重要な制約（本番データ取扱、公開リポ、機密性）

収集した結果は内部変数として保持し、後続ステップ（CLAUDE.md 雛形、setup-ci-review の `analyze=yes`、ステップ4のオーナーチーム判定）で再利用する。

#### ステップ2: CLAUDE.md / README.md 最低限整備

```bash
ls CLAUDE.md README.md 2>&1 | grep -v "No such"
```

存在しないものについて:
- CLAUDE.md: `/init` skill の起動を案内（自動起動はしない。生成物の品質をユーザーが確認すべきため）
- README.md: 最小構成 (プロジェクト名・1行説明・セットアップ・主要コマンド) の雛形を `Write` でドラフトし、ユーザーレビューを待つ

ステップ1で収集した「リポジトリの目的」「主要言語」を雛形に反映する。`/init` への引き継ぎはconversation contextに任せる（CLAUDE.mdが膨張しすぎないよう30-50行を目安に告知）。

#### ステップ3: PR レビュー自動化

`setup-ci-review` skill を invoke。

skill側で必要な質問（Tier / コンポーネント / analyze / model / greptileAutoReview）はsetup-ci-review内で行うため、orchestratorは起動するだけ。

完了後、setup-ci-reviewが生成したPRが draft で存在することを確認する手順を案内。マージ後の動作確認は「次PR」で行う旨も伝える（初回PRは workflow validation でスキップされる仕様）。

#### ステップ4: チーム権限割り当て

リポジトリ作成直後は作成者のみが Admin。チーム単位で権限を割り当てる。

詳細手順とorg固有のチーム命名規則は以下を参照:
- 公開ガイドライン: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md` セクション4
- org固有ルール: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/<org>-repo-permissions.local.md`（存在すれば）

`AskUserQuestion` でオーナーチーム名（`<team>`）を確認。`SKILL.local.md` 相当のorg固有rule が存在すれば既知チーム一覧を選択肢として提示する。

チーム名確定後、teams の存在チェック → 権限付与の順で実行:

```bash
TEAM=<選択結果>

# teams の存在チェック（適用前に確認することで未定義チームへの誤適用を防ぐ）
gh api /orgs/$ORG/teams/$TEAM-admin -q '.slug' 2>&1 | head -1
gh api /orgs/$ORG/teams/$TEAM -q '.slug' 2>&1 | head -1
gh api /orgs/$ORG/teams/$TEAM-guest -q '.slug' 2>&1 | head -1

# 適用
gh api -X PUT /orgs/$ORG/teams/$TEAM-admin/repos/$ORG/$REPO -f permission=admin
gh api -X PUT /orgs/$ORG/teams/$TEAM/repos/$ORG/$REPO -f permission=push
```

`-guest` は `AskUserQuestion` で必要可否を確認してから適用（業務委託・ヘルプ要員がいる場合のみ）。

適用後の確認:

```bash
gh api /repos/$ORG/$REPO/teams -q '.[] | "\(.slug)\t\(.permission)"'
```

#### ステップ5: branch protection

main / master の保護を gh CLI で適用。AI Approve 単独でマージできない状態を作る。

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)

gh api -X PUT /repos/$ORG/$REPO/branches/$DEFAULT_BRANCH/protection \
  -f required_pull_request_reviews[required_approving_review_count]=2 \
  -f required_pull_request_reviews[dismiss_stale_reviews]=true \
  -F enforce_admins=false \
  -F allow_force_pushes=false \
  -F allow_deletions=false \
  -F required_status_checks=null \
  -F restrictions=null
```

設定値の理由は `new-repo-checklist.md` セクション5 を参照。`enforce_admins=false` は Admin が緊急時に bypass できる余地を残すため。

#### ステップ6: harness-audit

`harness-audit` skill を invoke。初回ベースラインを `docs/audit-history/{YYYY-MM-DD}.md` に出力する。

初回は「未構成だらけ（スコア 0-1 多数）」になるのが正常。Quick Wins を提示するだけで、修正適用は別セッションで行う方針を伝える（orchestratorの責務外）。

#### ステップ7: Renovate 導入

`setup-renovate` skill を invoke。

skill側で `renovate.json` 配置、Dependabot 削除（存在すれば）、syntax 検証、PR 作成までを実施する。orchestratorは起動するだけ。

#### ステップ8: 完了後の運用サイクル登録

Linear / Kibela / カレンダーへの登録案内のみ（自動化しない）:

- 週次: 自分宛て PR レビュー消化
- 月次: 未適用リポへの setup-ci-review 適用検討
- 月次: Renovate PR の処理（破壊的変更の確認）
- 四半期: harness-audit 再実行、スコア推移確認
- 四半期: ハーネスルール台帳の棚卸し

このステップでは新規実行はせず、運用ルールの存在をユーザーにリマインドする。

### 3. 完了サマリ

全ステップ実行後、以下を出力:

- 実行したステップ一覧（実行/スキップ/失敗の別）
- 生成したPR / Issue のリンク
- 次のアクション（branch protection で待機中のPRをマージ、Renovate App install 状態確認など）
- 想定所要時間（残りタスクがあれば）

## Gotchas

- このskillはorchestrator。実体的な実装ロジック（テンプレート展開・syntax検証・lint）はsub-skillに任せる。ここに重複させない（責務肥大化を防ぐため）
- 各ステップは独立して再実行可能。中断後の再開でも前ステップの成果物に依存しない設計にする（CLAUDE.mdが既にあればステップ2をスキップ、`renovate.json`が既にあればステップ7をスキップ、等）
- ステップ間で内部変数（`REPO_NAME`, `ORG`, ステップ1の収集結果）を引き継ぐが、sub-skill起動時にこれらを引数で渡せない場合は明示的に「sub-skillに以下を伝える」と案内する
- `gh api -X PUT /repos/.../branches/.../protection` は値の指定形式が特殊（`-f` と `-F` の使い分け、ネストフィールドの書き方）。一度誤適用するとprotection ruleがおかしくなりやすい。dry-runの代わりに `gh api /repos/$ORG/$REPO/branches/$DEFAULT_BRANCH/protection` で現状確認してから適用する
- チーム権限割り当て前にbranch protection を入れると、admin team不在のリポでprotection更新が詰まる可能性。ステップ4 → 5 の順序を必ず守る
- orchestratorが sub-skill を invoke する経路は「自然言語で `/<skill-name>` を起動する」形になる。skill間の引数渡しはconversation contextで行われるため、orchestratorはsub-skill起動前に必要なコンテキストを `log` 的に明示する（例: 「`/setup-ci-review` を起動する。Tierは2想定」）
- 初回PR は Claude Code Action の workflow validation でスキップされる。setup-ci-review完了後に「次PRで動作確認」と必ず案内する。ここを伝え忘れると「動かない」と誤判定される
- ステップ8は自動化しない。Linear 起票やカレンダー登録はユーザーの判断・他システムへの書き込みなので、orchestrator が勝手にやらない

## 関連

- 全体ガイド: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md`
- sub-skills:
  - `/setup-ci-review` (ステップ3)
  - `/harness-audit` (ステップ6)
  - `/setup-renovate` (ステップ7)
  - `/init` (ステップ2、CLAUDE.md 初期化)
- org固有ルール:
  - `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/winticket-repo-permissions.local.md`
  - `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/winticket-dep-updates.local.md`
