---
name: setup-renovate
description: GitHubリポジトリにRenovate（依存更新自動化）を導入する。baseline `renovate.json` を配置し、既存の `dependabot.yml` 削除、syntax検証、PR作成までを対話的に支援する。Renovate App の install 状態は人手依頼の手順を案内する。「Renovate導入」「renovate.json追加」「依存更新自動化」「Dependabotから移行」「setup-renovate」等で起動。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Bash(pnpm:*)
  - Bash(npx:*)
  - Bash(trash:*)
---

# /setup-renovate - Renovate 導入

Renovateの`renovate.json`をbaselineテンプレから配置し、Dependabotとの混在を解消し、syntax検証付きでPR化する。

新規リポ立ち上げ時の `new-repo-checklist.md` セクション7に対応。`setup-ci-review` とは独立して動作するが、両方を順次実行する場合は将来の `new-repo-bootstrap` orchestrator から呼ばれる。

## 実行手順

### 1. リポジトリ確認

```bash
REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
  || git remote get-url origin | sed -E 's#^git@github\.com:##; s#^https?://github\.com/##; s#\.git$##')
ORG="${REPO_NAME%%/*}"
echo "repo=$REPO_NAME org=$ORG"
```

orgを判定するのは、org固有のRenovate設定（`SKILL.local.md`）を切り替える起点になるため。

### 2. 既存ファイルの確認

以下のいずれかが既に存在するかチェック:

```bash
ls -la renovate.json .renovaterc.json .renovaterc .github/renovate.json 2>&1 | grep -v "No such"
ls -la .github/dependabot.yml .github/dependabot.yaml 2>&1 | grep -v "No such"
```

判定:
- `renovate.json` が既にある → 上書きしない。差分のみ `AskUserQuestion` で確認、必要なら `Edit` で部分修正
- `dependabot.yml` がある → ステップ4で削除を提案
- 両方ない → 新規導入として進める

### 3. org固有設定のロード（任意）

`${CLAUDE_SKILL_DIR}/SKILL.local.md` が存在すれば `Read` する。orgごとの:
- baseline からの差分（追加 packageRules、`extends` プリセット）
- bot 連携ポリシー（`allowed_bots` の扱いなど）
- 関連 Linear Issue / Kibela リンク

を抜き出して、後段の `renovate.json` 生成に反映する。

org判定に該当しない場合（個人リポ等）は baseline のみで進める。

### 4. Dependabot からの移行（該当時のみ）

`.github/dependabot.yml` または `.github/dependabot.yaml` が存在する場合は、Renovate と並走させると PR が二重に飛ぶ。`AskUserQuestion` で削除可否を確認してから `trash` で削除する。

```bash
DEPENDABOT_FILE=$(ls .github/dependabot.yml .github/dependabot.yaml 2>/dev/null | head -1)
[[ -n "$DEPENDABOT_FILE" ]] && trash "$DEPENDABOT_FILE"
```

拡張子は `.yml` / `.yaml` の両方を実在チェックする。決め打ちすると検出/削除/git add で取りこぼす（実リポで `.yaml` 拡張子採用ケースあり）。`DEPENDABOT_FILE` 変数は後続の `git add` でも使い回す。

理由をPR本文に明記する（「Renovate導入に伴いDependabotを停止」）。

### 5. `renovate.json` の生成

`${CLAUDE_SKILL_DIR}/templates/renovate.json` を `Read` してbaselineを取得。org固有調整を上乗せして、リポジトリルートの `renovate.json` に `Write` する。

配置先の選択肢:
- `renovate.json`（ルート）: 既定。最も検出されやすい
- `.github/renovate.json`: `.github/` 配下に集約したい場合
- `.renovaterc.json`: 隠しファイル運用のリポ

特別な理由がなければルートの `renovate.json` を使う。判定が分かれる場合は `AskUserQuestion` で確認。

### 6. syntax 検証

`renovate-config-validator` で構文チェック。失敗したら Write を取り消して原因を提示する。

```bash
pnpm dlx --package renovate -- renovate-config-validator renovate.json
```

`pnpm dlx` を使うのは、グローバルインストールを避けつつ非対話で実行できるため（CLAUDE.md のサプライチェーン方針に整合）。

検証で出る代表的な warning:
- `prPriority` を `vulnerabilityAlerts` 直下に書くと warning → baseline で対応済（`matchUpdateTypes: ["security"]` の packageRule に分離）
- `matchPackageNames` 等のマッチャーを持たない packageRule → 全パッケージに適用されて意図せず override が起きる

### 7. コミット + PR 作成

ブランチ名は以下の優先順:

1. Linear Issue がある: `gitBranchName`（`<assignee-handle>/<issue-id>`）
2. Dependabot からの移行: `chore/migrate-to-renovate`（実態を表す名前。実リポでの移行 PR で採用）
3. 新規導入のみ: `chore/setup-renovate`

```bash
git checkout -b <branch>
git add renovate.json
[[ -n "$DEPENDABOT_FILE" ]] && git add "$DEPENDABOT_FILE"  # 削除した場合のみ
git commit -m "chore(deps): introduce Renovate"
gh pr create --draft --title "chore(deps): introduce Renovate and remove Dependabot" --body "$(cat <<'EOF'
## 概要

<org名> の依存更新自動化方針 (Renovate 統一) に合流する。

- `renovate.json` を追加
- 既存の `.github/dependabot.yaml` を削除 (並走による PR 二重投稿の防止)

## 主な設定

- `extends`: `config:best-practices`, `:dependencyDashboard`, `:semanticCommitsDisabled`
- スケジュール: 毎週月曜 0-2時 JST
- `minimumReleaseAge`: 7日 (脆弱性アラートは即時)
- GitHub Actions の minor/patch/digest は automerge
- `prHourlyLimit: 2` / `prConcurrentLimit: 5`
- `commitMessagePrefix: chore(deps):`

## 動作確認

- `renovate-config-validator renovate.json` で構文検証通過

## 補足

- org レベルで Renovate App が install 済みであれば、マージ後に Onboarding PR / Dependency Dashboard Issue が自動起票される
- Dependabot で開いている PR があれば、Renovate からの後続 PR を待ってから手動 close

## 参考

- 先行事例: `<org>/<repo>` (最小構成), `<org>/<repo>` (フル機能)

## Linear

Refs <Issue ID があれば>
EOF
)"
```

PR body は実際の移行 PR の本文構造を雛形にしている。「主な設定」「補足」「参考（先行事例）」は他リポへ展開するときも再利用価値が高い。先行事例リンクは `SKILL.local.md` の「リファレンス設定」表から拾う。

draft の使い分け:
- 既定: `--draft` で作る（変更が大きい・対話的に詰めるべき設定が残っている場合）
- 例外: Dependabot → Renovate の単純な migration で baseline ほぼそのままなら `--draft` 抜きで作って即マージ可

Linear Issue 紐づけ: 1 PR で Issue の Acceptance Criteria を満たすなら `Closes PF-XXXX`、満たさない / 部分対応なら `Refs PF-XXXX`。

### 8. org Renovate App の install 状態案内

設定ファイルだけ置いても、org レベルで Renovate App が install されていないと動かない。最後にユーザーに以下を案内する:

- 確認: https://github.com/organizations/<ORG>/settings/installations で Renovate を検索
- 未 install の場合: org admin に install 依頼（個人ユーザーが直接 install できない org がほとんど）
- install 済みの場合: PR マージ後 1-2 時間以内に Onboarding PR / Dependency Dashboard Issue が起票される

## Gotchas

- `vulnerabilityAlerts` ブロックに `prPriority` を直書きすると Renovate が warning を出す。baseline では `packageRules` の `matchUpdateTypes: ["security"]` entry に分離済。手動で `vulnerabilityAlerts` を編集するときは戻さないよう注意
- `matchPackageNames` などのマッチャーを持たない `packageRules` entry は全パッケージに適用される。`minimumReleaseAge` などの上書きで事故るため、必ず matcher を1つは付ける
- 既存リポで `renovate.json` がある場合の上書きは破壊的。差分マージするか、ユーザーに既存内容の意図を確認してから手を入れる。skill 側で自動マージしない
- `allowed_bots` に `dependabot[bot]` や `renovate[bot]` を入れない。Wiz custom rule で Confused Deputy 攻撃ベクトルとして検出される。詳細は `SKILL.local.md`
- 個人リポ（`ryosukesuto/*`）では org Renovate App の install 確認は不要。設定ファイル単体で動く
- `pnpm dlx --package renovate -- renovate-config-validator` は初回実行で renovate パッケージ全体をDLするため数分かかる。タイムアウト目安は 300 秒
- WinTicket org では Dependabot ではなく Renovate に統一する方針。新規リポでも Dependabot を選ばない。詳細は `SKILL.local.md`
- Dependabot ファイルの拡張子は `.yml` と `.yaml` の両方が存在する。section 4 で検出した `DEPENDABOT_FILE` 変数を使い回し、決め打ちで `dependabot.yml` と書かない（実リポで `.yaml` 拡張子採用ケースあり）

## 関連

- 公開 baseline: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md` セクション7
- 新規リポ立ち上げ全体: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md`
- 上位orchestrator: `/new-repo-bootstrap`（このskillをステップ7として呼び出す）
- PR レビュー自動化（先行ステップ）: `/setup-ci-review`
