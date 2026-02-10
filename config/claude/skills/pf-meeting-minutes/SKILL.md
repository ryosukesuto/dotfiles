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
  - Bash
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_projects
---

# /pf-meeting-minutes - PF定例議事録作成

## 目的
PF定例の文字起こしから、Linearプロジェクトベースで構成された議事録を作成する。

## 前提条件
- 引数で文字起こしテキストが渡されること
- Linearにアクセス可能であること

## 実行手順

### 1. 日付確認と必要情報の並列取得

```bash
date "+%Y-%m-%d (%a) %H:%M"
```

以下を並列で取得:

**人名対応表**:
```
Read(file_path: "04_Docs/人名対応表.md")
```

**ドメイン用語対応表**:
```
Read(file_path: "04_Docs/ドメイン用語対応表.md")
```

**Linearプロジェクト一覧**:
```
ToolSearch(query: "+linear projects cycles issues")
```
→ mcp__linear-server__list_projects(team: "Platform")
※ プロジェクトのLeadが各プロジェクトの担当者を示す

**current cycleの全Issue**:
```
mcp__linear-server__list_cycles(teamId: "01826a20-6bbd-4135-b732-2d789b98f7e8", type: "current")
mcp__linear-server__list_issues(team: "Platform", cycle: "<取得したcycle_id>", limit: 250)
```
※ `assignee: "me"` は付けない。チーム全体のIssueが必要

### 3. プロジェクト照合（逆引き方式）

文字起こしのプロジェクト名は音声認識でガーブルされることが多いため、以下の手順で照合する:

**Step 1: Issue内容からの逆引き**
- current cycleのIssueタイトル・内容と、文字起こしの議論内容を照合
- 例: 「ログ送信をDatadogに」→ PF-830「Error/Warn以外のログもDatadogに送信する」→ Datadog改善プロジェクト

**Step 2: プロジェクトLeadとの照合**
- プロジェクトのLead情報から、発言者とプロジェクトの対応を推定
- 例: GKEクラスタ移行のLead=谷口 → 「ぐっちゃん」がGKE移行について報告

**Step 3: ガーブル名の解読**
- 音声認識は技術用語やプロジェクト名を頻繁に誤認識する
- Issue内容との照合で正式名称を特定する（文字起こしの名称をそのまま使わない）

**構成ルール**:
- Linearプロジェクトごとにセクションを作成
- 各セクションにLinearプロジェクトリンクと関連Issueを記載
- プロジェクトに紐付かない話題は「その他」セクションに

### 4. 議事録作成

**出力先**: `00_Inbox/YYYY-MM-DD_<会議名>.md`
- 会議名は引数で指定された件名を使用（PF定例、PFプランニング等）

**フォーマット**:
```markdown
---
title: "<会議名>"
date: YYYY-MM-DD
meeting_type: "<会議種別>"
tags: [meeting, Platform, ...]
---

## 参加者

- @kibela_username（人名対応表のKibela列を参照）

## 議題・進捗報告

### 1. プロジェクト名
**Linear**: [プロジェクト名](https://linear.app/winticket/project/...)

（議論内容を箇条書きで整理）

**関連Issue**:
- [PF-XXX](https://linear.app/winticket/issue/PF-XXX) タイトル [Xpt]

---

### 2. 次のプロジェクト名
...

### N. その他
（プロジェクトに紐付かない話題）
```

**関連IssueのURL形式**:
- 必ず `[PF-XXX](https://linear.app/winticket/issue/PF-XXX)` 形式でLinearリンクを付与
- estimateがあれば末尾に `[Xpt]` を記載

**省略する項目**（不要なセクション）:
- サマリー（h1タイトルも不要）
- 決定事項
- ネクストアクション

### 5. 過去の議事録参照と表記ゆれ修正

議事録作成後、過去の同じ会議の議事録を参照して用語の表記を統一:

```bash
# 同じ会議の過去の議事録を検索（最新3件程度）
- 04_Docs/*PF定例*.md
- 00_Inbox/*PF定例*.md
```

- タイトル形式を過去の議事録と統一
- 技術用語の英語表記（カタカナ→英語）
- プロジェクト固有用語の統一

## 表記ルール

- 人名は `04_Docs/人名対応表.md` の「議事録表記」を使用
- サービス名・競合名・社内用語は `04_Docs/ドメイン用語対応表.md` の「正式表記」を使用
- ASICSチームメンバーは `（ASICS）` を付記
- 技術用語はカタカナではなく正式名称（例: ワーカー→Worker）
- Linearリンクは日本語プロジェクト名でも動作する

## 音声認識のガーブル対応

`04_Docs/ドメイン用語対応表.md` を参照し、サービス名・競合名・社内用語の正式表記に変換する。
加えて、以下のような技術用語のガーブルも頻出する。Issue内容との照合で正式名称に変換すること:

| ガーブル例 | 正式名称 | 解読のヒント |
|-----------|----------|-------------|
| カニメロウサッシュ | 管理面ロール刷新 | 「かんりめんロールさっしん」の音声誤認 |
| Auto-esth | autorace | 「オートレース」の音声誤認 |
| 白リック | Public (Registry) | 「パブリック」の音声誤認 |
| メジャム | メジャー | 「メジャー」の音声誤認 |

原則: ガーブルされた名称をそのまま使わず、ドメイン用語対応表・Linearプロジェクト名・Issueタイトルから正式名称を特定する。
不明な場合は須藤に確認。

## 注意事項

- 文字起こしの内容を要約しすぎない（議論の経緯が分かる程度に）
- 不明な技術用語があれば確認してから記載
- 人名が不明な場合は須藤に確認（推測禁止）
- プロジェクトLeadの情報を活用して発言者とプロジェクトの対応を推定できるが、人名対応表にない人物は推測せず確認する
