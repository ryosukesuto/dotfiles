#!/bin/bash
# tmux-manager.sh: Codexペインの管理スクリプト
# Usage:
#   tmux-manager.sh ensure         - Codexペインを作成/確認
#   tmux-manager.sh send "msg"     - メッセージを送信
#   tmux-manager.sh wait_response  - 応答完了を待機
#   tmux-manager.sh capture [lines] - 出力をキャプチャ
#   tmux-manager.sh close          - Codexペインを閉じる

set -e

PANE_TITLE="codex-review"
PANE_BG="colour233"

# ペインIDを保存するファイル
PANE_ID_FILE="/tmp/tmux-codex-pane-$$"

# 既存のCodexペインを探す
find_codex_pane() {
    # 現在のウィンドウ内でcodexが動いているペインを探す
    tmux list-panes -F '#{pane_id} #{pane_current_command}' 2>/dev/null | \
        grep -E 'codex|node' | head -1 | awk '{print $1}'
}

# ペインが存在するか確認
pane_exists() {
    local pane_id="$1"
    [ -n "$pane_id" ] && tmux list-panes -F '#{pane_id}' 2>/dev/null | grep -q "^${pane_id}$"
}

# ensure: Codexペインを作成/確認
cmd_ensure() {
    # tmuxセッション確認
    if [ -z "$TMUX" ]; then
        echo "Error: tmuxセッション外です" >&2
        exit 1
    fi

    # 既存のCodexペインを探す
    local existing_pane=$(find_codex_pane)

    if pane_exists "$existing_pane"; then
        echo "Using existing Codex pane: $existing_pane"
        echo "$existing_pane" > "$PANE_ID_FILE"
        return 0
    fi

    # 新しいペインを作成してcodexを起動
    local new_pane=$(tmux split-window -h -p 50 -P -F '#{pane_id}' "codex")

    # 背景色を設定
    tmux select-pane -t "$new_pane" -P "bg=$PANE_BG"

    # ペインIDを保存
    echo "$new_pane" > "$PANE_ID_FILE"

    # Codexの起動を待つ
    sleep 2

    echo "Created new Codex pane: $new_pane (bg=$PANE_BG)"
    echo "Auto-started Codex in pane"
}

# send: メッセージを送信
cmd_send() {
    local message="$1"

    if [ -z "$message" ]; then
        echo "Usage: tmux-manager.sh send \"message\"" >&2
        exit 1
    fi

    # ペインIDを取得
    local pane_id=$(find_codex_pane)

    if ! pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。先に 'ensure' を実行してください。" >&2
        exit 1
    fi

    # メッセージを送信（リテラル文字列として送信）
    tmux send-keys -t "$pane_id" -l "$message"
    echo "Sent command to pane: $pane_id"

    # 少し待機してからEnterを送信（C-mを使用）
    sleep 0.2
    tmux send-keys -t "$pane_id" C-m
    echo "Sent Enter (C-m) to pane: $pane_id"
}

# capture: 出力をキャプチャ
cmd_capture() {
    local lines="${1:-100}"

    # ペインIDを取得
    local pane_id=$(find_codex_pane)

    if ! pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。" >&2
        exit 1
    fi

    # ペインの内容をキャプチャ
    tmux capture-pane -t "$pane_id" -p -S "-$lines"
}

# close: Codexペインを閉じる
cmd_close() {
    local pane_id=$(find_codex_pane)

    if pane_exists "$pane_id"; then
        tmux kill-pane -t "$pane_id"
        echo "Closed Codex pane: $pane_id"
    else
        echo "No Codex pane found"
    fi

    # 一時ファイルを削除
    rm -f "$PANE_ID_FILE"
}

# status: 状態を確認
cmd_status() {
    local pane_id=$(find_codex_pane)

    if pane_exists "$pane_id"; then
        echo "Codex pane active: $pane_id"
        return 0
    else
        echo "No Codex pane found"
        return 1
    fi
}

# wait_response: 応答完了を待機
cmd_wait_response() {
    local timeout="${1:-120}"  # デフォルト120秒
    local interval=3
    local elapsed=0

    local pane_id=$(find_codex_pane)

    if ! pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。" >&2
        exit 1
    fi

    echo "Waiting for Codex response (timeout: ${timeout}s)..." >&2

    while [ $elapsed -lt $timeout ]; do
        sleep $interval
        elapsed=$((elapsed + interval))

        # ペインの最新内容を取得
        local content=$(tmux capture-pane -t "$pane_id" -p -S -50)

        # 処理中かどうかを判定
        # "Worked for XXs" や "• esc to interrupt" があれば処理中
        if echo "$content" | grep -qE '(esc to interrupt|Thinking|Working)'; then
            echo "Still processing... (${elapsed}s)" >&2
            continue
        fi

        # "› " プロンプトが最終行付近にあれば完了
        if echo "$content" | tail -5 | grep -qE '^›'; then
            echo "Response complete (${elapsed}s)" >&2
            return 0
        fi
    done

    echo "Timeout waiting for response" >&2
    return 1
}

# メインコマンド処理
case "${1:-}" in
    ensure)
        cmd_ensure
        ;;
    send)
        shift
        cmd_send "$*"
        ;;
    capture)
        cmd_capture "${2:-100}"
        ;;
    close)
        cmd_close
        ;;
    status)
        cmd_status
        ;;
    wait_response)
        cmd_wait_response "${2:-120}"
        ;;
    *)
        echo "Usage: tmux-manager.sh {ensure|send|capture|close|status|wait_response}" >&2
        echo ""
        echo "Commands:"
        echo "  ensure           - Create/find Codex pane"
        echo "  send \"msg\"       - Send message to Codex"
        echo "  capture [n]      - Capture last n lines (default: 100)"
        echo "  close            - Close Codex pane"
        echo "  status           - Check pane status"
        echo "  wait_response [s] - Wait for response completion (default: 120s)"
        exit 1
        ;;
esac
