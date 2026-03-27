---
name: google-workspace
description: Google Workspace操作（Gmail・Calendar・Drive）。「メール確認」「予定教えて」「ドライブ検索」「メール送って」等で起動。
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

`gws-personal` は `~/.zshrc` に以下の関数として定義済み:
```bash
function gws-personal() {
  GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-personal gws "$@"
}
```

新しいターミナルセッション以外では以下で代替:
```bash
eval "$(mise activate zsh)" && GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-personal gws <args>
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
eval "$(mise activate zsh)" && gws gmail users messages get --params '{"userId": "me", "id": "MESSAGE_ID"}'
```

メール送信（必ず須藤に宛先・件名・本文を確認してから実行）:
```bash
eval "$(mise activate zsh)" && gws gmail +send --to "recipient@example.com" --subject "件名" --body "本文"
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

## 既知の制約

- Drive書き込み不可: OAuthアプリが未検証のため、既存ファイルのリネーム・移動・削除はブロックされる（`appNotAuthorizedToFile` エラー）。gwsで新規作成したファイルのみ書き込み可能
- Drive整理が必要な場合: Google Apps Script（clasp or ブラウザ）経由で実行する。GASはアプリ検証制限を受けない
- GCPプロジェクト: `~/.claude/rules/service-environments.local.md` を参照（テストモード）

## 注意事項

- 送信系操作（メール送信、予定作成）は必ず内容を提示して須藤の確認を取ってから実行
- 時刻はJST（+09:00）で指定
- API呼び出し時のパラメータは `--params` にJSON形式で渡す
- ヘルパーコマンド（`+triage`, `+agenda`, `+send`, `+insert`, `+upload`）を優先的に使う

## Gotchas

- `+agenda` ヘルパーは `--start` オプション非対応。任意日付は `events list` API を直接使う
- OAuth同意画面にスコープ未登録だと `--scope` 指定しても反映されない。GCPコンソールで API 有効化 → スコープ追加が必要
