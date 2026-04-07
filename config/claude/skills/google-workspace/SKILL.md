---
name: google-workspace
description: Google Workspace操作（Gmail・Calendar・Drive・Docs・Sheets・Slides）。「メール確認」「予定教えて」「ドライブ検索」「メール送って」「スプレッドシート読んで」「ドキュメントに追記」等で起動。
user-invocable: false
allowed-tools:
  - Bash(gws:*)
---

## 前提

- `gws` コマンド（`@googleworkspace/cli`）がmiseでインストール済み
- Bash実行時は `eval "$(mise activate zsh)" &&` を前置してパスを通す

## アカウント切り替え

gwsはプロファイル切り替え機能がないため、環境変数と config dir で切り替える。
アカウント情報・GCPプロジェクト・カレンダーIDは `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照。

### 仕組み

`GOOGLE_WORKSPACE_CLI_CLIENT_ID` / `CLIENT_SECRET` がシェル環境変数として常駐している（仕事用OAuthクライアント、winticket-workspace由来）。`gws` はこの環境変数を使って仕事アカウントで認証する。

`gws-personal` は `~/.zshrc` にシェル関数として定義済み:
```bash
function gws-personal() {
  env -u GOOGLE_WORKSPACE_CLI_CLIENT_ID \
      -u GOOGLE_WORKSPACE_CLI_CLIENT_SECRET \
      GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-personal" \
      gws "$@"
}
```

- `env -u` で社内の CLIENT_ID/SECRET を除去し、`~/.config/gws-personal/client_secret.json` の個人OAuthクライアントを使わせる
- `gws-personal` は必ずこのシェル関数を使う。手動で `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` だけ設定しても、社内の CLIENT_ID/SECRET 環境変数が残り認証が壊れる

### 使い分け

| 用途 | コマンド |
|------|---------|
| Calendar（仕事予定 + 個人予定の両方） | `gws-personal calendar +agenda` |
| Calendar（NASCAカレンダーのみ） | `gws calendar +agenda --calendar '<表示名>'` |
| Gmail | `gws-personal`（仕事用は Gmail API 無効化済み） |
| Drive（個人、01_Finance等） | `gws-personal` |
| Drive（仕事） | `gws` |
| Sheets / Docs / Slides | 対象に応じて使い分け |

### 再認証

```bash
# 仕事用（CLIENT_ID/SECRET は .zshrc.local で export 済み）
gws auth login

# 個人用
gws-personal auth login
```

## コマンドパターン

### Gmail

仕事用（`gws`）は Gmail API 無効化済み（誤送信リスク対策）。Gmail は `gws-personal` のみ使用可能。

未読メール確認（まずこれを使う）:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +triage
eval "$(mise activate zsh)" && gws-personal gmail +triage --max 5 --query 'from:example@gmail.com'
eval "$(mise activate zsh)" && gws-personal gmail +triage --format table
```

メール本文を読む（+triageでIDを取得してから）:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +read --id MESSAGE_ID
eval "$(mise activate zsh)" && gws-personal gmail +read --id MESSAGE_ID --headers
eval "$(mise activate zsh)" && gws-personal gmail +read --id MESSAGE_ID --format json
```

メール送信（必ず須藤に宛先・件名・本文を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +send --to "recipient@example.com" --subject "件名" --body "本文"
```

返信（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +reply --message-id MESSAGE_ID --body "返信本文"
eval "$(mise activate zsh)" && gws-personal gmail +reply --message-id MESSAGE_ID --body "返信本文" --cc "cc@example.com"
eval "$(mise activate zsh)" && gws-personal gmail +reply --message-id MESSAGE_ID --body "下書き" --draft
```

全員に返信:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +reply-all --message-id MESSAGE_ID --body "返信本文"
```

転送（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws-personal gmail +forward --message-id MESSAGE_ID --to "forward@example.com"
eval "$(mise activate zsh)" && gws-personal gmail +forward --message-id MESSAGE_ID --to "forward@example.com" --body "FYI"
```

ラベル一覧:
```bash
eval "$(mise activate zsh)" && gws-personal gmail users labels list --params '{"userId": "me"}'
```

### Calendar

2つのアカウントにカレンダーが分散している:
- `gws`（仕事）: NASCAカレンダー（会議予定）。カレンダーIDと表示名は `${CLAUDE_SKILL_DIR}/SKILL.local.md` 参照
- `gws-personal`（個人）: NASCAカレンダー + primary カレンダー（フライト・ホテル・個人予定）

全予定を一覧するには `gws-personal` をカレンダー指定なしで使う（両方のカレンダーが返る）:
```bash
eval "$(mise activate zsh)" && gws-personal calendar +agenda --today
eval "$(mise activate zsh)" && gws-personal calendar +agenda --days 5
eval "$(mise activate zsh)" && gws-personal calendar +agenda --week --format table
```

NASCAカレンダーのみ（仕事予定だけ見たいとき）:
```bash
eval "$(mise activate zsh)" && gws calendar +agenda --today --calendar '<SKILL.local.mdのカレンダー表示名>'
eval "$(mise activate zsh)" && gws calendar +agenda --week --format table --calendar '<SKILL.local.mdのカレンダー表示名>'
eval "$(mise activate zsh)" && gws calendar +agenda --days 3 --calendar '<SKILL.local.mdのカレンダー表示名>'
```

任意の日付の予定（`+agenda` は日付指定不可のため API 直接呼び出し、`gws` のみ対応）:
```bash
eval "$(mise activate zsh)" && gws calendar events list --params '{"calendarId": "<SKILL.local.mdのカレンダーID>", "timeMin": "YYYY-MM-DDT00:00:00+09:00", "timeMax": "YYYY-MM-DDT00:00:00+09:00", "singleEvents": true, "orderBy": "startTime"}'
```

予定作成（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws calendar +insert --summary "会議名" --start "2026-03-10T10:00:00+09:00" --end "2026-03-10T11:00:00+09:00"
eval "$(mise activate zsh)" && gws calendar +insert --summary "1on1" --start "..." --end "..." --attendee "someone@example.com" --location "会議室A"
```

### Drive

ファイル検索（個人: gws-personal、仕事: gws）:
```bash
eval "$(mise activate zsh)" && gws-personal drive files list --params '{"q": "name contains '\''検索語'\''", "fields": "files(id,name,mimeType,modifiedTime)"}'
```

フォルダ内ファイル一覧:
```bash
eval "$(mise activate zsh)" && gws-personal drive files list --params '{"q": "'\''FOLDER_ID'\'' in parents and trashed=false", "fields": "files(id,name,mimeType,modifiedTime)", "orderBy": "modifiedTime desc"}'
```

マイドライブルート一覧:
```bash
eval "$(mise activate zsh)" && gws-personal drive files list --params '{"q": "'\''root'\'' in parents and trashed=false", "fields": "files(id,name,mimeType,modifiedTime)", "orderBy": "modifiedTime desc"}'
```

ファイルダウンロード（PDF等）:
```bash
eval "$(mise activate zsh)" && gws-personal drive files get --params '{"fileId": "FILE_ID", "alt": "media"}' --output /tmp/filename.pdf
```

ファイルアップロード:
```bash
eval "$(mise activate zsh)" && gws drive +upload --file /path/to/file
```

### Docs

ドキュメントにテキスト追記（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws docs +write --document DOCUMENT_ID --text "追記するテキスト"
```

ドキュメント取得:
```bash
eval "$(mise activate zsh)" && gws docs documents get --params '{"documentId": "DOCUMENT_ID"}'
```

### Sheets

スプレッドシートの値を読み取り:
```bash
eval "$(mise activate zsh)" && gws sheets +read --spreadsheet SPREADSHEET_ID --range "Sheet1!A1:D10"
eval "$(mise activate zsh)" && gws sheets +read --spreadsheet SPREADSHEET_ID --range Sheet1 --format table
```

行の追加（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws sheets +append --spreadsheet SPREADSHEET_ID --values 'Alice,100,true'
eval "$(mise activate zsh)" && gws sheets +append --spreadsheet SPREADSHEET_ID --json-values '[["a","b"],["c","d"]]'
```

既存セルの値を編集（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws sheets spreadsheets values update --params '{"spreadsheetId": "SPREADSHEET_ID", "range": "Sheet1!A1:B2", "valueInputOption": "USER_ENTERED"}' --json '{"values": [["新しい値", "100"], ["行2", "200"]]}'
```

### Slides

プレゼンテーション取得:
```bash
eval "$(mise activate zsh)" && gws slides presentations get --params '{"presentationId": "PRESENTATION_ID"}'
```

## 既知の制約

- Gmail（仕事用）: API 無効化済み（誤送信リスク対策）。Gmail は `gws-personal` のみ
- Drive書き込み不可: OAuthアプリが未検証のため、既存ファイルのリネーム・移動・削除はブロックされる（`appNotAuthorizedToFile` エラー）。gwsで新規作成したファイルのみ書き込み可能
- Drive整理が必要な場合: Google Apps Script（clasp or ブラウザ）経由で実行する。GASはアプリ検証制限を受けない
- GCPプロジェクト: `~/.claude/rules/gcp-accounts.local.md` を参照

## 注意事項

- 送信系操作（メール送信、予定作成）は必ず内容を提示して須藤の確認を取ってから実行
- 時刻はJST（+09:00）で指定
- API呼び出し時のパラメータは `--params` にJSON形式で渡す
- ヘルパーコマンド（`+triage`, `+read`, `+send`, `+reply`, `+forward`, `+agenda`, `+insert`, `+upload`, `+write`, `+append`）を優先的に使う

## Gotchas

- `+agenda` ヘルパーは `--start` オプション非対応。任意日付は `events list` API を直接使う
- OAuth同意画面にスコープ未登録だと `--scope` 指定しても反映されない。GCPコンソールで API 有効化 → スコープ追加が必要
- `gws-personal` で `--calendar` フラグを使わない。CalendarList API が呼ばれ、個人アカウントではスコープ不足（`insufficientPermissions`）になる。代わりに `+agenda` をカレンダー指定なしで実行すれば、アクセス可能な全カレンダーの予定が返る
- `gws-personal` で `events list` 等の生API呼び出しは `plasma-creek-116906` の権限エラーになる場合がある。`+agenda` 等のヘルパーコマンドを優先して使う
- `gws-personal` は必ずシェル関数を使う。`GOOGLE_WORKSPACE_CLI_CONFIG_DIR` を手動設定しても、社内の CLIENT_ID/SECRET 環境変数が残り認証が壊れる
- `~/.config/gws/client_secret.json` が存在すると、そのファイルの `project_id` がquota projectとして使われ、環境変数のOAuthクライアントと矛盾して403になる。仕事用はenv vars経由なのでこのファイルは不要
