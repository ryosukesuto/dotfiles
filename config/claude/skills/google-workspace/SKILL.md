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

gwsはプロファイル切り替え機能がないため、`GOOGLE_WORKSPACE_CLI_CONFIG_DIR` で切り替える。

| コマンド | アカウント | GCPプロジェクト | config dir |
|---------|-----------|----------------|-----------|
| `gws` | WinTicket（会社） | <WORKSPACE_GCP_PROJECT> | `~/.config/gws/` |
| `gws-personal` | <PERSONAL_EMAIL> | <PERSONAL_GCP_PROJECT> | `~/.config/gws-personal/` |

`gws-personal` は `~/.zshrc` に関数として定義済み（自前OAuthクライアント + config dir切替）:
```bash
function gws-personal() {
  GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-personal \
  GOOGLE_WORKSPACE_CLI_CLIENT_ID="..." \
  GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="..." \
  gws "$@"
}
```

- OAuthクライアント: GCPプロジェクト `<PERSONAL_GCP_PROJECT>` で作成済み（デスクトップアプリ型）
- `client_secret.json` が `~/.config/gws-personal/` に配置済み。通常のAPI呼び出しはこれで認証される
- 環境変数 `CLIENT_ID`/`CLIENT_SECRET` は `auth login`（再認証）時に必要。通常のAPI呼び出しでは不要

新しいターミナルセッション以外では以下で代替:
```bash
eval "$(mise activate zsh)" && gws-personal <args>
```

個人用Drive（01_Finance等）へのアクセスは必ず `gws-personal` を使う。

## コマンドパターン

### Gmail

未読メール確認（まずこれを使う）:
```bash
eval "$(mise activate zsh)" && gws gmail +triage
eval "$(mise activate zsh)" && gws gmail +triage --max 5 --query 'from:example@gmail.com'
eval "$(mise activate zsh)" && gws gmail +triage --format table
```

メール本文を読む（+triageでIDを取得してから）:
```bash
eval "$(mise activate zsh)" && gws gmail +read --id MESSAGE_ID
eval "$(mise activate zsh)" && gws gmail +read --id MESSAGE_ID --headers
eval "$(mise activate zsh)" && gws gmail +read --id MESSAGE_ID --format json
```

メール送信（必ず須藤に宛先・件名・本文を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws gmail +send --to "recipient@example.com" --subject "件名" --body "本文"
```

返信（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws gmail +reply --message-id MESSAGE_ID --body "返信本文"
eval "$(mise activate zsh)" && gws gmail +reply --message-id MESSAGE_ID --body "返信本文" --cc "cc@example.com"
eval "$(mise activate zsh)" && gws gmail +reply --message-id MESSAGE_ID --body "下書き" --draft
```

全員に返信:
```bash
eval "$(mise activate zsh)" && gws gmail +reply-all --message-id MESSAGE_ID --body "返信本文"
```

転送（必ず須藤に内容を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws gmail +forward --message-id MESSAGE_ID --to "forward@example.com"
eval "$(mise activate zsh)" && gws gmail +forward --message-id MESSAGE_ID --to "forward@example.com" --body "FYI"
```

ラベル一覧:
```bash
eval "$(mise activate zsh)" && gws gmail users labels list --params '{"userId": "me"}'
```

### Calendar

デフォルトカレンダー: NASCAカレンダー（会議予定が入っている）
- カレンダーID: `<CALENDAR_ID>`
- `+agenda` ヘルパーは `--calendar` 指定で使う
- `primary` カレンダーには勤務場所（オフィス/リモート）のみ登録されている

今日の予定:
```bash
eval "$(mise activate zsh)" && gws calendar +agenda --today --calendar '<CALENDAR_DISPLAY_NAME>'
```

今週の予定:
```bash
eval "$(mise activate zsh)" && gws calendar +agenda --week --format table --calendar '<CALENDAR_DISPLAY_NAME>'
```

N日間の予定:
```bash
eval "$(mise activate zsh)" && gws calendar +agenda --days 3 --calendar '<CALENDAR_DISPLAY_NAME>'
```

任意の日付の予定（`+agenda` は日付指定不可のため API 直接呼び出し）:
```bash
eval "$(mise activate zsh)" && gws calendar events list --params '{"calendarId": "<CALENDAR_ID>", "timeMin": "YYYY-MM-DDT00:00:00+09:00", "timeMax": "YYYY-MM-DDT00:00:00+09:00", "singleEvents": true, "orderBy": "startTime"}'
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

- Drive書き込み不可: OAuthアプリが未検証のため、既存ファイルのリネーム・移動・削除はブロックされる（`appNotAuthorizedToFile` エラー）。gwsで新規作成したファイルのみ書き込み可能
- Drive整理が必要な場合: Google Apps Script（clasp or ブラウザ）経由で実行する。GASはアプリ検証制限を受けない
- GCPプロジェクト: `~/.claude/rules/service-environments.local.md` を参照（テストモード）

## 注意事項

- 送信系操作（メール送信、予定作成）は必ず内容を提示して須藤の確認を取ってから実行
- 時刻はJST（+09:00）で指定
- API呼び出し時のパラメータは `--params` にJSON形式で渡す
- ヘルパーコマンド（`+triage`, `+read`, `+send`, `+reply`, `+forward`, `+agenda`, `+insert`, `+upload`, `+write`, `+append`）を優先的に使う

## Gotchas

- `+agenda` ヘルパーは `--start` オプション非対応。任意日付は `events list` API を直接使う
- OAuth同意画面にスコープ未登録だと `--scope` 指定しても反映されない。GCPコンソールで API 有効化 → スコープ追加が必要
