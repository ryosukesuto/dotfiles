---
name: linear-triage
description: 週次レビュー。PR-Issue紐づけ、プロジェクトUpdate更新、優先度整理、Cycle修正、月初は CI レビュー未適用リポの起票。「トリアージ」「Linear Update」「週次レビュー」「weekly review」「月次レビュー」等で起動。
user-invocable: true
allowed-tools:
  - Bash(gh:*)
  - Bash(~/gh/github.com/ryosukesuto/dotfiles/bin/claude-review-coverage*)
  - Bash(claude-review-coverage*)
  - Bash(jq:*)
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_projects
  - mcp__linear-server__get_issue
  - mcp__linear-server__get_status_updates
  - mcp__linear-server__save_issue
  - mcp__linear-server__save_comment
  - mcp__linear-server__save_status_update
  - AskUserQuestion
---

# /linear-triage - Weekly Review

## 目的

直近1週間の作業を棚卸しし、Linearの状態を最新化する。PR-Issue紐づけ → プロジェクトUpdate → 優先度整理 → Cycle修正の順で実行。

## フロー概要

```
Phase 1: PR-Issue紐づけチェック
Phase 2: プロジェクト横断タスク取得
Phase 3: プロジェクトUpdates更新
Phase 4: プロジェクト外Issueの整理
Phase 5: Current Cycle修正
Phase 6: デイリーノート更新（任意）
Phase 7: 月次タスク（月次レビュー時のみ）
```

### 起動時の月次判定

skill 起動直後、AskUserQuestion で「今回は月次レビューですか？」を必ず確認する。yes なら Phase 7 まで実行、no なら Phase 6 で終了。

判定の目安: 当月初の linear-triage 実行であれば yes、それ以外は no。ユーザー発話に「月次」「monthly」「月初」が含まれていれば自動的に yes 扱い。

## Phase 1: PR-Issue紐づけチェック

PRとIssueの乖離を放置すると、進捗が見えなくなり週次報告の精度が下がる。早期に紐づけを揃える。

### 手順

1. 直近1週間の自分のPRを `gh pr list --author=@me --state=all` で取得
2. 各PRから `PF-XXXX` パターンを抽出（ブランチ名、タイトル、body）
3. 紐づけ済み / 未紐づけ / 要確認に分類して表示
4. 未紐づけPRごとにユーザーに確認: 新規Issue起票 / 既存Issue指定 / スキップ
5. マージ済みPRでIssueがDone/Cancelledでないものを報告
6. PR descriptionにLinearリンクを追記（マージ済み含む）

詳細な手順・出力フォーマット・PR description追記フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 2: プロジェクト横断タスク取得

全プロジェクトの状況を一覧化することで、Phase 3以降の判断材料を揃える。

### 手順

1. `mcp__linear-server__list_projects(member: "me", state: "started")` で参加プロジェクトを取得
2. 各プロジェクトのIssueを `mcp__linear-server__list_issues(assignee: "me", project: <projectId>)` で取得
3. `mcp__linear-server__list_issues(assignee: "me", limit: 100)` でプロジェクト外Issueも取得（プロジェクト付きIssueのIDを除外）
4. MCP応答から必要フィールドだけ抽出し、プロジェクト別・ステータス別のサマリを表示（生JSONをそのまま出力しない）

出力フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 3: プロジェクトUpdates更新

Updateが古いとステークホルダーに誤った状況認識を与える。最新のタスク状況との差分を埋める。

### 手順

1. 各プロジェクトの直近Updateを `get_status_updates(type: "project", project: <id>, limit: 1)` で取得
2. Phase 2のタスク状況と比較し、差分を分析
3. Update案（変化点・health判定・下書き）をユーザーに提示
4. 承認後、`save_status_update` で保存

Updateフォーマット / healthの判断基準 / 優先度の絵文字マッピング / Issueリンクのルールは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 4: プロジェクト外Issueの整理

プロジェクトに属さないIssueは棚卸しから漏れやすい。放置を防ぐために1件ずつ確認する。

Phase 2で抽出した「プロジェクト外Issue」を1件ずつ提示し、ユーザーに対応を確認する。
対応: 優先度変更 / コメント追加 / プロジェクトに追加 / 現状維持。
変更は `save_issue` / `save_comment` で即座に反映。作成から30日以上ステータス未変更のIssueは特に注意を促す。

提示フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 5: Current Cycle修正

優先度の変動を反映しないとCycleが実態と乖離する。ここまでの判断をCycleに落とし込む。

### 手順

1. `mcp__linear-server__list_cycles(teamId: TEAM_ID, type: "current")` でCycle取得
2. `mcp__linear-server__list_issues(team: TEAM_ID, cycle: <cycleId>, limit: 100)` でCycle内タスクを取得し、自分のタスクだけ抽出
3. MCP応答から必要フィールドだけ抽出して修正案を提示（生JSONをそのまま出力しない）:
   - Urgent/HighだがCycleに未追加 → 追加候補
   - Low/NoneでCycleに存在 → 除外候補
   - 完了済みだがCycleに残存 → ステータス確認
   - ポイント合計超過 → 調整提案
4. 承認後、`save_issue` でCycle割り当てを変更

## Phase 6: デイリーノート更新（任意）

Obsidianのデイリーノートが存在する場合、レビュー結果を反映する。ノートがない場合はスキップ。

## Phase 7: 月次タスク（月次レビュー時のみ）

月次レビュー判定が yes の場合のみ実行。CI レビュー自動化（setup-ci-review）が未適用のリポを Linear に Issue として積み、適用漏れを防ぐ。

### 手順

1. `claude-review-coverage --format json --only-missing` を実行して未適用リポ一覧を取得
   ```bash
   ~/gh/github.com/ryosukesuto/dotfiles/bin/claude-review-coverage --format json --only-missing > /tmp/coverage-missing.json
   ```
2. 結果を `jq` で整形して、リポごとに以下を抽出:
   - `repo`: `host/owner/name`
   - `status`: `未適用` / `部分適用`
   - 既存ファイル状況（workflow/skill/greptile/checkov の有無）
3. 既に Linear に同名 Issue が存在しないかチェック
   ```
   mcp__linear-server__list_issues(query: "setup-ci-review {repo}", limit: 5)
   ```
4. 未起票のリポをユーザーに提示し、どれを起票するか確認（`AskUserQuestion` でまとめて選択）
5. 承認されたリポについて `mcp__linear-server__save_issue` で Issue 作成
   - タイトル: `{repo} に setup-ci-review を導入`
   - body: 下記テンプレート参照
   - priority: 部分適用は `2 (High)`、未適用は `3 (Normal)`
   - team: 設定の TEAM_ID
   - labels: `["devx", "automation"]`（既存ラベルがあれば追加）

### Issue body テンプレート

```markdown
## 背景

`bin/claude-review-coverage` で {YYYY-MM-DD} 時点で未適用と検出されたリポ。
PR レビュー自動化（Claude Code Action / Greptile）を導入して、AI レビュー
が走る状態にする。

## 現状

- リポ: {host/owner/name}
- workflow (`.github/workflows/claude-review.yml`): {✅ / ❌}
- skill (`.claude/skills/claude-code-review/SKILL.md`): {✅ / ❌}
- greptile (`.greptile/config.json`): {✅ / ❌}
- checkov (`.github/workflows/checkov.yml`): {✅ / ❌}

## やること

1. `setup-ci-review` skill を流す（個人ツール、対話で構成決定）
2. `ANTHROPIC_API_KEY` を Settings > Secrets に登録
3. `https://github.com/apps/claude` から GitHub App を対象リポにインストール
4. branch protection の Required approvals を 2 以上に設定
5. 初回 PR で動作確認（マージ後の次の PR で実レビューが走る）

詳細手順: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md`

## 完了条件

- `claude-review-coverage` で `完全適用` と表示される
- 直近 1 件の PR で Claude Code Action が動作している
```

### 注意

- 一度に大量起票しない。月 5 件を目安に、優先度の高いリポから順次（重要度: ops > server-config > 業務リポ > その他）
- 既に Issue がある場合は新規起票せず、既存 Issue にコメントで「{YYYY-MM-DD} 時点で未適用継続」と追記する選択肢を提示
- 個人 / experimental リポは「適用しない判断」として手動でカバレッジから除外する候補をユーザーに確認

## 設定

- TEAM_ID: `~/.claude/rules/service-environments.local.md` を参照

## Gotchas

- `gh pr list` は現在のリポジトリのPRのみ返す。複数リポジトリを横断する場合は `gh search prs --author=@me` を使う
- Phase 1のPR description更新はマージ済みPRでも `gh pr edit` で可能
- `list_projects(member: "me")` はViewerだけのプロジェクトも含む可能性がある。active状態のみを対象にする
- Cycleへの追加は `save_issue(id: "PF-XXXX", cycle: <cycleId>)` で行う。Cycleから外す場合はcycleにnullを指定できないため、ユーザーに手動対応を案内する
