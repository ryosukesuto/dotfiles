---
name: setup-ci-review
description: GitHubリポジトリにPRレビュー自動化を対話的に導入する。Claude Code workflow / Greptile / Checkov gating / Renovate Tier policy を bootstrap。既存ファイルの更新はスコープ外。「PRレビュー導入」「setup-ci-review」「コードレビューCI bootstrap」「CIレビュー setup」等で起動。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash(ls:*)
  - Bash(mkdir:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Bash(diff:*)
  - AskUserQuestion
  - Bash(~/.claude/skills/setup-ci-review/scripts/*)
---

## 実行手順

### 1. リポジトリ確認

```bash
gh repo view --json nameWithOwner,defaultBranchRef
```

失敗した場合は `git remote get-url origin` でフォールバック。
`REPO_NAME` を取得しておく。

### 2. ユーザーへの質問（1回でまとめて聞く）

`AskUserQuestion` で以下を一度に収集する。

- preset: `generic` / `iac`
- コンポーネント選択（multiSelect）:
  - `generic`: Claude Code workflow / Greptile
  - `iac`: Claude Code workflow / Greptile / Checkov（IaCのみ候補追加）

### 3. 競合検出

生成予定ファイルのパスを引数として `${CLAUDE_SKILL_DIR}/scripts/detect-conflicts.sh` を実行する。

出力を読んでユーザーに提示し、既存ファイルがある場合はマージ判断を仰ぐ。
**Skillは自動マージも自動上書きもしない。**

`.greptile/` 配下は3ファイル（config.json / rules.md / files.json）を個別に引数に含める。
ディレクトリの存在だけで「スキップ」と判定してはいけない。

### 4. テンプレートの読み込みと変数置換、ファイル生成

`${CLAUDE_SKILL_DIR}/templates/` 配下のテンプレートを `Read` し、以下を置換して `Write` する。

| 変数 | 置換先 |
|------|--------|
| `{{REPO_NAME}}` | 実際のリポジトリ名 |
| `{{REVIEWER_ROLE}}` | generic=「シニアエンジニア」 / iac=「Terraformシニアレビュアー」 |
| `{{REVIEW_CRITERIA}}` | generic=空文字 / iac=reference.md の IaC観点カタログ内容 |
| `{{DATE}}` | 実行日（YYYY-MM-DD） |

生成先（選択されたコンポーネントのみ）:
- Claude Code workflow: `.github/workflows/claude-review.yml`
- Greptile: `.greptile/config.json` / `.greptile/rules.md` / `.greptile/files.json`
  - IaC preset → `rules-iac.md` を `rules.md` として生成
  - generic preset → `rules.md` をそのまま生成
- Checkov: `.github/workflows/checkov.yml`（IaC preset かつ選択時のみ）

### 5. SHA-pin 検証

生成した `.yml` ファイルのパスを引数として `${CLAUDE_SKILL_DIR}/scripts/verify-sha-pin.sh` を実行する。

exit 1 の場合は失敗として報告し、修正を促す。
local action（`uses: ./...`）と reusable workflow は検証対象外（スクリプト内で除外済み）。

### 6. 完了ガイド表示

以下をユーザーに伝える。

- 必要な Secret: `ANTHROPIC_API_KEY`（リポジトリ Settings > Secrets > Actions）
- Branch Protection は維持したまま、Claude / Greptile の check を Required Check にしない
- Greptile `statusCheck: true` は状態表示用。Required Check にすると block 相当になるため注意
- 生成ファイルの確認を促し、コミット・PR作成はユーザーに委ねる

## Gotchas

- `anthropics/claude-code-action` は advisory のみ（APPROVE/REQUEST_CHANGES を出さない）
- `.greptile/` は3ファイルを個別に競合判定。ディレクトリ存在だけでスキップ禁止
- Checkov は IaC preset 選択時のみ候補に出す（Terraform専用）
- `verify-sha-pin.sh` は生成ファイルのみ対象

詳細は `${CLAUDE_SKILL_DIR}/reference.md` を参照（必要時のみ読み込む）。
