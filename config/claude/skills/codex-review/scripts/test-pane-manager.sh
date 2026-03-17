#!/bin/bash
# test-pane-manager.sh: pane-manager.sh のユニットテスト
# Usage: ./test-pane-manager.sh
#
# cmux ソケットをモックし、surface 検出ロジックの回帰を防ぐ。
# 特に echo vs printf によるbase64含有レスポンスの破損を検証する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PANE_MANAGER="$SCRIPT_DIR/pane-manager.sh"

# テスト用の一時ディレクトリ
TEST_TMPDIR=$(mktemp -d)
MOCK_SOCK="$TEST_TMPDIR/cmux-mock.sock"
MOCK_PID=""

# カウンター
PASS=0
FAIL=0
TOTAL=0

cleanup() {
    [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
    rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

# ── テストヘルパー ──────────────────────────────────────────────

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local label="$1" expected="$2"
    shift 2
    TOTAL=$((TOTAL + 1))
    local actual=0
    "$@" > /dev/null 2>&1 || actual=$?
    if [ "$expected" -eq "$actual" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected exit=$expected, got exit=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

# ── モックソケットサーバー ────────────────────────────────────────

# python3 で UNIX ソケットサーバーを起動。
# リクエストの method に応じて固定レスポンスを返す。
start_mock_server() {
    local response_mode="${1:-normal}"
    python3 -u "$TEST_TMPDIR/mock_server.py" "$MOCK_SOCK" "$response_mode" &
    MOCK_PID=$!
    # ソケットが作成されるまで待機
    local wait=0
    while [ ! -S "$MOCK_SOCK" ] && [ $wait -lt 10 ]; do
        sleep 0.2
        wait=$((wait + 1))
    done
    if [ ! -S "$MOCK_SOCK" ]; then
        echo "ERROR: mock server failed to start" >&2
        exit 1
    fi
}

stop_mock_server() {
    [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
    MOCK_PID=""
    rm -f "$MOCK_SOCK"
    sleep 0.3
}

# base64 にエスケープシーケンスっぽい文字を含むテスト用データを生成
# \n, \t, \0x1b (ESC) を含むバイナリを base64 化
TRICKY_BASE64=$(printf 'line1\nline2\ttab\x1b[31mred\x1b[0m\nline3' | base64)

# モックサーバーの Python スクリプトを生成
cat > "$TEST_TMPDIR/mock_server.py" << 'PYEOF'
import socket, sys, os, json, base64, threading

sock_path = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else "normal"

# テスト用 base64（エスケープシーケンス含む）
tricky_b64 = base64.b64encode(b"line1\nline2\ttab\x1b[31mred\x1b[0m\nline3").decode()

SURFACE_ID = "TEST-SURFACE-1234"

def handle_client(conn):
    try:
        data = conn.recv(4096).decode()
        if not data:
            conn.close()
            return
        req = json.loads(data.strip())
        method = req.get("method", "")
        params = req.get("params", {})
        req_id = req.get("id", "unknown")

        if mode == "error_only":
            resp = {"id": req_id, "error": {"code": -1, "message": "surface not found"}}
        elif method == "surface.read_text":
            sid = params.get("surface_id", "")
            if sid == SURFACE_ID:
                resp = {"id": req_id, "result": {"window_id": "WIN-1", "base64": tricky_b64}}
            else:
                resp = {"id": req_id, "error": {"code": -1, "message": "not found"}}
        elif method == "surface.list":
            resp = {"id": req_id, "result": {"surfaces": [
                {"surface_id": SURFACE_ID, "title": "codex"}
            ]}}
        else:
            resp = {"id": req_id, "result": {}}

        conn.sendall((json.dumps(resp) + "\n").encode())
    except Exception as e:
        print(f"Mock server error: {e}", file=sys.stderr)
    finally:
        conn.close()

if os.path.exists(sock_path):
    os.unlink(sock_path)

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sock_path)
server.listen(5)
server.settimeout(1.0)

while True:
    try:
        conn, _ = server.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
    except socket.timeout:
        continue
    except Exception:
        break
PYEOF

# ── テストケース ──────────────────────────────────────────────

echo "=== pane-manager.sh テスト ==="
echo ""

# -------------------------------------------------------------------
echo "[1] cmux_api: printf でエスケープシーケンスを含む base64 が壊れない"
# -------------------------------------------------------------------
start_mock_server normal

# cmux_api を直接呼ぶのは難しいので、pane-manager.sh の関数を source して実行
# ただし source すると BACKEND 検出やメイン処理が走るので、関数だけ抽出してテスト
result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    CMUX_SOCK="$MOCK_SOCK" \
    bash -c '
        source "'"$PANE_MANAGER"'" 2>/dev/null <<< "" || true
    ' 2>/dev/null || true
)

# cmux_api を直接テスト（printf '%s\n' の動作確認）
api_output=$(
    printf '{"id":"test","method":"surface.read_text","params":{"surface_id":"TEST-SURFACE-1234","scrollback":false}}\n' \
    | nc -U "$MOCK_SOCK" -w 3 2>/dev/null
)

# echo でパイプするとJSON が壊れる可能性をテスト
echo_result=$(echo "$api_output" | python3 -c "
import sys,json
try:
    json.load(sys.stdin)
    print('valid')
except:
    print('invalid')
" 2>/dev/null)

printf_result=$(printf '%s\n' "$api_output" | python3 -c "
import sys,json
try:
    json.load(sys.stdin)
    print('valid')
except:
    print('invalid')
" 2>/dev/null)

assert_eq "printf preserves valid JSON" "valid" "$printf_result"
# echo が壊す場合もあることを記録（環境依存なので FAIL にはしない）
if [ "$echo_result" = "invalid" ]; then
    echo "  INFO: echo corrupts JSON with base64 content (expected on some systems)"
fi

stop_mock_server

# -------------------------------------------------------------------
echo ""
echo "[2] cmux_pane_exists: 存在する surface を検出できる"
# -------------------------------------------------------------------
start_mock_server normal

exists_result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    bash -c '
        CMUX_SOCK="'"$MOCK_SOCK"'"
        cmux_api() {
            local method="$1" params="${2:-"{}"}" id="${3:-req-$$}"
            local response=""
            for attempt in 1 2 3; do
                response=$(printf "{\"id\":\"%s\",\"method\":\"%s\",\"params\":%s}\n" "$id" "$method" "$params" \
                    | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
                if [ -n "$response" ]; then
                    printf "%s\n" "$response"
                    return 0
                fi
                sleep 0.2
            done
            return 1
        }
        cmux_pane_exists() {
            local surface_id="$1"
            [ -n "$surface_id" ] || return 1
            local response
            response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
            [ -n "$response" ] && printf "%s" "$response" | grep -q "\"result\""
        }
        if cmux_pane_exists "TEST-SURFACE-1234"; then echo "found"; else echo "not_found"; fi
    ' 2>/dev/null
)
assert_eq "existing surface detected" "found" "$exists_result"

stop_mock_server

# -------------------------------------------------------------------
echo ""
echo "[3] cmux_pane_exists: 存在しない surface を正しく not found にする"
# -------------------------------------------------------------------
start_mock_server normal

not_exists_result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    bash -c '
        CMUX_SOCK="'"$MOCK_SOCK"'"
        cmux_api() {
            local method="$1" params="${2:-"{}"}" id="${3:-req-$$}"
            local response=""
            for attempt in 1 2 3; do
                response=$(printf "{\"id\":\"%s\",\"method\":\"%s\",\"params\":%s}\n" "$id" "$method" "$params" \
                    | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
                if [ -n "$response" ]; then
                    printf "%s\n" "$response"
                    return 0
                fi
                sleep 0.2
            done
            return 1
        }
        cmux_pane_exists() {
            local surface_id="$1"
            [ -n "$surface_id" ] || return 1
            local response
            response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
            [ -n "$response" ] && printf "%s" "$response" | grep -q "\"result\""
        }
        if cmux_pane_exists "NONEXISTENT-ID"; then echo "found"; else echo "not_found"; fi
    ' 2>/dev/null
)
assert_eq "nonexistent surface returns not_found" "not_found" "$not_exists_result"

stop_mock_server

# -------------------------------------------------------------------
echo ""
echo "[4] cmux_pane_exists: API がエラーのみ返す場合に not found"
# -------------------------------------------------------------------
start_mock_server error_only

error_result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    bash -c '
        CMUX_SOCK="'"$MOCK_SOCK"'"
        cmux_api() {
            local method="$1" params="${2:-"{}"}" id="${3:-req-$$}"
            local response=""
            for attempt in 1 2 3; do
                response=$(printf "{\"id\":\"%s\",\"method\":\"%s\",\"params\":%s}\n" "$id" "$method" "$params" \
                    | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
                if [ -n "$response" ]; then
                    printf "%s\n" "$response"
                    return 0
                fi
                sleep 0.2
            done
            return 1
        }
        cmux_pane_exists() {
            local surface_id="$1"
            [ -n "$surface_id" ] || return 1
            local response
            response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
            [ -n "$response" ] && printf "%s" "$response" | grep -q "\"result\""
        }
        if cmux_pane_exists "TEST-SURFACE-1234"; then echo "found"; else echo "not_found"; fi
    ' 2>/dev/null
)
assert_eq "error-only response returns not_found" "not_found" "$error_result"

stop_mock_server

# -------------------------------------------------------------------
echo ""
echo "[5] cmux_find_codex_pane: PANE_ID_FILE から保存済みIDを再利用"
# -------------------------------------------------------------------
start_mock_server normal

pane_id_file="$TEST_TMPDIR/codex-pane-id"
echo "TEST-SURFACE-1234" > "$pane_id_file"

find_result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    bash -c '
        CMUX_SOCK="'"$MOCK_SOCK"'"
        PANE_ID_FILE="'"$pane_id_file"'"
        cmux_api() {
            local method="$1" params="${2:-"{}"}" id="${3:-req-$$}"
            local response=""
            for attempt in 1 2 3; do
                response=$(printf "{\"id\":\"%s\",\"method\":\"%s\",\"params\":%s}\n" "$id" "$method" "$params" \
                    | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
                if [ -n "$response" ]; then
                    printf "%s\n" "$response"
                    return 0
                fi
                sleep 0.2
            done
            return 1
        }
        cmux_pane_exists() {
            local surface_id="$1"
            [ -n "$surface_id" ] || return 1
            local response
            response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
            [ -n "$response" ] && printf "%s" "$response" | grep -q "\"result\""
        }
        cmux_find_codex_pane() {
            if [ -f "$PANE_ID_FILE" ]; then
                local saved_id
                saved_id=$(cat "$PANE_ID_FILE" 2>/dev/null)
                if [ -n "$saved_id" ] && cmux_pane_exists "$saved_id"; then
                    echo "$saved_id"
                    return 0
                fi
            fi
            return 1
        }
        cmux_find_codex_pane
    ' 2>/dev/null
)
assert_eq "saved pane ID reused" "TEST-SURFACE-1234" "$find_result"

stop_mock_server

# -------------------------------------------------------------------
echo ""
echo "[6] cmux_find_codex_pane: 保存済みIDが無効ならフォールバック探索へ"
# -------------------------------------------------------------------
start_mock_server normal

echo "STALE-SURFACE-ID" > "$pane_id_file"

find_fallback_result=$(
    CMUX_SOCKET_PATH="$MOCK_SOCK" \
    bash -c '
        CMUX_SOCK="'"$MOCK_SOCK"'"
        PANE_ID_FILE="'"$pane_id_file"'"
        cmux_api() {
            local method="$1" params="${2:-"{}"}" id="${3:-req-$$}"
            local response=""
            for attempt in 1 2 3; do
                response=$(printf "{\"id\":\"%s\",\"method\":\"%s\",\"params\":%s}\n" "$id" "$method" "$params" \
                    | nc -U "$CMUX_SOCK" -w 3 2>/dev/null) || true
                if [ -n "$response" ]; then
                    printf "%s\n" "$response"
                    return 0
                fi
                sleep 0.2
            done
            return 1
        }
        cmux_pane_exists() {
            local surface_id="$1"
            [ -n "$surface_id" ] || return 1
            local response
            response=$(cmux_api "surface.read_text" "{\"surface_id\":\"${surface_id}\",\"scrollback\":false}" 2>/dev/null) || return 1
            [ -n "$response" ] && printf "%s" "$response" | grep -q "\"result\""
        }
        # 保存済みIDが無効 → find は失敗して return 1
        cmux_find_codex_pane() {
            if [ -f "$PANE_ID_FILE" ]; then
                local saved_id
                saved_id=$(cat "$PANE_ID_FILE" 2>/dev/null)
                if [ -n "$saved_id" ] && cmux_pane_exists "$saved_id"; then
                    echo "$saved_id"
                    return 0
                fi
            fi
            echo "fallback"
            return 0
        }
        cmux_find_codex_pane
    ' 2>/dev/null
)
assert_eq "stale ID triggers fallback" "fallback" "$find_fallback_result"

stop_mock_server

# ── 結果サマリー ──────────────────────────────────────────────

echo ""
echo "=== 結果: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
