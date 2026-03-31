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
#   $CMUX_SOCKET_PATH のソケットが存在すれば cmux、$TMUX が設定されていれば tmux を使用。
#   cmux バックエンドはソケットAPI（nc -U）で直接通信する（cmux CLIはハングするため使用しない）。

set -e

PANE_TITLE="codex-review"
PANE_BG="colour233"

# =============================================================================
# リポジトリ名の取得（ワークスペース特定に使用）
# =============================================================================

get_repo_name() {
    # git rev-parse --git-common-dir でworktree内でもメインリポジトリのパスを取得
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || true
    if [ -n "$git_common_dir" ] && [ "$git_common_dir" != ".git" ]; then
        # 絶対パスの場合: /path/to/repo/.git → /path/to/repo → repo
        dirname "$git_common_dir" | xargs basename
    elif [ -d ".git" ]; then
        basename "$PWD"
    else
        echo ""
    fi
}

REPO_NAME=$(get_repo_name)

# ペインIDを保存するファイル（リポジトリ単位で分離）
if [ -n "$REPO_NAME" ]; then
    PANE_ID_FILE="/tmp/codex-review-pane-${USER:-$(id -un)}-${REPO_NAME}"
else
    PANE_ID_FILE="/tmp/codex-review-pane-${USER:-$(id -un)}"
fi

# =============================================================================
# バックエンド検出
# =============================================================================

detect_backend() {
    local sock="${CMUX_SOCKET_PATH:-/tmp/cmux.sock}"
    if [ -S "$sock" ]; then
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
        if echo "$content" | tail -10 | grep -qE '^›'; then
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
# cmux バックエンド（ソケットAPI直接通信）
# =============================================================================
# cmux CLI はハングする問題があるため、nc -U でソケットAPIに直接通信する。

CMUX_SOCK="${CMUX_SOCKET_PATH:-/tmp/cmux.sock}"
CMUX_WS_ID="${CMUX_WORKSPACE_ID:-}"

# CMUX_WS_ID が未設定の場合、リポジトリ名からワークスペースを自動検出
cmux_resolve_workspace_id() {
    [ -n "$CMUX_WS_ID" ] && return 0
    [ -n "$REPO_NAME" ] || return 1

    local list_response
    list_response=$(cmux_api "workspace.list" "{}") || return 1

    CMUX_WS_ID=$(echo "$list_response" | python3 -c "
import sys,json
try:
    r=json.load(sys.stdin)
    repo='$REPO_NAME'
    for ws in r.get('result',{}).get('workspaces',[]):
        name=ws.get('name','') or ws.get('title','')
        wid=ws.get('workspace_id','') or ws.get('id','')
        if name == repo:
            print(wid,end='')
            break
except: pass
" 2>/dev/null)

    if [ -n "$CMUX_WS_ID" ]; then
        echo "Auto-detected workspace: $CMUX_WS_ID (repo=$REPO_NAME)" >&2
        return 0
    fi
    return 1
}

# ソケットAPIにJSON-RPCリクエストを送信し、レスポンスを返す（リトライ付き）
cmux_api() {
    local method="$1"
    local params="${2:-"{}"}"
    local id="${3:-req-$$}"
    local response=""
    local attempt
    for attempt in 1 2 3; do
        response=$(printf '{"id":"%s","method":"%s","params":%s}\n' "$id" "$method" "$params" \
            | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
        if [ -n "$response" ]; then
            printf '%s\n' "$response"
            return 0
        fi
        sleep 0.5
    done
    # 3回リトライしても空の場合は失敗を返す
    return 1
}

# surface.listをworkspace_id付きで取得
cmux_list_surfaces() {
    if [ -n "$CMUX_WS_ID" ]; then
        cmux_api "surface.list" "{\"workspace_id\":\"${CMUX_WS_ID}\"}"
    else
        cmux_api "surface.list" "{}"
    fi
}

# レスポンスからresult内のフィールドを抽出（jqなしで動作）
cmux_extract() {
    local json="$1"
    local field="$2"
    # "field":"value" or "field": "value" を抽出
    echo "$json" | grep -o "\"${field}\" *: *\"[^\"]*\"" | head -1 | sed 's/.*: *"\([^"]*\)"/\1/'
}

# surface.read_text の結果をデコードして返す（text/base64両対応）
cmux_read_screen() {
    local surface_id="$1"
    local scrollback="${2:-false}"
    local response
    response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":${scrollback}}")

    # python3でJSONをパース（base64/text両対応、grepでの不正マッチを回避）
    echo "$response" | python3 -c "
import sys,json,base64
try:
    r=json.load(sys.stdin)
    result=r.get('result',{})
    if 'base64' in result:
        print(base64.b64decode(result['base64']).decode(),end='')
    elif 'text' in result:
        print(result['text'],end='')
    else:
        print('Error: read_text response has no base64/text field',file=sys.stderr)
except Exception as e:
    print(f'Error: read_text parse failed: {e}',file=sys.stderr)
"
}

cmux_find_codex_pane() {
    # ワークスペースIDを自動検出（未設定の場合）
    cmux_resolve_workspace_id 2>/dev/null || true

    # 1. 保存済みIDがあればsurface.read_textで直接存在確認
    if [ -f "$PANE_ID_FILE" ]; then
        local saved_id
        saved_id=$(cat "$PANE_ID_FILE" 2>/dev/null)
        if [ -n "$saved_id" ] && cmux_pane_exists "$saved_id"; then
            echo "$saved_id"
            return 0
        fi
    fi

    # 2. フォールバック: surface.listからcodexが動いているsurfaceをscreen内容から探す
    local list_response
    list_response=$(cmux_list_surfaces) || true
    local surface_ids
    surface_ids=$(echo "$list_response" | python3 -c "
import sys,json
try:
    r=json.load(sys.stdin)
    for s in r.get('result',{}).get('surfaces',[]):
        print(s.get('surface_id','') or s.get('id',''))
except: pass
" 2>/dev/null)

    for sid in $surface_ids; do
        [ -n "$sid" ] || continue
        local screen
        screen=$(cmux_read_screen "$sid" false 2>/dev/null)
        # Claude Codeペインはスキップ（コード表示内のリテラルで誤検出するため先に除外）
        if echo "$screen" | grep -qE '(Opus [0-9]|Sonnet [0-9]|Haiku [0-9]|Claude Code)'; then
            continue
        fi
        # Codex固有パターンで検出
        if echo "$screen" | grep -qE '(OpenAI Codex|codex>|gpt-[0-9]+\.[0-9]|esc to interrupt)'; then
            echo "$sid" > "$PANE_ID_FILE"
            echo "$sid"
            return 0
        fi
    done

    return 1
}

cmux_pane_exists() {
    local surface_id="$1"
    [ -n "$surface_id" ] || return 1
    # surface.read_textで直接存在確認（surface.list + grepより確実）
    local response
    response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
    # printf '%s' で出力（echo だと base64 内のエスケープが解釈されてJSONが壊れる）
    [ -n "$response" ] && printf '%s' "$response" | grep -q '"result"'
}

cmux_ensure() {
    if ! command -v codex &>/dev/null; then
        echo "Error: codexコマンドが見つかりません。npm install -g @openai/codex" >&2
        exit 1
    fi

    # ワークスペースIDを自動検出（未設定の場合）
    cmux_resolve_workspace_id || true
    if [ -z "$CMUX_WS_ID" ]; then
        echo "Warning: ワークスペースを特定できませんでした。フォーカス中のワークスペースに作成します" >&2
    fi

    # 排他ロック: 並行呼び出しによる重複surface作成を防止（macOS互換）
    local lock_file="/tmp/codex-review-lock-${USER:-$(id -un)}${REPO_NAME:+-${REPO_NAME}}"
    local lock_acquired=false
    for _i in $(seq 1 10); do
        if ( set -o noclobber; echo $$ > "$lock_file" ) 2>/dev/null; then
            lock_acquired=true
            break
        fi
        # 既存ロックが古すぎる場合（30秒以上）は強制解除
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -f %m "$lock_file" 2>/dev/null || echo 0) ))
        if [ "$lock_age" -gt 30 ]; then
            rm -f "$lock_file"
            continue
        fi
        echo "Another ensure is in progress, waiting... (attempt $_i)" >&2
        sleep 1
    done
    if [ "$lock_acquired" = false ]; then
        echo "Warning: Could not acquire lock after 10 attempts, checking for existing surface" >&2
        # ロック未取得時は作成を試みず、既存surfaceの確認のみ行う
        local fallback_id
        fallback_id=$(cmux_find_codex_pane 2>/dev/null) || true
        if [ -n "$fallback_id" ] && cmux_pane_exists "$fallback_id"; then
            echo "Using existing Codex surface: $fallback_id"
            return 0
        fi
        echo "Error: ロックを取得できず、既存surfaceも見つからない" >&2
        exit 1
    fi

    # ロック取得後、先行プロセスが作成済みかもしれないので再確認
    local existing_id
    existing_id=$(cmux_find_codex_pane 2>/dev/null) || true
    if [ -n "$existing_id" ] && cmux_pane_exists "$existing_id"; then
        echo "Using existing Codex surface: $existing_id"
        rm -f "$lock_file"
        return 0
    fi

    # surface.splitはsurface作成後に消失する問題があるためpane.createを使用
    local create_params='{"direction":"right"}'
    if [ -n "$CMUX_WS_ID" ]; then
        create_params="{\"direction\":\"right\",\"workspace_id\":\"${CMUX_WS_ID}\"}"
    fi
    local create_response
    create_response=$(cmux_api "pane.create" "$create_params")

    local new_id
    new_id=$(cmux_extract "$create_response" "surface_id")

    if [ -z "$new_id" ]; then
        echo "Error: 新しいペインの作成に失敗した" >&2
        echo "Response: $create_response" >&2
        rm -f "$lock_file"
        exit 1
    fi

    echo "$new_id" > "$PANE_ID_FILE"

    # codexを起動し、プロンプト(›)が表示されるまで待機
    sleep 1
    cmux_api "surface.send_text" "{\"surface_id\":\"${new_id}\",\"text\":\"codex\\n\"}" > /dev/null

    local boot_timeout=30
    local boot_elapsed=0
    echo "Waiting for Codex to start..." >&2
    while [ $boot_elapsed -lt $boot_timeout ]; do
        sleep 2
        boot_elapsed=$((boot_elapsed + 2))
        local screen
        screen=$(cmux_read_screen "$new_id" false 2>/dev/null)
        # Codexプロンプト(›)または起動バナー(OpenAI Codex)を検出
        if echo "$screen" | grep -qE '^›|OpenAI Codex'; then
            echo "Codex started (${boot_elapsed}s)" >&2
            break
        fi
    done

    if [ $boot_elapsed -ge $boot_timeout ]; then
        echo "Warning: Codex prompt not detected after ${boot_timeout}s" >&2
    fi

    echo "Created new Codex surface: $new_id (backend=cmux-socket)"
    echo "Auto-started Codex in surface"
    rm -f "$lock_file"
}

cmux_send() {
    local message="$1"
    local surface_id
    surface_id=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_id" ] || ! cmux_pane_exists "$surface_id"; then
        echo "Error: Codex surfaceが見つかりません。先に 'ensure' を実行してください。" >&2
        exit 1
    fi

    # プロンプト出現を待機
    local wait_timeout=30
    local wait_elapsed=0
    echo "Waiting for Codex prompt..." >&2
    while [ $wait_elapsed -lt $wait_timeout ]; do
        local content
        content=$(cmux_read_screen "$surface_id" false)
        if echo "$content" | tail -10 | grep -qE '^›'; then
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

    # メッセージ内のダブルクォートとバックスラッシュをエスケープ（macOS sed互換）
    local escaped_message
    escaped_message=$(printf '%s' "$message" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read())[1:-1],end='')")

    cmux_api "surface.send_text" "{\"surface_id\":\"${surface_id}\",\"text\":\"${escaped_message}\"}" > /dev/null
    echo "Sent message to surface: $surface_id (${#message} chars)" >&2

    sleep 0.3
    cmux_api "surface.send_key" "{\"surface_id\":\"${surface_id}\",\"key\":\"enter\"}" > /dev/null
    echo "Sent Enter to surface: $surface_id" >&2
}

cmux_capture() {
    local lines="$1"
    local surface_id
    surface_id=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_id" ] || ! cmux_pane_exists "$surface_id"; then
        echo "Error: Codex surfaceが見つかりません。" >&2
        exit 1
    fi

    cmux_read_screen "$surface_id" true | tail -n "$lines"
}

cmux_close() {
    local surface_id
    surface_id=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -n "$surface_id" ] && cmux_pane_exists "$surface_id"; then
        cmux_api "surface.close" "{\"surface_id\":\"${surface_id}\"}" > /dev/null
        echo "Closed Codex surface: $surface_id"
    else
        echo "No Codex surface found"
    fi
    rm -f "$PANE_ID_FILE"
}

cmux_status() {
    local surface_id
    surface_id=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -n "$surface_id" ] && cmux_pane_exists "$surface_id"; then
        echo "Codex surface active: $surface_id (backend=cmux-socket)"
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

    local surface_id
    surface_id=$(cmux_find_codex_pane 2>/dev/null) || true

    if [ -z "$surface_id" ] || ! cmux_pane_exists "$surface_id"; then
        echo "Error: Codex surfaceが見つかりません。" >&2
        exit 1
    fi

    echo "Waiting for Codex response (timeout: ${timeout}s)..." >&2

    while [ $elapsed -lt $timeout ]; do
        sleep $interval
        elapsed=$((elapsed + interval))

        local content
        content=$(cmux_read_screen "$surface_id" true | tail -50)

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
                recheck=$(cmux_read_screen "$surface_id" true | tail -50)

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
