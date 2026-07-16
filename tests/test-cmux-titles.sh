#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SESSION_TITLE="$ROOT_DIR/bin/claude-session-title-init"
WORKSPACE_RENAME="$ROOT_DIR/bin/cmux-rename-workspace"

failures=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local context="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
      "$context" "$expected" "$actual" >&2
    failures=$((failures + 1))
  fi
}

session_title() {
  local directory="$1"

  (
    cd "$directory"
    "$SESSION_TITLE"
  ) | jq -er '.hookSpecificOutput.sessionTitle'
}

capture_workspace_rename() {
  local directory="$1"
  local socket_path="$TMP_DIR/cmux-$RANDOM.sock"
  local capture_path="$TMP_DIR/cmux-request-$RANDOM.json"
  local server_pid

  python3 - "$socket_path" "$capture_path" <<'PY' &
import socket
import sys

socket_path, capture_path = sys.argv[1:]
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(socket_path)
server.listen(1)
server.settimeout(3)

connection, _ = server.accept()
with connection, open(capture_path, "wb") as capture:
    while True:
        data = connection.recv(4096)
        if not data:
            break
        capture.write(data)

server.close()
PY
  server_pid=$!

  for _ in {1..100}; do
    [[ -S "$socket_path" ]] && break
    sleep 0.01
  done

  (
    cd "$directory"
    CMUX_SOCKET_PATH="$socket_path" \
      CMUX_WORKSPACE_ID="workspace:test" \
      "$WORKSPACE_RENAME"
  )

  wait "$server_pid"
  cat "$capture_path"
}

if [[ ! -x "$WORKSPACE_RENAME" ]]; then
  printf 'FAIL: workspace rename helper is missing or not executable: %s\n' \
    "$WORKSPACE_RENAME" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

REPO_DIR="$TMP_DIR/sample-repo"
git init -q -b main "$REPO_DIR"
git -C "$REPO_DIR" -c user.name=Test -c user.email=test@example.com \
  -c commit.gpgsign=false \
  commit -q --allow-empty -m init

assert_eq "main" "$(session_title "$REPO_DIR")" \
  "main branch stays concise"

git -C "$REPO_DIR" checkout -q -b chore/digger-plan-approval-gate
assert_eq "digger plan approval gate" "$(session_title "$REPO_DIR")" \
  "conventional prefix and separators are removed"

git -C "$REPO_DIR" checkout -q -b feature/PF-1234-digger-plan
assert_eq "PF-1234 digger plan" "$(session_title "$REPO_DIR")" \
  "issue key remains readable"

git -C "$REPO_DIR" checkout -q -b fix/this-is-a-very-long-session-title-that-keeps-going
assert_eq "this is a very long session" "$(session_title "$REPO_DIR")" \
  "long titles are shortened at a word boundary"

PLAIN_DIR="$TMP_DIR/plain-project"
mkdir "$PLAIN_DIR"
assert_eq "plain-project" "$(session_title "$PLAIN_DIR")" \
  "non-git directories fall back to the directory name"

workspace_request=$(capture_workspace_rename "$REPO_DIR")
assert_eq "workspace.rename" "$(jq -r '.method' <<<"$workspace_request")" \
  "cmux workspace rename method"
assert_eq "sample-repo" "$(jq -r '.params.title' <<<"$workspace_request")" \
  "workspace title uses the repository name"
assert_eq "workspace:test" "$(jq -r '.params.workspace_id' <<<"$workspace_request")" \
  "workspace id is forwarded"

if [[ "$failures" -ne 0 ]]; then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All cmux title tests passed\n'
