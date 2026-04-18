#!/usr/bin/env bash
set -euo pipefail

# Usage: verify-sha-pin.sh <file1.yml> [file2.yml] ...
# Verifies that all uses: in given workflow files are SHA-pinned.
# Skips: local actions (uses: ./...) and reusable workflows (uses: ./.github/...)

if [ $# -eq 0 ]; then
  echo "Usage: $0 <workflow.yml> [...]" >&2
  exit 1
fi

FAILED=0

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "SKIP (not found): $FILE" >&2
    continue
  fi

  while IFS= read -r LINE; do
    # Extract uses: value
    USES=$(echo "$LINE" | grep -oP 'uses:\s*\K\S+' || true)
    [ -z "$USES" ] && continue

    # Skip local actions and reusable workflows
    if [[ "$USES" == ./* ]]; then
      continue
    fi

    # Check SHA-pin: owner/repo@<40-char hex>
    if ! echo "$USES" | grep -qP '@[0-9a-f]{40}'; then
      echo "NOT SHA-PINNED in $FILE: uses: $USES" >&2
      FAILED=1
    fi
  done < <(grep -n 'uses:' "$FILE" || true)
done

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "ERROR: Some uses: references are not SHA-pinned." >&2
  echo "Fix: Replace tag references with SHA-pinned versions." >&2
  echo "Example: actions/checkout@<40-char-sha> # v4" >&2
  exit 1
fi

echo "OK: All uses: references are SHA-pinned."
