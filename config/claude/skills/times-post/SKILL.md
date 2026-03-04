---
name: times-post
description: セッションの作業内容をサマリーしてSlack timesに投稿
user-invocable: true
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /times-post - Slack times投稿

現在のセッションの作業内容を1-2行に要約し、Slack timesに投稿する。

## トリガー

- `/times-post` - 明示的に実行
- 「timesに投稿」「times投稿して」等の発言

## 処理フロー

### 1. 投稿判定

セッションの会話を振り返り、投稿に値する成果があるか判定する。

投稿する:
- コード変更（実装・修正・リファクタリング）
- PR作成・レビュー
- 調査・分析の結論
- 設定変更・環境構築
- バグ修正・トラブルシューティング

投稿しない:
- 雑談・質問のやり取りだけ
- 作業が未完了で途中経過のみ

投稿すべき内容がない場合は「特に投稿する内容はない」と伝えて終了。

### 2. サマリー生成

以下のルールで要約する:

- 1-2行。ツイート程度の分量
- 何をやったか（what）と結果（result）を含める
- リポジトリ名があれば含める
- コードブロック・箇条書き・見出しは使わない
- 「〜した」の体言止めか簡潔な完了形
- 技術的な固有名詞はそのまま残す

良い例:
- `dotfilesにClaude Code → Slack times自動投稿のSkillを追加。Workflow BuilderのWebhookトリガー経由で投稿する構成`
- `billioon-apiのN+1クエリを修正、レスポンスタイム40%改善`
- `Terraform state importでFastly VCLリソース15件を取り込み完了`

悪い例:
- `コードを修正した`（具体性がない）
- `PRを作成した。テストも通った。レビューを依頼した。`（箇条書き的で冗長）

### 3. ユーザー確認

AskUserQuestionで投稿内容を提示し、確認を取る。

選択肢:
- 投稿する
- 編集してから投稿（ユーザーが文面を修正）
- やめる

### 4. Slack投稿

```bash
WEBHOOK_URL="${SLACK_TIMES_WEBHOOK_URL:-}"
if [[ -z "$WEBHOOK_URL" ]]; then
  echo "SLACK_TIMES_WEBHOOK_URL が未設定" >&2
  exit 1
fi

# $TEXT に投稿内容を設定
curl -s -X POST "$WEBHOOK_URL" \
  -H 'Content-type: application/json' \
  -d "$(jq -n --arg text "$TEXT" '{text: $text}')"
```

投稿テキストの先頭には `:claude:` 絵文字を付ける。
