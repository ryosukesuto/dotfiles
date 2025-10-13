#!/usr/bin/env bash
# Codex Review Hook Wrapper
# このスクリプトはClaude CodeのStopフックから呼び出され、
# stdinからJSONを受け取り、transcript_pathを抽出してcodex-review.shを実行します

set -euo pipefail

# 環境変数の設定
export CODEX_REVIEW_VERBOSE="${CODEX_REVIEW_VERBOSE:-true}"
export CODEX_REVIEW_TIMEOUT="${CODEX_REVIEW_TIMEOUT:-30}"
export CODEX_REVIEW_PLAN="${CODEX_REVIEW_PLAN:-false}"

# ログファイルのパスとセキュアな初期化
LOG_FILE="/tmp/claude-codex-review.log"
if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"  # 所有者のみ読み書き可能
fi

# stdinからJSONを読み取り
JSON_INPUT=$(cat)

# transcript_pathを抽出（nullと空文字を除外）
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -er '.transcript_path | select(. != null and . != "")')

# 抽出に失敗した場合
if [[ $? -ne 0 ]] || [[ -z "$TRANSCRIPT_PATH" ]]; then
    echo "Error: Failed to extract transcript_path from hook input" >&2
    if [[ "$CODEX_REVIEW_VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to extract transcript_path" >> "$LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Input JSON: $JSON_INPUT" >> "$LOG_FILE"
    fi
    exit 1
fi

# ファイルの存在確認
if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    echo "Error: Transcript file not found: $TRANSCRIPT_PATH" >&2
    if [[ "$CODEX_REVIEW_VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Transcript file not found: $TRANSCRIPT_PATH" >> "$LOG_FILE"
    fi
    exit 1
fi

# codex-review.shを実行（完全非同期で即座に制御を返す）
# nohup: SIGHUP無視、サブシェル: 親プロセスからの切り離し
# stdout/stderrはログファイルに記録（トラブルシュート用）
(nohup ~/.claude/codex-review.sh "$TRANSCRIPT_PATH" </dev/null >>"$LOG_FILE" 2>&1 &)
