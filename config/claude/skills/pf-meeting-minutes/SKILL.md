---
name: pf-meeting-minutes
description: PF定例の議事録を作成。文字起こしとLinearプロジェクトを照合してプロジェクトベースで構成。「PF定例の議事録」「PF定例まとめて」等で起動。
user-invocable: true
allowed-tools:
  - Task
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_projects
---

# /pf-meeting-minutes - PF定例議事録作成

## 目的
PF定例の文字起こしから、Linearプロジェクトベースで構成された議事録を作成する。

## 前提条件
- 文字起こしファイルが `06_Transcripts/` にあること
- Linearにアクセス可能であること

## 実行手順

### 1. 日付確認と文字起こしファイル特定

```bash
date "+%Y-%m-%d (%a) %H:%M"
```

06_Transcripts/から最新のPF定例の文字起こしを特定:
```
Glob(pattern: "**/PF定例*.md", path: "06_Transcripts/")
```

ユーザーにファイルを確認:「この文字起こしファイルでよいですか？」

### 2. 必要情報を並列取得

以下を並列で取得:

**人名対応表**:
```
Read(file_path: "04_Docs/人名対応表.md")
```

**文字起こし**:
```
Read(file_path: <特定したファイル>)
```

**Linearプロジェクト一覧**:
```
ToolSearch(query: "+linear projects cycles issues")
```
→ mcp__linear-server__list_projects(team: "Platform", status: "active")

**current cycleのIssue**:
```
mcp__linear-server__list_cycles(teamId: "01826a20-6bbd-4135-b732-2d789b98f7e8", type: "current")
mcp__linear-server__list_issues(team: "Platform", assignee: "me", limit: 100)
```

### 3. 議事録構成の整理

**Linearプロジェクトとの照合**:
- 文字起こしで言及されたプロジェクトを特定
- 各プロジェクトに関連するIssueを紐付け
- 言及のないプロジェクトは除外

**構成ルール**:
- Linearプロジェクトごとにセクションを作成
- 各セクションにLinearリンクと関連Issueを記載
- プロジェクトに紐付かない話題は「その他」セクションに

### 4. 議事録作成

**出力先**: `00_Inbox/YYYY-MM-DD_PF定例.md`

**フォーマット**:
```markdown
---
title: "PF定例"
date: YYYY-MM-DD
meeting_type: "定例"
participants:
  - 須藤
  - （参加者を人名対応表の表記で記載）
tags: [meeting, Platform, ...]
---

## 議題・進捗報告

### 1. プロジェクト名
**Linear**: [プロジェクト名](https://linear.app/winticket/project/...)

（議論内容を箇条書きで整理）

**関連Issue**:
- [PF-XXX] タイトル (ステータス) @担当者 [Xpt]

---

### 2. 次のプロジェクト名
...

### N. その他
（プロジェクトに紐付かない話題）
```

**省略する項目**（不要なセクション）:
- サマリー（h1タイトルも不要）
- 決定事項
- ネクストアクション

### 5. 文字起こしのアーカイブ

議事録作成完了後、文字起こしを移動:
```
06_Transcripts/xxx.md → 99_Archive/Transcripts/xxx.md
```

## 表記ルール

- 人名は `04_Docs/人名対応表.md` の「議事録表記」を使用
- ASICSチームメンバーは `（ASICS）` を付記
- 技術用語はカタカナではなく正式名称（例: ワーカー→Worker）
- Linearリンクは日本語プロジェクト名でも動作する

## 注意事項

- 文字起こしの内容を要約しすぎない（議論の経緯が分かる程度に）
- 不明な技術用語があれば確認してから記載
- 人名が不明な場合は須藤に確認
