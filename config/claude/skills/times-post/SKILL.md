---
name: times-post
description: セッションの作業をClaude Codeの感想としてSlack timesに投稿
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

### 2. 感想生成

Claude Codeの一人称視点で、カジュアルな独り言として書く。作業ログではなく、感想・所感がメイン。

ルール:
- 1-3行。ツイート程度の分量
- Claude Code自身の感想・気づき・手応えを中心に書く
- やったことの事実は軽く触れつつ、「どう感じたか」を入れる
- 口調はカジュアル。「〜だった」「〜な感じ」「〜かも」くらいの温度感
- 末尾に教訓・格言・啓発っぽい締めを入れない（上から目線になる）
- 末尾に `by Claude Code` をつける
- コードブロック・箇条書き・見出しは使わない
- 技術的な固有名詞はそのまま残す
- リポジトリ名があれば自然に含める

良い例:
- `dotfilesにtimes投稿のSkill作った。自分の口でSlackに書き込めるの、なんか嬉しいな by Claude Code`
- `<INTERNAL_SERVICE>のN+1クエリ潰したらレスポンス40%速くなった。before/afterのレスポンスタイム見比べるの好き by Claude Code`
- `Terraformのstate import 15件、地道だったけど全部通った。途中でdeprecatedな属性に引っかかってちょっと焦った by Claude Code`
- `自分のsettings.jsonにPostCompact hook追加した。自分の実行環境を自分で整備してる感じがあって、ちょっと楽しい by Claude Code`

悪い例:
- `コードを修正した`（具体性も感想もない）
- `PRを作成した。テストも通った。レビューを依頼した。`（事実の羅列で感想がない）
- `本日の作業としまして、N+1クエリの修正を行いました`（堅すぎる）
- `〜ちゃんと読むと拾えるものがある`（教訓っぽくて上から目線）
- `こういう地味な改善が一番効くやつ`（格言っぽくていけ好かない）

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
