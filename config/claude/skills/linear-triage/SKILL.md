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

```
Linearから現サイクルの自分のタスク一覧を取得し、整形して返してください。

## 設定
- TEAM_ID: ~/.claude/rules/service-environments.local.md を参照

## 手順

1. ToolSearchで Linear MCPツールをロード:
   ToolSearch(query: "+linear cycle issues list")

2. 現在のサイクルを取得:
   mcp__linear-server__list_cycles(teamId: TEAM_ID, type: "current")

3. サイクルIDで全タスクを取得:
   mcp__linear-server__list_issues(
     team: TEAM_ID,
     cycle: <取得したサイクルID>,
     limit: 100
   )

4. 結果をJSONパースし、自分（須藤/suto）のタスクだけ抽出

5. 以下の形式で返す（全件、優先度・ステータス問わず）:

タスク1件につき:
- identifier (PF-XXXX)
- title
- status
- priority (0=None, 1=Urgent, 2=High, 3=Normal, 4=Low)
- estimate (ポイント)
- project名
- description（冒頭200文字）
- URL
```

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

### Updateフォーマット（統一）

```markdown
## MM/DD タイトル（状況を端的に）

### 状況

1-2行で全体サマリ。

### Issue進捗

| Issue | 優先度 | Status | 内容 |
| -- | -- | -- | -- |
| [PF-XXXX](https://linear.app/winticket/issue/PF-XXXX) | 🔥 Urgent | In Progress | 説明 |

### 前回からの差分

- 箇条書きで変更点

### 次のアクション

- 箇条書きで次にやること
```

### 優先度の絵文字マッピング

| 優先度 | 表記 |
|--------|------|
| Urgent | 🔥 Urgent |
| High | 🔴 High |
| Normal | 🟡 Normal |
| Low | 🔵 Low |

### healthの判断基準

- `onTrack`: デッドラインに余裕がある、ブロッカーなし
- `atRisk`: デッドラインが近い、外部依存あり、作業量に対して時間が足りない
- `offTrack`: デッドラインを超過、重大なブロッカーあり

healthの判断に迷う場合はユーザーに確認する。

### Issueリンクのルール

Issueを参照する際は必ずLinearのURLリンクを付与する:
- テーブル内: `[PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)`
- 本文中: 同上

リンクなしのIssue IDは禁止。

## Phase 4: デイリーノート更新（任意）

Obsidianのデイリーノートが存在する場合、トリアージ結果を反映する。
ノートがない場合はスキップ（デイリーノート作成はこのSkillのスコープ外）。
