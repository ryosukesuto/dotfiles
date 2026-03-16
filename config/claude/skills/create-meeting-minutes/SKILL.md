---
name: create-meeting-minutes
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
  - mcp__notion__notion-search
  - mcp__notion__notion-fetch
  - mcp__notion__notion-move-pages
  - mcp__ragent__hybrid_search
---

# /create-meeting-minutes - 議事録作成

## 目的
会議の文字起こしから、Linearプロジェクトベースで構成された議事録を作成する。

## 前提条件
- Linearにアクセス可能であること
- 文字起こしテキストは以下のいずれかで取得:
  - **引数で直接渡される**（従来通り）
  - **Notion MCPから自動取得**（引数なしの場合）— カレンダーで会議を特定し、Notionから文字起こしを取得

## テンプレート

会議名からテンプレートを選択し、構成を決定する:

| 会議名 | テンプレート | 特徴 |
|--------|------------|------|
| PF定例 | `templates/pf-teirei.md` | 全プロジェクト進捗報告 |
| PF施策共有会 | `templates/pf-shisaku-kyouyukai.md` | 技術的深掘り・共有会 |
| PFプランニング | `templates/pf-planning.md` | スプリント計画・タスク選定 |

該当テンプレートがない場合は PF定例テンプレートをベースに調整する。

## 実行手順

### 0. 文字起こしの取得（引数で渡されなかった場合）

引数に文字起こしテキストが含まれていない場合、Notion MCPとカレンダーから自動取得する。

**Step 0-1: カレンダーから会議を特定**

google-workspace Skillを参照し、今日の予定を取得:
```bash
eval "$(mise activate zsh)" && gws calendar +agenda --today
```

ユーザーが会議名を指定している場合（例: 「PF定例の議事録作って」）、カレンダーの予定から該当する会議を特定し、開催時刻を取得する。
複数候補がある場合は須藤に確認。

**Step 0-2: Notionからミーティングノートを検索**

カレンダーで特定した会議の時間帯・タイトルを使ってNotionを検索:
```
mcp__notion__notion-search(query: "<会議名やキーワード>", page_size: 5, max_highlight_length: 100)
```

検索結果のtimestampとカレンダーの開催時刻を照合し、該当するミーティングノートを特定する。

**Step 0-3: 文字起こしを取得**

特定したNotionページから文字起こしを取得:
```
mcp__notion__notion-fetch(id: "<page_id>", include_transcript: true)
```

レスポンスの `<transcript>` セクションが文字起こし本文。これを以降のステップで使用する。

---

### 1. テンプレート選択と必要情報の並列取得

会議名に基づいてテンプレートを読み込む:
```
Read(file_path: "<skill_base_dir>/templates/<対応テンプレート>.md")
```

```bash
date "+%Y-%m-%d (%a) %H:%M"
```

以下を並列で取得:

**人名対応表**（Globで最新ファイルを検索）:
```
Glob(pattern: "*人名対応表*", path: "<obsidian-notes>")
Read(file_path: "<見つかったファイル>")
```

**ドメイン用語対応表**（Globで最新ファイルを検索）:
```
Glob(pattern: "*ドメイン用語対応表*", path: "<obsidian-notes>")
Read(file_path: "<見つかったファイル>")
```

**Linearプロジェクト一覧**:
```
ToolSearch(query: "+linear projects cycles issues")
```
→ mcp__linear-server__list_projects(team: "<チーム名>")
※ プロジェクトのLeadが各プロジェクトの担当者を示す
※ チーム名は引数の会議情報から推定（PF定例→Platform等）

**current cycleの全Issue**:
```
mcp__linear-server__list_cycles(teamId: "<TEAM_ID>", type: "current")
# TEAM_IDは ~/.claude/rules/service-environments.local.md を参照
mcp__linear-server__list_issues(team: "<チーム名>", cycle: "<取得したcycle_id>", limit: 250)
```
※ `assignee: "me"` は付けない。チーム全体のIssueが必要

**過去の同じ会議の議事録**:
```
Glob(pattern: "*<会議名>*", path: "<obsidian-notes>")
```
→ 最新2-3件を読んで表記ルールを確認

### 2. プロジェクト照合（逆引き方式）

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

**Step 4: RAGentで不足情報を補完**

Linear・ドメイン用語対応表で解決できないプロジェクトや用語がある場合、社内ナレッジベースを検索:
```
mcp__ragent__hybrid_search(query: "<不明な用語やプロジェクト名>", search_mode: "hybrid", top_k: 5)
```
- プロジェクトの背景・経緯の補完
- 不明な技術用語・社内用語の特定
- 過去の議事録や設計ドキュメントとの照合

**構成ルール**:
- Linearプロジェクトごとにセクションを作成
- 各セクションにLinearプロジェクトリンクと関連Issueを記載
- プロジェクトに紐付かない話題は「その他」セクションに

### 3. 議事録作成

**出力先**: `YYYY-MM-DD_<会議名>.md`
- 会議名は引数で指定された件名を使用（PF定例、PF施策共有会、PFプランニング等）

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
**Linear**: [プロジェクト名](https://linear.app/<org>/project/...)

（議論内容を箇条書きで整理）

**関連Issue**:
- [PF-XXX](https://linear.app/<org>/issue/PF-XXX) タイトル [Xpt]

---

### 2. 次のプロジェクト名
...

### N. その他
（プロジェクトに紐付かない話題）
```

**関連IssueのURL形式**:
- 必ず `[PF-XXX](https://linear.app/<org>/issue/PF-XXX)` 形式でLinearリンクを付与
- estimateがあれば末尾に `[Xpt]` を記載

**省略する項目**（不要なセクション）:
- サマリー（h1タイトルも不要）
- 決定事項
- ネクストアクション

### 4. 過去の議事録参照と表記ゆれ修正

議事録作成後、過去の同じ会議の議事録を参照して用語の表記を統一:

- タイトル形式を過去の議事録と統一
- 技術用語の英語表記（カタカナ→英語）
- プロジェクト固有用語の統一

### 5. Notionミーティングノートの後処理

Notion MCPから文字起こしを取得した場合（Step 0を実行した場合）、議事録作成完了後に元のミーティングノートを「処理済み」ページに移動する:
```
mcp__notion__notion-move-pages(
  page_or_database_ids: ["<取得元のNotion page_id>"],
  new_parent: { type: "page_id", page_id: "325a420d-2606-8161-818d-f7d980870775" }
)
```
※ 引数で文字起こしが渡された場合はこのステップをスキップ

### 6. ガーブル確認フェーズ

議事録作成後、以下の確認を須藤に求める:
- 意味不明な音声ガーブルを箇条書きで提示
- 推測で埋めた箇所を明示
- 人名対応表にない人物名を列挙

## 表記ルール

- 人名は人名対応表の「議事録表記」を使用
- サービス名・競合名・社内用語はドメイン用語対応表の「正式表記」を使用
- ASICSチームメンバーは `（ASICS）` を付記
- 技術用語はカタカナではなく正式名称（例: ワーカー→Worker）
- Linearリンクは日本語プロジェクト名でも動作する

## 音声認識のガーブル対応

ドメイン用語対応表を参照し、サービス名・競合名・社内用語の正式表記に変換する。
加えて、以下のような技術用語のガーブルも頻出する。Issue内容との照合で正式名称に変換すること:

| ガーブル例 | 正式名称 | 解読のヒント |
|-----------|----------|-------------|
| カニメロウサッシュ | 管理面ロール刷新 | 「かんりめんロールさっしん」の音声誤認 |
| Auto-esth | autorace | 「オートレース」の音声誤認 |
| 白リック | Public (Registry) | 「パブリック」の音声誤認 |
| メジャム | メジャー | 「メジャー」の音声誤認 |
| オープンゲア | Go アップグレード | 「ゴーアップグレード」の音声誤認 |
| スパージュ | キャッシュパージ | 「キャッシュパージ」の音声誤認 |
| ゲートウィーザー | gateway-user等 | 「ゲートウェイユーザー」の音声誤認 |
| クリスト | CREST | 「クレスト」の音声誤認 |
| ロクト | Rokt | 広告配信最適化ツール |
| アストラリア | Fastly | 「ファストリー」の音声誤認 |
| デジタルアドレス | テストアドレス | 「テストアドレス」の音声誤認 |
| 佐藤さん / ストーさん | 須藤 | 「すとう」の音声誤認。「さとう」「ストー」に化ける |

原則: ガーブルされた名称をそのまま使わず、ドメイン用語対応表・Linearプロジェクト名・Issueタイトルから正式名称を特定する。
不明な場合は須藤に確認。

## 注意事項

- 文字起こしの内容を要約しすぎない（議論の経緯が分かる程度に）
- 不明な技術用語があれば確認してから記載
- 人名が不明な場合は須藤に確認（推測禁止）
- プロジェクトLeadの情報を活用して発言者とプロジェクトの対応を推定できるが、人名対応表にない人物は推測せず確認する
