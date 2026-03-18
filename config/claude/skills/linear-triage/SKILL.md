---
name: linear-triage
description: LinearタスクのトリアージとプロジェクトUpdate作成。「トリアージ」「Linear Update」「プロジェクト更新」等で起動。
user-invocable: true
allowed-tools:
  - Task
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_cycles
  - mcp__linear-server__update_issue
  - mcp__linear-server__save_status_update
  - mcp__linear-server__get_status_updates
  - AskUserQuestion
---

# /linear-triage - タスクトリアージ & プロジェクトUpdate

## 目的

Linearの現サイクルから自分のタスクを取得し、1件ずつ対話的にトリアージ（優先度設定）した後、プロジェクト単位でStatus Updateを統一フォーマットで作成する。

## フロー

```
タスク取得 → トリアージ（対話） → プロジェクトUpdate作成
```

## Phase 1: タスク取得

Taskツールでsubagentを使い、現サイクルの自分のタスクを取得する。

```
Task(
  subagent_type: "general-purpose",
  description: "Linearタスク取得・整形",
  prompt: <下記>
)
```

### subagentプロンプト

詳細プロンプトは `${CLAUDE_SKILL_DIR}/reference.md` の「subagentプロンプト（Phase 1）」を参照。

概要: Linear MCPで現サイクルを取得 → 全タスク取得 → 自分のタスクを抽出 → identifier/title/status/priority/estimate/project/description/URL 形式で返す。

## Phase 2: トリアージ（対話）

取得したタスクを1件ずつ提示し、優先度を確認する。

### 提示フォーマット

```
N件目: `PF-XXXX` タイトル

- プロジェクト: ○○
- 現在: Status / Xpt
- 現在の優先度: ○○
- 概要: （descriptionから要約）

優先度は？（Urgent / High / Normal / Low / 現状維持）
```

### ルール

- 既に適切な優先度が設定済みのものも確認する（スキップしない）
- ユーザーが「現状維持」「OK」等と回答したら変更しない
- 変更があった場合は即座に `mcp__linear-server__update_issue` で反映
- 全件完了後、Phase 3へ進む

## Phase 3: プロジェクトUpdate作成

トリアージ結果を元に、プロジェクト単位でStatus Updateを作成/更新する。

### 手順

1. `mcp__linear-server__get_status_updates` で各プロジェクトの直近Updateを確認
2. 同日のUpdateがあれば更新、なければ新規作成
3. `mcp__linear-server__save_status_update` で保存

### Updateフォーマット / 優先度の絵文字マッピング

フォーマットと絵文字マッピングは `${CLAUDE_SKILL_DIR}/reference.md` の「Updateフォーマット（統一）」「優先度の絵文字マッピング」を参照。

### healthの判断基準

- `onTrack`: デッドラインに余裕がある、ブロッカーなし
- `atRisk`: デッドラインが近い、外部依存あり、作業量に対して時間が足りない
- `offTrack`: デッドラインを超過、重大なブロッカーあり

healthの判断に迷う場合はユーザーに確認する。

### Issueリンクのルール

詳細は `${CLAUDE_SKILL_DIR}/reference.md` の「Issueリンクのルール」を参照。リンクなしのIssue IDは禁止。

## Phase 4: デイリーノート更新（任意）

Obsidianのデイリーノートが存在する場合、トリアージ結果を反映する。
ノートがない場合はスキップ（デイリーノート作成はこのSkillのスコープ外）。

## Gotchas

(運用しながら追記)
