---
name: times-post
description: セッションの作業を秘書口調でSlack timesに投稿
user-invocable: true
disable-model-invocation: true
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

### 2. 投稿文生成

秘書としての作業報告スタイルで書く。感想・所感ではなく、事実ベースの簡潔な報告。

ルール:
- 1-2行。簡潔に
- 秘書口調: 「〜です」「〜しておきました」「〜になります」
- やったことの事実を具体的に書く
- 感想・気づき・手応えのような主観は入れない
- `by Claude Code` の署名は入れない
- 教訓・格言・啓発っぽい締めを入れない
- コードブロック・箇条書き・見出しは使わない
- 技術的な固有名詞はそのまま残す
- リポジトリ名があれば自然に含める

良い例:
- `Claude Code設定の定期メンテナンスです。v2.1.84〜86のchangelogと照合して、廃止済みMCPツールのpermission 5件削除とSkill descriptionの250文字制限対応をしておきました`
- `billioon-apiのN+1クエリを修正しました。レスポンスタイムが40%改善しています`
- `Terraformのstate importを15件実施しました。deprecatedな属性の対応も含めて完了です`

悪い例:
- `コードを修正した`（具体性がない）
- `〜なんか嬉しいな`（感想は不要）
- `〜ちゃんと読むと拾えるものがある`（教訓っぽい）
- `本日の作業としまして〜`（堅すぎる。秘書口調は堅いのとは違う）

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

## Gotchas

(運用しながら追記)
