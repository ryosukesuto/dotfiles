---
name: linear-next
description: Linearの現在のサイクルから次のタスクを表示。「次のタスク」「Linear確認」「今週やること」等で起動。
user-invocable: true
allowed-tools:
  - Task
  - mcp__linear-server__get_issue
---

# /linear-next - 次のタスクを確認

## 目的
Linearの現在のサイクルから、自分にアサインされている未完了タスクを表示する。
subagentを使ってMCPレスポンスのトークン消費を抑える。

## 実行方法

Taskツールでsubagentを起動し、整形済みの結果を受け取る:

```
Task(
  subagent_type: "general-purpose",
  description: "Linearタスク一覧取得",
  prompt: <下記のプロンプト>
)
```

## subagentへのプロンプト

```
Linearから自分のタスク一覧を取得し、整形して返してください。

## 設定
- TEAM_ID: ~/.claude/rules/service-environments.local.md を参照

## 手順

1. ToolSearchで Linear MCPツールをロード:
   ToolSearch(query: "+linear cycle issues user")

2. 現在のサイクルとユーザー情報を並列取得:
   - mcp__linear-server__list_cycles(teamId: TEAM_ID, type: "current")
   - mcp__linear-server__get_user(query: "me")

3. 自分のタスクを取得:
   mcp__linear-server__list_issues(
     team: "Platform",
     assignee: "me",
     includeArchived: false,
     limit: 100
   )

4. 結果をフィルタリング・整形:
   - 未完了のみ (status が Done, Canceled 以外)
   - サイクル内とサイクル外（バックログ）に分類
   - ステータス順にソート (In Progress → In Review → Todo)

5. 以下の形式で返す:

## 現在のサイクル: Cycle XX (YYYY/MM/DD - YYYY/MM/DD)

### 未完了タスク
| Status | ID | タイトル | 見積もり | プロジェクト |
|--------|-----|---------|---------|-------------|
| In Progress | PF-XXX | タスク名 | Xpt | プロジェクト名 |

未完了: Xpt / 完了: Ypt

### バックログ（サイクル未設定）
プロジェクト別にグループ化して表示。

---
どのタスクから始めますか？
```

## タスク詳細の取得

ユーザーがIDを指定したら `mcp__linear-server__get_issue` で詳細を取得:
- タイトル
- 説明（全文）
- プロジェクト
- 関連ドキュメント
- Git ブランチ名

※ 詳細取得はsubagentを使わず直接呼び出す（1件なのでトークン消費は小さい）
