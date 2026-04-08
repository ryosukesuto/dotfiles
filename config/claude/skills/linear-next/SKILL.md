---
name: linear-next
description: Linearの現在のサイクルから次のタスクを表示。「次のタスク」「Linear確認」「今週やること」等で起動。
user-invocable: true
allowed-tools:
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_issues
  - mcp__linear-server__get_user
  - mcp__linear-server__get_issue
---

# /linear-next - 次のタスクを確認

## 目的
Linearの現在のサイクルから、自分にアサインされている未完了タスクを表示する。

## 設定
- TEAM_ID: `~/.claude/rules/service-environments.local.md` を参照

## 手順

### 1. 現在のサイクルとユーザー情報を並列取得

- `mcp__linear-server__list_cycles(teamId: TEAM_ID, type: "current")`
- `mcp__linear-server__get_user(query: "me")`

### 2. 自分のタスクを取得

```
mcp__linear-server__list_issues(
  team: "Platform",
  assignee: "me",
  includeArchived: false,
  limit: 100
)
```

### 3. フィルタリング・整形して表示

MCP応答から必要なフィールドだけ抽出し、以下の形式で表示する。生JSONをそのまま出力しない。

- 未完了のみ (status が Done, Canceled 以外)
- サイクル内とサイクル外（バックログ）に分類
- ステータス順にソート (In Progress → In Review → Todo)

```
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

## Gotchas

(運用しながら追記)
