#!/usr/bin/env bash
set -euo pipefail

# Usage: detect-conflicts.sh <file1> [file2] ...
# For each file that already exists, creates <file>.new (empty placeholder)
# and shows a diff. Exits 0 always (caller decides how to handle conflicts).
# Does NOT auto-merge or auto-overwrite.

if [ $# -eq 0 ]; then
  echo "Usage: $0 <file1> [file2] ..." >&2
  exit 1
fi

CONFLICTS=0

for FILE in "$@"; do
  if [ -f "$FILE" ]; then
    echo "CONFLICT: $FILE already exists"
    CONFLICTS=$((CONFLICTS + 1))
    # Create placeholder for new content
    touch "${FILE}.new"
    echo "  -> Created ${FILE}.new (fill with new content, then: mv ${FILE}.new ${FILE})"
  fi
done

if [ "$CONFLICTS" -eq 0 ]; then
  echo "OK: No conflicts detected."
fi

exit 0
