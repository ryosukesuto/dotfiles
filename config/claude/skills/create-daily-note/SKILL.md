---
name: create-daily-note
description: デイリーノートを作成する。「デイリーノート作って」「今日のノート」「daily note」等で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - mcp__linear-server__list_issues
---

# /create-daily-note - デイリーノート作成

日付確認 → Linear Issue取得 → デイリーノート作成を一括で行う。

## 実行手順

### 1. 日付確認

```bash
date "+%Y-%m-%d (%a) %H:%M"
```

ユーザーに「今日は○月○日、デイリーノートを作成しますね」と確認する。

### 2. 既存ファイル確認

`YYYY-MM-DD_daily.md` が既に存在するか確認する。
- 存在する場合: 上書きせず、Linear Issueの更新だけ提案する
- 存在しない場合: 新規作成へ進む

### 3. Linear Issue取得

自分にアサインされたIssueをステータス別に取得する:

```
mcp__linear-server__list_issues:
  assignee: "me"
  team: "Platform"
  state: "In Progress"
  includeArchived: false

mcp__linear-server__list_issues:
  assignee: "me"
  team: "Platform"
  state: "Todo"
  includeArchived: false
```

2つのリクエストは並列実行する。

### 4. デイリーノート作成

Vault直下に `YYYY-MM-DD_daily.md` を作成する。

構造:
```markdown
## Tasks

### 個人
- [ ] {前日から引き継いだ未完了タスク}

### Linear (In Progress)
- [ ] [PF-XXXX](url) タイトル

### Linear (Todo)
- [ ] [PF-XXXX](url) タイトル

---
```

### 5. 前日の未完了タスク引き継ぎ

直近のデイリーノートから `### 個人` セクションの未完了タスク(`- [ ]`)を探し、今日のノートに引き継ぐ。
未完了タスクがなければ `### 個人` セクションは空にする。

## Gotchas

- Vault直下に配置する。サブフォルダに作らない
- Linear Issueのチェックボックスはその日の把握用スナップショット。ステータス管理はLinear側で行う
- 個人タスクの完了管理はデイリーノート側で完結する
- `team: "Platform"` 固定で取得する。他チームのIssueが必要になったら拡張する
- 親子関係のあるIssue（例: PF-986の子にPF-1063/1064）は両方表示してよい。フラットに並べる
