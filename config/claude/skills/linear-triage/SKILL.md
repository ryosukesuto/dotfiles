---
name: linear-triage
description: 週次レビュー。PR-Issue紐づけ、プロジェクトUpdate更新、優先度整理、Cycle修正。「トリアージ」「Linear Update」「週次レビュー」「weekly review」等で起動。
user-invocable: true
allowed-tools:
  - Bash(gh:*)
  - Agent
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
```

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

1. `list_projects(member: "me")` で参加プロジェクトを取得
2. 各プロジェクトのIssueを `list_issues(assignee: "me", project: <id>)` で取得
3. `list_issues(assignee: "me", limit: 100)` でプロジェクト外Issueも取得
4. プロジェクト別・ステータス別のサマリを表示

subagentプロンプトは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

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

1. `list_cycles(teamId: TEAM_ID, type: "current")` でCycle取得
2. Cycle内の自分のタスクを取得
3. 修正案を提示:
   - Urgent/HighだがCycleに未追加 → 追加候補
   - Low/NoneでCycleに存在 → 除外候補
   - 完了済みだがCycleに残存 → ステータス確認
   - ポイント合計超過 → 調整提案
4. 承認後、`save_issue` でCycle割り当てを変更

subagentプロンプトは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 6: デイリーノート更新（任意）

Obsidianのデイリーノートが存在する場合、レビュー結果を反映する。ノートがない場合はスキップ。

## 設定

- TEAM_ID: `~/.claude/rules/service-environments.local.md` を参照

## Gotchas

- `gh pr list` は現在のリポジトリのPRのみ返す。複数リポジトリを横断する場合は `gh search prs --author=@me` を使う
- Phase 1のPR description更新はマージ済みPRでも `gh pr edit` で可能
- `list_projects(member: "me")` はViewerだけのプロジェクトも含む可能性がある。active状態のみを対象にする
- Cycleへの追加は `save_issue(id: "PF-XXXX", cycle: <cycleId>)` で行う。Cycleから外す場合はcycleにnullを指定できないため、ユーザーに手動対応を案内する
