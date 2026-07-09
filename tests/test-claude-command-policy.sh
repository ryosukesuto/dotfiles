#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GUARD="$ROOT_DIR/bin/claude-guard-command-policy"

failures=0

assert_status() {
  local expected_status="$1"
  local command="$2"
  local expected_message="${3:-}"
  local payload output actual_status

  payload=$(jq -cn --arg command "$command" '{tool_name:"Bash",tool_input:{command:$command}}')

  if output=$(printf '%s' "$payload" | env -u CLAUDE_TOOL_INPUT_command "$GUARD" 2>&1); then
    actual_status=0
  else
    actual_status=$?
  fi

  if [[ "$actual_status" -ne "$expected_status" ]]; then
    printf 'FAIL: expected status %s, got %s\n  command: %s\n  output: %s\n' \
      "$expected_status" "$actual_status" "$command" "$output" >&2
    failures=$((failures + 1))
    return
  fi

  if [[ -n "$expected_message" ]] && [[ "$output" != *"$expected_message"* ]]; then
    printf 'FAIL: expected output to contain %s\n  command: %s\n  output: %s\n' \
      "$expected_message" "$command" "$output" >&2
    failures=$((failures + 1))
  fi
}

# pnpm以外のNode.jsパッケージマネージャは拒否
assert_status 2 'npx @microsoft/workiq --help' 'pnpx'
assert_status 2 'cd /tmp && npm install' 'pnpm'
assert_status 2 'env FOO=bar yarn add left-pad' 'pnpm'
assert_status 2 'corepack yarn add left-pad' 'pnpm'
assert_status 2 'command /usr/local/bin/npm ci' 'pnpm'

# pnpm系、単なる文字列検索、明示的な例外は許可
assert_status 0 'pnpx @microsoft/workiq --help'
assert_status 0 'pnpm dlx cowsay hello'
assert_status 0 "rg -n 'npx' README.md"
assert_status 0 "printf '%s\\n' 'use npx only in historical examples'"
assert_status 0 'AI_ALLOW_NON_PNPM=1 npx @microsoft/workiq --help'

# EULA・利用規約・ライセンスへの同意操作は拒否
assert_status 2 'pnpx @microsoft/workiq accept-eula' '明示承認'
assert_status 2 'tool --accept-license' '明示承認'
assert_status 2 'tool terms accept' '明示承認'
assert_status 2 'yes | pnpx tool accept-terms' '明示承認'
assert_status 2 'tool --agree-to-terms=true' '明示承認'

# 読み取り操作、同意を伴わない操作、明示承認済みの操作は許可
assert_status 0 'pnpx @microsoft/workiq --help'
assert_status 0 "rg -n 'accept-eula' README.md"
assert_status 0 "printf '%s\\n' 'accept-eula'"
assert_status 0 'pnpx @microsoft/workiq status'
assert_status 0 'AI_ALLOW_LEGAL_CONSENT=1 pnpx @microsoft/workiq accept-eula'

if [[ "$failures" -ne 0 ]]; then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All command policy guard tests passed\n'
