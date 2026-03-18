# linear-triage リファレンス

## subagentプロンプト（Phase 1）

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

## Updateフォーマット（統一）

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

## 優先度の絵文字マッピング

| 優先度 | 表記 |
|--------|------|
| Urgent | 🔥 Urgent |
| High | 🔴 High |
| Normal | 🟡 Normal |
| Low | 🔵 Low |

## Issueリンクのルール

Issueを参照する際は必ずLinearのURLリンクを付与する:
- テーブル内: `[PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)`
- 本文中: 同上

リンクなしのIssue IDは禁止。
