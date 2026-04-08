# linear-triage リファレンス

## Phase 1: PR-Issue紐づけチェック 詳細手順

### PR取得コマンド

```bash
gh pr list --author=@me --state=all --limit=50 \
  --json number,title,url,headRefName,body,state,createdAt \
  --jq '[.[] | select(.createdAt >= "YYYY-MM-DD")]'
```
（YYYY-MM-DDは1週間前の日付）

### PF-XXXX抽出対象

各PRから以下の順で `PF-XXXX` パターンを探す:
1. ブランチ名 (`headRefName`)
2. タイトル
3. body

### 分類と出力フォーマット

```
## PR-Issue紐づけ状況

紐づけ済み (N件):
- #123 タイトル → PF-XXXX

未紐づけ (N件):
- #456 タイトル ← Issue起票が必要

要確認 (N件):
- #789 タイトル ← LinearリンクあるがID不明
```

### 未紐づけPRの対応フロー

ユーザーに確認:
- 新規Issue起票 → `save_issue` でIssue作成 → `gh pr edit` でPR descriptionにIssue IDを追記
- 既存Issueを指定 → `gh pr edit` でPR descriptionにIssue IDを追記
- スキップ → 何もしない

### マージ済みPRのステータスチェック

紐づけ済みPRの中でマージ済みだがIssueがDone/Cancelledでないものを報告する。

## Phase 4: プロジェクト外Issue 提示フォーマット

```
N件目: `PF-XXXX` タイトル

- 現在: Status / Xpt
- 優先度: ○○
- Cycle: あり/なし
- 概要: （descriptionから要約）

対応: 優先度変更 / コメント追加 / プロジェクトに追加 / 現状維持
```

## Phase 2: プロジェクト横断タスク取得 出力フォーマット

MCP応答から以下のフィールドだけ抽出して整形する:

### プロジェクト別
プロジェクト名ごとに:
- identifier, title, status, priority, estimate, description(冒頭200文字), URL

### プロジェクト外
- identifier, title, status, priority, estimate, description(冒頭200文字), URL, createdAt

## Phase 5: Current Cycle取得 出力フォーマット

自分（須藤/suto）のタスクだけ抽出し、全件を以下の形式で表示:

タスク1件につき:
- identifier (PF-XXXX)
- title
- status
- priority (0=None, 1=Urgent, 2=High, 3=Normal, 4=Low)
- estimate (ポイント)
- project名
- description（冒頭200文字）
- URL

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

## healthの判断基準

- `onTrack`: デッドラインに余裕がある、ブロッカーなし
- `atRisk`: デッドラインが近い、外部依存あり、作業量に対して時間が足りない
- `offTrack`: デッドラインを超過、重大なブロッカーあり

healthの判断に迷う場合はユーザーに確認する。

## Issueリンクのルール

Issueを参照する際は必ずLinearのURLリンクを付与する:
- テーブル内: `[PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)`
- 本文中: 同上

リンクなしのIssue IDは禁止。

## PR description追記フォーマット

マージ済みPRも含めて `gh pr edit` で追記する:

```markdown

<!-- Linear -->
Linear: [PF-XXXX](https://linear.app/winticket/issue/PF-XXXX)
```

bodyの末尾に追記。既にLinearリンクがある場合は重複追記しない。
