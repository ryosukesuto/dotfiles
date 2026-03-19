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
  - mcp__claude_ai_Slack__slack_search_channels
  - mcp__claude_ai_Slack__slack_read_channel
  - mcp__claude_ai_Slack__slack_search_public
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
| PF定例 | `${CLAUDE_SKILL_DIR}/templates/pf-teirei.md` | 全プロジェクト進捗報告 |
| PF施策共有会 | `${CLAUDE_SKILL_DIR}/templates/pf-shisaku-kyouyukai.md` | 技術的深掘り・共有会 |
| PFプランニング | `${CLAUDE_SKILL_DIR}/templates/pf-planning.md` | スプリント計画・タスク選定 |

該当テンプレートがない場合は PF定例テンプレートをベースに調整する。

## 実行手順

### 0. リファレンス読み込み

以下を必要時に参照する:
- `${CLAUDE_SKILL_DIR}/reference.md` — 出力フォーマット、表記ルール、ガーブル対応表
- `${CLAUDE_SKILL_DIR}/templates/` — 会議種別ごとのテンプレート

### 1. 文字起こしの取得（引数で渡されなかった場合）

google-workspace Skillでカレンダーから会議を特定し、Notionから文字起こしを取得する:

```bash
eval "$(mise activate zsh)" && gws calendar +agenda --today
```
```
mcp__notion__notion-search(query: "<会議名>", page_size: 5, max_highlight_length: 100)
mcp__notion__notion-fetch(id: "<page_id>", include_transcript: true)
```

レスポンスの `<transcript>` セクションを以降のステップで使用する。複数候補がある場合は須藤に確認。

---

### 2. テンプレート選択と必要情報の並列取得

会議名に基づいてテンプレートを読み込み、現在時刻を確認する:
```
Read(file_path: "${CLAUDE_SKILL_DIR}/templates/<対応テンプレート>.md")
date "+%Y-%m-%d (%a) %H:%M"
```

以下を並列で取得:
- 人名対応表: `Glob(pattern: "*人名対応表*")` → Read
- ドメイン用語対応表: `Glob(pattern: "*ドメイン用語対応表*")` → Read
- Linearプロジェクト一覧: `mcp__linear-server__list_projects(team: "<チーム名>")` ※ LeadがPJ担当者
- current cycleの全Issue: `mcp__linear-server__list_cycles` → `mcp__linear-server__list_issues(limit: 250)` ※ TEAM_IDは service-environments.local.md 参照、`assignee: "me"` は付けない
- 過去の同じ会議の議事録: `Glob(pattern: "*<会議名>*")` → 最新2-3件を読んで表記ルール確認
- 会議チャンネルの直近メッセージ: `mcp__claude_ai_Slack__slack_search_channels(query: "<会議名>")` → channel_id を特定して `mcp__claude_ai_Slack__slack_read_channel(limit: 30)` ※ チャンネルが見つからない場合はスキップ

### 3. プロジェクト照合（逆引き方式）

文字起こしのプロジェクト名は音声認識でガーブルされることが多い。以下の順で照合する:

1. Issue内容との逆引き: Issueタイトル・内容と議論内容を照合してプロジェクトを特定
2. プロジェクトLeadとの照合: Lead情報から発言者とプロジェクトの対応を推定
3. ガーブル名の解読: `${CLAUDE_SKILL_DIR}/reference.md` のガーブル対応表を参照
4. Slack検索で補完: Step 2 で取得した会議チャンネルの発言や `mcp__claude_ai_Slack__slack_search_public(query: "<ガーブル語句> OR <推測キーワード>")` で前後の文脈を確認
5. RAGentで補完: それでも解決できない場合は `mcp__ragent__hybrid_search(search_mode: "hybrid", top_k: 5)`

構成: Linearプロジェクトごとにセクションを作成。リンク・関連Issueを記載。紐付かない話題は「その他」へ。

### 4. 議事録作成

**出力先**: `YYYY-MM-DD_<会議名>.md`
- 会議名は引数で指定された件名を使用（PF定例、PF施策共有会、PFプランニング等）

フォーマット詳細は `${CLAUDE_SKILL_DIR}/reference.md` を参照。

### 5. 過去の議事録参照と表記ゆれ修正

議事録作成後、過去の同じ会議の議事録を参照して用語の表記を統一:

- タイトル形式を過去の議事録と統一
- 技術用語の英語表記（カタカナ→英語）
- プロジェクト固有用語の統一

### 6. Notionミーティングノートの後処理

Notion MCPから文字起こしを取得した場合（Step 0を実行した場合）、議事録作成完了後に元のミーティングノートを「処理済み」ページに移動する:
```
mcp__notion__notion-move-pages(
  page_or_database_ids: ["<取得元のNotion page_id>"],
  new_parent: { type: "page_id", page_id: "325a420d-2606-8161-818d-f7d980870775" }
)
```
※ 引数で文字起こしが渡された場合はこのステップをスキップ

### 7. ガーブル確認フェーズ

議事録作成後、以下の確認を須藤に求める:
- 意味不明な音声ガーブルを箇条書きで提示
- 推測で埋めた箇所を明示
- 人名対応表にない人物名を列挙

## 注意事項

- 文字起こしの内容を要約しすぎない（議論の経緯が分かる程度に）
- 不明な技術用語があれば確認してから記載
- 人名が不明な場合は須藤に確認（推測禁止）
- プロジェクトLeadの情報を活用して発言者とプロジェクトの対応を推定できるが、人名対応表にない人物は推測せず確認する

## Gotchas

(運用しながら追記)
