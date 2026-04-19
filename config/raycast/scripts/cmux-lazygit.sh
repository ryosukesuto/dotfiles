#!/bin/bash
#
# Raycast Script Command: フォーカス中のcmuxペインを分割してlazygit起動
#
# 推奨ホットキー: Cmd+Shift+G
# 登録方法: Raycast → Extensions → Script Commands → Add Directory
#   → このファイルの親ディレクトリを指定
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Lazygit (cmux)
# @raycast.mode silent
# @raycast.packageName cmux
#
# Optional parameters:
# @raycast.icon 🦎
# @raycast.description Split focused cmux pane and launch lazygit in current worktree

set -euo pipefail

# PATHを補完（Raycast起動時は /usr/bin:/bin:/usr/sbin:/sbin のみの場合がある）
export PATH="/Applications/cmux.app/Contents/Resources/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/gh/github.com/ryosukesuto/dotfiles/bin:$PATH"

# cmuxソケットパスを明示（Raycastサンドボックス下でも確実に解決されるように）
export CMUX_SOCKET_PATH="${CMUX_SOCKET_PATH:-$HOME/Library/Application Support/cmux/cmux.sock}"

if ! command -v cmux &> /dev/null; then
  echo "error: cmux CLI が見つかりません" >&2
  exit 1
fi

if [[ ! -S "$CMUX_SOCKET_PATH" ]]; then
  echo "error: cmux socket が見つかりません: $CMUX_SOCKET_PATH" >&2
  echo "hint: Raycast に Full Disk Access を付与してください（システム設定 > プライバシーとセキュリティ）" >&2
  exit 1
fi

# フォーカス中のsurfaceを取得
focused_surface=$(cmux identify --no-caller | grep -o '"surface_ref"[^,]*' | grep -o 'surface:[0-9]*')

if [[ -z "$focused_surface" ]]; then
  echo "error: cmuxのフォーカス中pane取得に失敗" >&2
  exit 1
fi

# フォーカス中のペインに cmux-lazygit コマンドを送信
# ペイン内で実行されるため、CWD/CMUX_SURFACE_IDが自動で解決される
cmux send --surface "$focused_surface" "cmux-lazygit\n"
