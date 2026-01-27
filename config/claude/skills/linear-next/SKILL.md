---
name: linear-next
description: Linearの現在のサイクルから次のタスクを表示。「次のタスク」「Linear確認」「今週やること」等で起動。
user-invocable: true
allowed-tools:
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_issues
  - mcp__linear-server__get_issue
  - mcp__linear-server__get_user
  - mcp__linear-server__update_issue
  - Bash(jq:*)
  - Bash(cat:*)
---

# /linear-next - 次のタスクを確認

## 目的
Linearの現在のサイクルから、自分にアサインされている未完了タスクを表示し、次に取り組むべきタスクを選択できるようにする。

## 設定

```
TEAM_ID: 01826a20-6bbd-4135-b732-2d789b98f7e8  # Platform
```

## 動作手順

### 1. 現在のサイクル情報を取得
`mcp__linear-server__list_cycles` でPlatformチームの現在のサイクルを取得。

### 2. サイクルのissueを取得
`mcp__linear-server__list_issues` でサイクルIDを指定してissueを取得:
- team: Platform
- cycle: (取得したサイクルID)
- includeArchived: false

### 3. 自分のタスクをフィルタ
結果が大きい場合はファイルに保存されるので、jqでフィルタ:
```bash
cat {result_file} | jq -r '.[0].text' | jq '[.issues[] | select(.assigneeId == "{user_id}") | select(.status | IN("Done", "Canceled") | not) | {id: .identifier, title: .title, state: .status, estimate: .estimate.value, url: .url, project: .project}]'
```

ユーザーIDは `mcp__linear-server__get_user` で `me` を指定して取得。

### 4. 結果を表示
ステータス順（In Progress → Todo）でソートして表形式で表示:

| Status | ID | タイトル | 見積もり | プロジェクト |
|--------|-----|---------|---------|-------------|
| In Progress | PF-XXX | タスク名 | Xpt | プロジェクト名 |
| Todo | PF-YYY | タスク名 | Ypt | - |

合計ポイントも表示。

### 5. タスク選択を促す
「どのタスクから始めますか？」と問いかける。

### 6. 選択されたタスクの詳細取得
ユーザーがIDを指定したら `mcp__linear-server__get_issue` で詳細を取得し、作業に必要な情報を表示:
- タイトル
- 説明（全文）
- プロジェクト
- 関連ドキュメント
- Git ブランチ名

## 出力例

```
## 現在のサイクル: Cycle 29 (2026/01/26 - 2026/02/01)

| Status | ID | タイトル | 見積もり |
|--------|-----|---------|---------|
| In Progress | PF-956 | Incident Email Notifier メール通知設定の調査・改善 | 1pt |
| Todo | PF-1027 | Incident Email Notifierのプロンプト改善 | 2pt |

合計: 3pt

どのタスクから始めますか？
```

## 注意事項
- 結果が大きい場合はファイルに保存されるので、jqでパースする
- assigneeIdでフィルタ（assigneeはメールアドレス文字列のため）
- statusフィールドを使用（state.nameではない）
