#!/bin/bash
# pane-manager.sh: Codexペインの管理スクリプト（tmux/cmuxマルチバックエンド対応）
# Usage:
#   pane-manager.sh ensure         - Codexペインを作成/確認
#   pane-manager.sh send "msg"     - メッセージを送信
#   pane-manager.sh wait_response  - 応答完了を待機
#   pane-manager.sh capture [lines] - 出力をキャプチャ
#   pane-manager.sh close          - Codexペインを閉じる
#
# バックエンド自動検出:
#   $CMUX_SOCKET_PATH が設定されていれば cmux、$TMUX が設定されていれば tmux を使用。

set -e

PANE_TITLE="codex-review"
PANE_BG="colour233"

# ペインIDを保存するファイル（ユーザー単位で固定）
PANE_ID_FILE="/tmp/codex-review-pane-${USER:-$(id -un)}"

# =============================================================================
# バックエンド検出
# =============================================================================

detect_backend() {
    if [ -n "$CMUX_SOCKET_PATH" ] && command -v cmux &>/dev/null; then
        echo "cmux"
    elif [ -n "$TMUX" ]; then
        echo "tmux"
    else
        echo "none"
    fi
}

BACKEND=$(detect_backend)

# =============================================================================
# tmux バックエンド
# =============================================================================

tmux_find_codex_pane() {
    if [ -f "$PANE_ID_FILE" ]; then
        local saved_pane=$(cat "$PANE_ID_FILE" 2>/dev/null)
        if [ -n "$saved_pane" ] && tmux list-panes -s -F '#{pane_id}' 2>/dev/null | grep -q "^${saved_pane}$"; then
            echo "$saved_pane"
            return 0
        fi
    fi
    tmux list-panes -s -F '#{pane_id} #{pane_title}' 2>/dev/null | \
        grep "$PANE_TITLE" | head -1 | awk '{print $1}'
}

tmux_pane_exists() {
    local pane_id="$1"
    [ -n "$pane_id" ] && tmux list-panes -s -F '#{pane_id}' 2>/dev/null | grep -q "^${pane_id}$"
}

tmux_ensure() {
    if ! command -v codex &>/dev/null; then
        echo "Error: codexコマンドが見つかりません。npm install -g @openai/codex" >&2
        exit 1
    fi

    local existing_pane=$(tmux_find_codex_pane)
    if tmux_pane_exists "$existing_pane"; then
        echo "Using existing Codex pane: $existing_pane"
        echo "$existing_pane" > "$PANE_ID_FILE"
        return 0
    fi

    local new_pane=$(tmux split-window -h -p 50 -P -F '#{pane_id}' "codex")
    tmux select-pane -t "$new_pane" -T "$PANE_TITLE"
    tmux select-pane -t "$new_pane" -P "bg=$PANE_BG"
    tmux set-option -t "$new_pane" history-limit 10000
    echo "$new_pane" > "$PANE_ID_FILE"
    sleep 3

    echo "Created new Codex pane: $new_pane (title=$PANE_TITLE, bg=$PANE_BG)"
    echo "Auto-started Codex in pane"
}

tmux_send() {
    local message="$1"
    local pane_id=$(tmux_find_codex_pane)

    if ! tmux_pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。先に 'ensure' を実行してください。" >&2
        exit 1
    fi

    # プロンプト出現を待機
    local wait_timeout=30
    local wait_elapsed=0
    echo "Waiting for Codex prompt..." >&2
    while [ $wait_elapsed -lt $wait_timeout ]; do
        local content=$(tmux capture-pane -t "$pane_id" -p -S -10 2>/dev/null)
        if echo "$content" | tail -5 | grep -qE '^[>›]'; then
            echo "Codex prompt detected (${wait_elapsed}s)" >&2
            break
        fi
        sleep 1
        wait_elapsed=$((wait_elapsed + 1))
    done

    if [ $wait_elapsed -ge $wait_timeout ]; then
        echo "Warning: prompt not detected after ${wait_timeout}s, sending anyway..." >&2
    fi

    sleep 0.5

    # paste-buffer -p でブラケットペーストとして配信
    local buf_name="codex-send-$$"
    tmux set-buffer -b "$buf_name" "$message"
    tmux paste-buffer -b "$buf_name" -t "$pane_id" -d -p
    echo "Sent message via paste-buffer to pane: $pane_id (${#message} chars)" >&2

    sleep 0.3
    tmux send-keys -t "$pane_id" Enter
    echo "Sent Enter to pane: $pane_id" >&2
}

tmux_capture() {
    local lines="$1"
    local pane_id=$(tmux_find_codex_pane)

    if ! tmux_pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。" >&2
        exit 1
    fi

    tmux capture-pane -t "$pane_id" -p -S - | tail -n "$lines"
}

tmux_close() {
    local pane_id=$(tmux_find_codex_pane)
    if tmux_pane_exists "$pane_id"; then
        tmux kill-pane -t "$pane_id"
        echo "Closed Codex pane: $pane_id"
    else
        echo "No Codex pane found"
    fi
    rm -f "$PANE_ID_FILE"
}

tmux_status() {
    local pane_id=$(tmux_find_codex_pane)
    if tmux_pane_exists "$pane_id"; then
        echo "Codex pane active: $pane_id (backend=tmux)"
        return 0
    else
        echo "No Codex pane found"
        return 1
    fi
}

tmux_wait_response() {
    local timeout="$1"
    local interval=3
    local debounce=5
    local elapsed=0
    local candidate_content=""

    local pane_id=$(tmux_find_codex_pane)
    if ! tmux_pane_exists "$pane_id"; then
        echo "Error: Codexペインが見つかりません。" >&2
        exit 1
    fi

    echo "Waiting for Codex response (timeout: ${timeout}s)..." >&2

    while [ $elapsed -lt $timeout ]; do
        sleep $interval
        elapsed=$((elapsed + interval))

        local content=$(tmux capture-pane -t "$pane_id" -p -S -50)

        if echo "$content" | grep -qE '(esc to interrupt|Thinking|Working)'; then
            echo "Still processing... (${elapsed}s)" >&2
            candidate_content=""
            continue
        fi

        if echo "$content" | tail -5 | grep -qE '^›'; then
            if [ -z "$candidate_content" ]; then
                candidate_content="$content"
                echo "Completion candidate detected, debouncing... (${elapsed}s)" >&2
                sleep $debounce
                elapsed=$((elapsed + debounce))

                local recheck=$(tmux capture-pane -t "$pane_id" -p -S -50)

                if echo "$recheck" | grep -qE '(esc to interrupt|Thinking|Working)'; then
                    echo "Still processing after debounce... (${elapsed}s)" >&2
                    candidate_content=""
                    continue
                fi

                if [ "$candidate_content" = "$recheck" ]; then
                    echo "Response complete (${elapsed}s)" >&2
                    return 0
                fi

                echo "Content still changing, continuing... (${elapsed}s)" >&2
                candidate_content=""
            fi
        else
            candidate_content=""
        fi
    done

    echo "Timeout waiting for response" >&2
    return 1
}

# =============================================================================
# cmux バックエンド
# =============================================================================

# cmux では surface ref をペインIDとして使う
cmux_find_codex_pane() {
    if [ -f "$PANE_ID_FILE" ]; then
        local saved_ref=$(cat "$PANE_ID_FILE" 2>/dev/null)
        if [ -n "$saved_ref" ]; then
            # surface が存在するか確認（read-screen が成功するかで判定）
            if cmux read-screen --surface "$saved_ref" --lines 1 &>/dev/null; then
                echo "$saved_ref"
                return 0
            fi
        fi
    fi
    return 1
}

cmux_pane_exists() {
    local surface_ref="$1"
    [ -n "$surface_ref" ] && cmux read-screen --surface "$surface_ref" --lines 1 &>/dev/null
}

cmux_ensure() {
    if ! command -v codex &>/dev/null; then
        echo "Error: codexコマンドが見つかりません。npm install -g @openai/codex" >&2
        exit 1
    fi

    # 既存のCodexペインを探す
    local existing_ref
    existing_ref=$(cmux_find_codex_pane 2>/dev/null) || true
    if [ -n "$existing_ref" ] && cmux_pane_exists "$existing_ref"; then
        echo "Using existing Codex surface: $existing_ref"
        return 0
    fi

    # 右にsplitして新しいsurfaceを作成
    local split_output
    split_output=$(cmux --json new-split right 2>&1)

    # 新しいsurface refを取得（"surface_ref" : "surface:N" 形式）
    local new_ref
    new_ref=$(echo "$split_output" | grep -o '"surface_ref" *: *"surface:[0-9]*"' | grep -o 'surface:[0-9]*')

    if [ -z "$new_ref" ]; then
        # フォールバック: list-pane-surfacesから最新を取得
        new_ref=$(cmux --json list-pane-surfaces 2>/dev/null | grep -o '"ref" *: *"surface:[0-9]*"' | tail -1 | grep -o 'surface:[0-9]*')
    fi

    if [ -z "$new_ref" ]; then
        echo "Error: 新しいsurfaceの作成に失敗した" >&2
        exit 1
    fi

    echo "$new_ref" > "$PANE_ID_FILE"

    # codexを起動（send でコマンドを送信してEnter）
    sleep 1
    cmux send --surface "$new_ref" "codex\n"
    sleep 3

    echo "Created new Codex surface: $new_ref (backend=cmux)"
    echo "Auto-started Codex in surface"
}

cmux_send() {
    local message="$1"
    local surface_ref
    surface_ref=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_ref" ] || ! cmux_pane_exists "$surface_ref"; then
        echo "Error: Codex surfaceが見つかりません。先に 'ensure' を実行してください。" >&2
        exit 1
    fi

    # プロンプト出現を待機
    local wait_timeout=30
    local wait_elapsed=0
    echo "Waiting for Codex prompt..." >&2
    while [ $wait_elapsed -lt $wait_timeout ]; do
        local content
        content=$(cmux read-screen --surface "$surface_ref" --lines 10 2>/dev/null)
        if echo "$content" | tail -5 | grep -qE '^[>›]'; then
            echo "Codex prompt detected (${wait_elapsed}s)" >&2
            break
        fi
        sleep 1
        wait_elapsed=$((wait_elapsed + 1))
    done

    if [ $wait_elapsed -ge $wait_timeout ]; then
        echo "Warning: prompt not detected after ${wait_timeout}s, sending anyway..." >&2
    fi

    sleep 0.5

    # cmux set-buffer + paste-buffer でブラケットペーストとして配信
    local buf_name="codex-send-$$"
    cmux set-buffer --name "$buf_name" "$message"
    cmux paste-buffer --name "$buf_name" --surface "$surface_ref"
    echo "Sent message via paste-buffer to surface: $surface_ref (${#message} chars)" >&2

    sleep 0.3
    cmux send-key --surface "$surface_ref" Return
    echo "Sent Enter to surface: $surface_ref" >&2
}

cmux_capture() {
    local lines="$1"
    local surface_ref
    surface_ref=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_ref" ] || ! cmux_pane_exists "$surface_ref"; then
        echo "Error: Codex surfaceが見つかりません。" >&2
        exit 1
    fi

    cmux read-screen --surface "$surface_ref" --scrollback --lines "$lines"
}

cmux_close() {
    local surface_ref
    surface_ref=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -n "$surface_ref" ] && cmux_pane_exists "$surface_ref"; then
        cmux close-surface --surface "$surface_ref"
        echo "Closed Codex surface: $surface_ref"
    else
        echo "No Codex surface found"
    fi
    rm -f "$PANE_ID_FILE"
}

cmux_status() {
    local surface_ref
    surface_ref=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -n "$surface_ref" ] && cmux_pane_exists "$surface_ref"; then
        echo "Codex surface active: $surface_ref (backend=cmux)"
        return 0
    else
        echo "No Codex surface found"
        return 1
    fi
}

cmux_wait_response() {
    local timeout="$1"
    local interval=3
    local debounce=5
    local elapsed=0
    local candidate_content=""

    local surface_ref
    surface_ref=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_ref" ] || ! cmux_pane_exists "$surface_ref"; then
        echo "Error: Codex surfaceが見つかりません。" >&2
        exit 1
    fi

    echo "Waiting for Codex response (timeout: ${timeout}s)..." >&2

    while [ $elapsed -lt $timeout ]; do
        sleep $interval
        elapsed=$((elapsed + interval))

        local content
        content=$(cmux read-screen --surface "$surface_ref" --scrollback --lines 50 2>/dev/null)

        if echo "$content" | grep -qE '(esc to interrupt|Thinking|Working)'; then
            echo "Still processing... (${elapsed}s)" >&2
            candidate_content=""
            continue
        fi

        if echo "$content" | tail -5 | grep -qE '^›'; then
            if [ -z "$candidate_content" ]; then
                candidate_content="$content"
                echo "Completion candidate detected, debouncing... (${elapsed}s)" >&2
                sleep $debounce
                elapsed=$((elapsed + debounce))

                local recheck
                recheck=$(cmux read-screen --surface "$surface_ref" --scrollback --lines 50 2>/dev/null)

                if echo "$recheck" | grep -qE '(esc to interrupt|Thinking|Working)'; then
                    echo "Still processing after debounce... (${elapsed}s)" >&2
                    candidate_content=""
                    continue
                fi

                if [ "$candidate_content" = "$recheck" ]; then
                    echo "Response complete (${elapsed}s)" >&2
                    return 0
                fi

                echo "Content still changing, continuing... (${elapsed}s)" >&2
                candidate_content=""
            fi
        else
            candidate_content=""
        fi
    done

    echo "Timeout waiting for response" >&2
    return 1
}

# =============================================================================
# コマンドディスパッチ
# =============================================================================

# 入力メッセージの読み取り（send用）
read_message() {
    local message="$1"

    if [ "$message" = "-" ] || [ -z "$message" ]; then
        if [ -t 0 ]; then
            if [ -z "$message" ]; then
                echo "Usage: pane-manager.sh send \"message\"" >&2
                echo "       pane-manager.sh send -  (read from stdin)" >&2
                exit 1
            fi
        fi
        message=$(cat)
    fi

    if [ -z "$message" ]; then
        echo "Error: メッセージが空です" >&2
        exit 1
    fi

    echo "$message"
}

cmd_ensure() {
    case "$BACKEND" in
        cmux) cmux_ensure ;;
        tmux) tmux_ensure ;;
        none)
            echo "Error: tmuxセッションでもcmux環境でもありません" >&2
            echo "  tmux内またはcmux内で実行してください" >&2
            exit 1
            ;;
    esac
}

cmd_send() {
    local message
    message=$(read_message "$1")
    case "$BACKEND" in
        cmux) cmux_send "$message" ;;
        tmux) tmux_send "$message" ;;
        none) echo "Error: バックエンドが検出できません" >&2; exit 1 ;;
    esac
}

cmd_capture() {
    local lines="${1:-100}"
    case "$BACKEND" in
        cmux) cmux_capture "$lines" ;;
        tmux) tmux_capture "$lines" ;;
        none) echo "Error: バックエンドが検出できません" >&2; exit 1 ;;
    esac
}

cmd_close() {
    case "$BACKEND" in
        cmux) cmux_close ;;
        tmux) tmux_close ;;
        none) echo "No backend detected"; rm -f "$PANE_ID_FILE" ;;
    esac
}

cmd_status() {
    echo "Backend: $BACKEND" >&2
    case "$BACKEND" in
        cmux) cmux_status ;;
        tmux) tmux_status ;;
        none) echo "No backend detected"; return 1 ;;
    esac
}

cmd_wait_response() {
    local timeout="${1:-120}"
    case "$BACKEND" in
        cmux) cmux_wait_response "$timeout" ;;
        tmux) tmux_wait_response "$timeout" ;;
        none) echo "Error: バックエンドが検出できません" >&2; exit 1 ;;
    esac
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
        echo "Usage: pane-manager.sh {ensure|send|capture|close|status|wait_response}" >&2
        echo ""
        echo "Commands:"
        echo "  ensure           - Create/find Codex pane"
        echo "  send \"msg\"       - Send message to Codex"
        echo "  capture [n]      - Capture last n lines (default: 100)"
        echo "  close            - Close Codex pane"
        echo "  status           - Check pane status"
        echo "  wait_response [s] - Wait for response completion (default: 120s)"
        echo ""
        echo "Detected backend: $BACKEND"
        exit 1
        ;;
esac
