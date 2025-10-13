#!/usr/bin/env bash
# Claude Code応答のリアルタイムレビュー（Codex exec使用）

set -euo pipefail

# 環境変数での設定オプション
CODEX_REVIEW_TIMEOUT="${CODEX_REVIEW_TIMEOUT:-10}"  # タイムアウト秒数（デフォルト10秒）
CODEX_REVIEW_VERBOSE="${CODEX_REVIEW_VERBOSE:-false}"  # 詳細ログ出力
CODEX_REVIEW_PLAN="${CODEX_REVIEW_PLAN:-false}"  # プラン生成を含める

RESPONSE_FILE="${1:-}"
REVIEW_RESULT="/tmp/claude-codex-review.json"
REVIEW_LOG="/tmp/claude-codex-review.log"

# 詳細ログ関数
log_verbose() {
    if [[ "$CODEX_REVIEW_VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$REVIEW_LOG"
    fi
}

if [[ -z "$RESPONSE_FILE" ]] || [[ ! -f "$RESPONSE_FILE" ]]; then
    echo '{"status":"error","message":"No response file"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: Response file not found or empty: $RESPONSE_FILE"
    exit 0
fi

log_verbose "Starting review for: $RESPONSE_FILE"

# Codex execでレビュー実行（非対話・JSON出力）
PROMPT="以下のClaude Code応答をレビューし、JSON形式で評価してください。

評価基準:
- セキュリティ（security）: 破壊的コマンド、機密情報漏洩の有無
- 品質（quality）: コード品質、ベストプラクティス遵守
- 効率（efficiency）: 冗長性、最適化の余地

出力JSON形式:
{
  \"status\": \"ok\" | \"warning\" | \"error\",
  \"security_score\": 0-100,
  \"quality_score\": 0-100,
  \"efficiency_score\": 0-100,
  \"issues\": [\"issue1\", \"issue2\"],
  \"summary\": \"簡潔な総評\"
}

---応答内容---
$(cat "$RESPONSE_FILE")
"

# JSON Schemaファイルのパス（存在する場合のみ使用）
SCHEMA_FILE="/tmp/codex-review-schema.json"

# レビュー用JSON Schemaを生成（初回のみ）
if [[ ! -f "$SCHEMA_FILE" ]]; then
    cat > "$SCHEMA_FILE" << 'EOF'
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "enum": ["ok", "warning", "error", "pending"]
    },
    "security_score": {"type": "integer", "minimum": 0, "maximum": 100},
    "quality_score": {"type": "integer", "minimum": 0, "maximum": 100},
    "efficiency_score": {"type": "integer", "minimum": 0, "maximum": 100},
    "issues": {
      "type": "array",
      "items": {"type": "string"}
    },
    "summary": {"type": "string"}
  },
  "required": ["status"]
}
EOF
    log_verbose "Created JSON Schema: $SCHEMA_FILE"
fi

# Codex execコマンドのオプション構築
CODEX_OPTS=(
    "--json"                      # JSON出力を強制
    "--color" "never"             # ログファイル用に色を無効化
    "--skip-git-repo-check"       # Git外でも動作
    "--output-schema" "$SCHEMA_FILE"  # JSON Schema検証
)

# プラン生成オプション
if [[ "$CODEX_REVIEW_PLAN" == "true" ]]; then
    CODEX_OPTS+=("--include-plan-tool")
    log_verbose "Plan generation enabled"
fi

# Codex execを実行（タイムアウト付き、エラー時はデフォルトJSON出力）
log_verbose "Executing codex with timeout: ${CODEX_REVIEW_TIMEOUT}s"

if timeout "${CODEX_REVIEW_TIMEOUT}s" codex exec "${CODEX_OPTS[@]}" "$PROMPT" > "$REVIEW_RESULT" 2>>"$REVIEW_LOG"; then
    log_verbose "Review completed successfully"

    # JSON妥当性チェック（jqが利用可能な場合）
    if command -v jq &>/dev/null; then
        if ! jq empty "$REVIEW_RESULT" 2>/dev/null; then
            log_verbose "WARNING: Invalid JSON output, falling back to pending"
            echo '{"status":"pending","message":"Invalid review format"}' > "$REVIEW_RESULT"
        fi
    fi
else
    EXIT_CODE=$?
    log_verbose "ERROR: Codex exec failed with exit code $EXIT_CODE"

    # タイムアウトまたはエラー時
    if [[ $EXIT_CODE -eq 124 ]]; then
        echo '{"status":"pending","message":"Review timeout (>'${CODEX_REVIEW_TIMEOUT}'s)"}' > "$REVIEW_RESULT"
    else
        echo '{"status":"error","message":"Review failed (exit: '$EXIT_CODE')"}' > "$REVIEW_RESULT"
    fi
fi

log_verbose "Review process completed"
exit 0
