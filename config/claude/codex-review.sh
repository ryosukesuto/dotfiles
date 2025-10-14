#!/usr/bin/env bash
# Claude Code応答のリアルタイムレビュー（Codex exec使用）

set -euo pipefail

# 環境変数ファイルを読み込み（Slack Webhook URLなど）
if [[ -f "$HOME/.env.local" ]]; then
    set -a  # 自動エクスポートを有効化
    source "$HOME/.env.local"
    set +a  # 自動エクスポートを無効化
fi

# 環境変数での設定オプション
CODEX_REVIEW_TIMEOUT="${CODEX_REVIEW_TIMEOUT:-10}"  # タイムアウト秒数（デフォルト10秒）
CODEX_REVIEW_VERBOSE="${CODEX_REVIEW_VERBOSE:-false}"  # 詳細ログ出力
CODEX_REVIEW_PLAN="${CODEX_REVIEW_PLAN:-false}"  # プラン生成を含める
CODEX_REVIEW_NOTIFY="${CODEX_REVIEW_NOTIFY:-true}"  # 完了通知（デフォルト有効）

TRANSCRIPT_FILE="${1:-}"

# プロジェクトごとに異なるファイル名を生成（複数プロジェクト同時使用対応）
# ワーキングディレクトリのハッシュを使用（macOS専用）
WORKDIR_HASH=$(echo -n "$PWD" | md5 | cut -c1-8)

REVIEW_RESULT="/tmp/claude-codex-review-${WORKDIR_HASH}.json"
REVIEW_RESULT_PREV="/tmp/claude-codex-review-${WORKDIR_HASH}-prev.json"
REVIEW_LOG="/tmp/claude-codex-review-${WORKDIR_HASH}.log"

# セキュアなファイル初期化関数（シンボリックリンク攻撃対策）
secure_init_file() {
    local file="$1"

    # シンボリックリンクの場合は削除して再作成
    if [[ -L "$file" ]]; then
        echo "[WARNING] Removing symlink at $file" >&2
        rm -f "$file" 2>/dev/null || return 1
    fi

    # 既存の通常ファイルがある場合はパーミッションを修正
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        chmod 600 "$file" 2>/dev/null || return 1
        return 0
    fi

    # 新規作成（umaskを設定してatomicに作成）
    (umask 077 && : > "$file") 2>/dev/null || return 1
    chmod 600 "$file" 2>/dev/null || return 1
}

# 初期化実行
for file in "$REVIEW_RESULT" "$REVIEW_RESULT_PREV" "$REVIEW_LOG"; do
    if ! secure_init_file "$file"; then
        echo '{"status":"error","message":"Failed to initialize secure file: '"$file"'"}' >&2
        exit 1
    fi
done

# ログ関数（常に出力）
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$REVIEW_LOG"
}

# 詳細ログ関数（verbose時のみ）
log_verbose() {
    if [[ "$CODEX_REVIEW_VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $*" >> "$REVIEW_LOG"
    fi
}

# macOS通知センターへの通知送信（シンプル版）
send_notification() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"  # デフォルトサウンド

    # 通知が無効な場合はスキップ
    if [[ "$CODEX_REVIEW_NOTIFY" != "true" ]]; then
        log_verbose "Notification skipped (CODEX_REVIEW_NOTIFY=$CODEX_REVIEW_NOTIFY)"
        return 0
    fi

    # macOS通知を送信（改行対応のためヒアドキュメント使用）
    if ! osascript <<EOF 2>/dev/null
display notification "$message" with title "$title" sound name "$sound"
EOF
    then
        log_verbose "WARNING: Failed to send notification"
        return 0
    fi

    log_verbose "Notification sent: $title - $message"
}

# Slack通知送信
send_slack_notification() {
    local status_emoji="$1"
    local avg_score="$2"
    local sec_score="$3"
    local qual_score="$4"
    local eff_score="$5"
    local summary="$6"
    local issues="$7"
    local repo_info="$8"

    # Webhook URLが設定されていない場合はスキップ
    if [[ -z "$CODEX_REVIEW_SLACK_WEBHOOK" ]]; then
        log_verbose "Slack notification skipped (CODEX_REVIEW_SLACK_WEBHOOK not set)"
        return 0
    fi

    # Issuesを整形（最大5個）
    local issues_text=""
    if [[ -n "$issues" ]]; then
        local count=0
        while IFS= read -r issue && [[ $count -lt 5 ]]; do
            # 実際の改行文字を使用
            issues_text="${issues_text}• ${issue}"$'\n'
            count=$((count + 1))
        done <<< "$issues"
    fi

    # jqを使ってJSONペイロードを安全に構築（自動エスケープ）
    local text_header="${status_emoji} Codex Review完了"
    local text_repo="📁 *${repo_info}*"
    # $'...' 形式で改行を実際の改行文字として扱う
    local text_score=$'*総合スコア*\n*'"${avg_score}"$'*/100'
    local text_details=$'*詳細*\n🔒 Security: '"${sec_score}"$'\n💎 Quality: '"${qual_score}"$'\n⚡ Efficiency: '"${eff_score}"

    # 基本ブロック（ヘッダー、リポジトリ、スコア）
    local slack_payload
    slack_payload=$(jq -n \
        --arg text "$text_header" \
        --arg repo "$text_repo" \
        --arg score "$text_score" \
        --arg details "$text_details" \
        '{
            "text": $text,
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": $text
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": $repo
                        }
                    ]
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": $score
                        },
                        {
                            "type": "mrkdwn",
                            "text": $details
                        }
                    ]
                }
            ]
        }')

    # サマリーブロックを追加（存在する場合）
    if [[ -n "$summary" ]]; then
        # $'...' 形式で改行を実際の改行文字として扱う
        local text_summary=$'*サマリー*\n'"${summary}"
        slack_payload=$(echo "$slack_payload" | jq \
            --arg summary "$text_summary" \
            '.blocks += [{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": $summary
                }
            }]')
    fi

    # Issuesブロックを追加（存在する場合）
    if [[ -n "$issues_text" ]]; then
        # $'...' 形式で改行を実際の改行文字として扱う
        local text_issues=$'*Issues*\n'"${issues_text}"
        slack_payload=$(echo "$slack_payload" | jq \
            --arg issues "$text_issues" \
            '.blocks += [{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": $issues
                }
            }]')
    fi

    # JSON妥当性検証（ペイロード破損の早期検出）
    if ! echo "$slack_payload" | jq empty 2>/dev/null; then
        log_message "ERROR: Invalid JSON payload generated, skipping Slack notification"
        log_verbose "Payload preview: ${slack_payload:0:200}..."
        return 1
    fi

    # Slackに送信（詳細エラーログ付き）
    local response
    local http_code
    response=$(curl -X POST -H 'Content-type: application/json' \
        --data "$slack_payload" \
        "$CODEX_REVIEW_SLACK_WEBHOOK" \
        --write-out "\n%{http_code}" \
        --silent --show-error \
        --max-time 5 2>&1)

    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" == "200" ]]; then
        log_message "Slack notification sent successfully (HTTP 200)"
    else
        log_message "WARNING: Slack notification failed (HTTP ${http_code})"
        log_verbose "Response: $(echo "$response" | head -n-1)"
    fi
}

# 引数の検証
if [[ -z "$TRANSCRIPT_FILE" ]]; then
    echo '{"status":"error","message":"No transcript_path argument provided"}' > "$REVIEW_RESULT"
    log_message "ERROR: No transcript_path argument provided"
    exit 1
fi

# "null"文字列が渡された場合のチェック
if [[ "$TRANSCRIPT_FILE" == "null" ]]; then
    echo '{"status":"error","message":"transcript_path is null"}' > "$REVIEW_RESULT"
    log_message "ERROR: transcript_path is null"
    exit 1
fi

# ファイルの存在確認
if [[ ! -f "$TRANSCRIPT_FILE" ]]; then
    echo '{"status":"error","message":"Transcript file not found: '"$TRANSCRIPT_FILE"'"}' > "$REVIEW_RESULT"
    log_message "ERROR: Transcript file not found: $TRANSCRIPT_FILE"
    exit 1
fi

log_message "Starting review for: $TRANSCRIPT_FILE"

# ============================================================================
# トランスクリプトファイルの新しさチェック（複数セッション対策）
# ============================================================================

# ファイルの最終更新時刻を取得（Unix timestamp）
FILE_MTIME=$(stat -f "%m" "$TRANSCRIPT_FILE" 2>/dev/null || echo "0")
CURRENT_TIME=$(date +%s)
AGE_SECONDS=$((CURRENT_TIME - FILE_MTIME))

# 5分（300秒）以上古い場合は警告
if [[ $AGE_SECONDS -gt 300 ]]; then
    log_message "WARNING: Transcript file is $((AGE_SECONDS / 60)) minutes old"

    # 同じプロジェクトディレクトリ内の最新ファイルを検索
    PROJECT_DIR=$(dirname "$TRANSCRIPT_FILE")
    LATEST_FILE=$(find "$PROJECT_DIR" -name "*.jsonl" -type f -print0 2>/dev/null | \
        xargs -0 stat -f "%m %N" 2>/dev/null | \
        sort -rn | \
        head -1 | \
        cut -d' ' -f2-)

    if [[ -n "$LATEST_FILE" ]] && [[ "$LATEST_FILE" != "$TRANSCRIPT_FILE" ]]; then
        LATEST_MTIME=$(stat -f "%m" "$LATEST_FILE" 2>/dev/null || echo "0")
        LATEST_AGE_SECONDS=$((CURRENT_TIME - LATEST_MTIME))

        # より新しいファイルが見つかった場合
        if [[ $LATEST_MTIME -gt $FILE_MTIME ]]; then
            log_message "Found newer transcript: $(basename "$LATEST_FILE") ($((LATEST_AGE_SECONDS / 60)) minutes old)"
            log_message "Switching from: $(basename "$TRANSCRIPT_FILE")"
            TRANSCRIPT_FILE="$LATEST_FILE"

            # 切り替え後の警告（ユーザーに通知）
            log_verbose "Auto-switched to newer transcript file"
        fi
    fi
fi

# JSONL形式のトランスクリプトから最新のアシスタント応答を抽出
# 構造: {"type":"assistant", "message": {"content": [{"type":"text","text":"..."}]}}
# パイプラインを分割してgrepの失敗を確実に検知
ASSISTANT_LINES=$(grep '"type":"assistant"' "$TRANSCRIPT_FILE" 2>/dev/null || echo "")
if [[ -z "$ASSISTANT_LINES" ]]; then
    echo '{"status":"error","message":"No assistant response found"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: No assistant response with type in transcript"
    exit 0
fi

# 最後のアシスタント応答行を取得
ASSISTANT_LINE=$(echo "$ASSISTANT_LINES" | tail -1)
if [[ -z "$ASSISTANT_LINE" ]]; then
    echo '{"status":"error","message":"No assistant response line"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: Empty assistant line after tail"
    exit 0
fi

# message.contentが存在しない/配列でないケースに対応（// []でフォールバック）
LATEST_RESPONSE=$(echo "$ASSISTANT_LINE" | jq -r '(.message.content // []) | map(select(.type == "text") | .text) | join(" ")' 2>/dev/null || echo "")

if [[ -z "$LATEST_RESPONSE" ]]; then
    echo '{"status":"error","message":"No assistant text content found"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: No assistant response with text content in transcript"
    exit 0
fi

log_verbose "Extracted latest assistant response (${#LATEST_RESPONSE} chars)"

# ============================================================================
# レビュー必要性の判定（スキップ条件）
# ============================================================================

# 1. 極めて短い応答のみスキップ（30文字未満かつツールなし）
# 「はい」「OK」「承知しました」などの確認応答のみをスキップ
if [[ ${#LATEST_RESPONSE} -lt 30 ]] && ! echo "$LATEST_RESPONSE" | grep -q '<function_calls>'; then
    log_message "Review skipped: Very short response (${#LATEST_RESPONSE} chars)"
    echo '{"status":"skipped","message":"Very short response"}' > "$REVIEW_RESULT"
    exit 0
fi

# 2. ツール呼び出しのみの応答はスキップ
# <function_calls>タグの前後にあるテキストが50バイト未満ならスキップ（日本語対応）
if echo "$LATEST_RESPONSE" | grep -q '<function_calls>'; then
    # タグより前の行のみを取得（タグを含む行は除外）
    TEXT_BEFORE=$(echo "$LATEST_RESPONSE" | sed '/<function_calls>/,$d' | tr -d '[:space:]')
    # タグより後の行のみを取得（タグを含む行は除外）
    TEXT_AFTER=$(echo "$LATEST_RESPONSE" | sed '1,/<\/function_calls>/d' | tr -d '[:space:]')

    # バイト数でカウント（日本語対応）- wc -c を使用
    BYTES_BEFORE=$(echo -n "$TEXT_BEFORE" | wc -c | tr -d ' ')
    BYTES_AFTER=$(echo -n "$TEXT_AFTER" | wc -c | tr -d ' ')
    TOTAL_TEXT_BYTES=$((BYTES_BEFORE + BYTES_AFTER))

    if [[ $TOTAL_TEXT_BYTES -lt 50 ]]; then
        log_message "Review skipped: Tool use only response (text: $TOTAL_TEXT_BYTES bytes)"
        echo '{"status":"skipped","message":"Tool use only"}' > "$REVIEW_RESULT"
        exit 0
    fi
fi

# ============================================================================
# 会話履歴の抽出（文脈理解のため）
# ============================================================================

# 最近の5ターン（user/assistant各5件）を抽出
# JSONL形式なので各行を個別に処理
CONVERSATION_CONTEXT=$(grep -E '"type":"(user|assistant)"' "$TRANSCRIPT_FILE" 2>/dev/null | tail -10 | while IFS= read -r line; do
    echo "$line" | jq -r '
        if .type == "user" then
            "User: " + ((.message.content // []) | map(select(.type == "text") | .text) | join(" ") | .[0:200])
        elif .type == "assistant" then
            "Assistant: " + ((.message.content // []) | map(select(.type == "text") | .text) | join(" ") | .[0:200])
        else
            empty
        end
    ' 2>/dev/null
done || echo "")

log_verbose "Extracted conversation context (${#CONVERSATION_CONTEXT} chars)"

# ============================================================================
# Codex execでレビュー実行（非対話・JSON出力）
# ============================================================================

PROMPT="以下のClaude Code応答をレビューし、JSON形式で評価してください。

会話履歴を参考に、文脈を理解した上でレビューしてください。

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

---会話履歴（最近5ターン）---
$CONVERSATION_CONTEXT

---最新の応答（レビュー対象）---
$LATEST_RESPONSE
"

# Codex execコマンドのオプション構築
CODEX_OPTS=(
    "--json"                      # JSONL出力を強制
    "--color" "never"             # ログファイル用に色を無効化
    "--skip-git-repo-check"       # Git外でも動作
)

# プラン生成オプション（現在のcodex CLIではサポート外）
# if [[ "$CODEX_REVIEW_PLAN" == "true" ]]; then
#     CODEX_OPTS+=("--include-plan-tool")
#     log_verbose "Plan generation enabled"
# fi

# Codex execを実行（タイムアウト付き、エラー時はデフォルトJSON出力）
log_verbose "Executing codex with timeout: ${CODEX_REVIEW_TIMEOUT}s"

# JSONL出力を一時ファイルに保存
JSONL_OUTPUT="/tmp/codex-review-jsonl.txt"

# スクリプト終了時にwatcherを確実にクリーンアップ（ゾンビ対策）
cleanup_watcher() {
    if [[ -n "$WATCHER_PID" ]] && kill -0 "$WATCHER_PID" 2>/dev/null; then
        # 段階的なシグナル送出：TERM（正常終了要求）→ KILL（強制終了）
        kill -TERM "$WATCHER_PID" 2>/dev/null
        sleep 0.5
        # まだ存在する場合のみKILLを送信
        if kill -0 "$WATCHER_PID" 2>/dev/null; then
            kill -KILL "$WATCHER_PID" 2>/dev/null
        fi
        wait "$WATCHER_PID" 2>/dev/null || true
    fi
}
trap cleanup_watcher EXIT

# macOS互換のタイムアウト実装
# バックグラウンドでcodexを実行
codex exec "${CODEX_OPTS[@]}" "$PROMPT" > "$JSONL_OUTPUT" 2>>"$REVIEW_LOG" &
CODEX_PID=$!

# タイムアウト監視プロセスをバックグラウンドで起動
(
    sleep "${CODEX_REVIEW_TIMEOUT}"
    if kill -0 "$CODEX_PID" 2>/dev/null; then
        log_verbose "Timeout reached, killing codex process (PID: $CODEX_PID)"
        kill -TERM "$CODEX_PID" 2>/dev/null
        sleep 1
        kill -KILL "$CODEX_PID" 2>/dev/null
    fi
) &
WATCHER_PID=$!

# codexの完了を待つ
if wait "$CODEX_PID" 2>/dev/null; then
    EXIT_CODE=0
    # タイムアウト監視は不要になったため停止（EXITトラップで正式に回収される）
    kill -TERM "$WATCHER_PID" 2>/dev/null || true

    log_message "Review completed successfully"

    # JSONL出力から最後のアシスタントメッセージを抽出
    if command -v jq &>/dev/null && [[ -f "$JSONL_OUTPUT" ]]; then
        # codex execの出力形式: {"id":"0","msg":{"type":"agent_message","message":"<JSON文字列>"}}
        # 1. jq -c でagent_messageレコードを1行JSONとして抽出（書式非依存、複数行対応）
        # 2. tail -n 1でレコード単位で最後の1件を取得
        # 3. jq -r '.msg.message'でメッセージフィールドを抽出
        LAST_MESSAGE=$(
            jq -c 'select(.msg.type == "agent_message")' "$JSONL_OUTPUT" 2>/dev/null | tail -n 1 | jq -r '.msg.message' 2>/dev/null || true
        )

        if [[ -n "$LAST_MESSAGE" ]] && [[ "$LAST_MESSAGE" != "null" ]] && [[ "$LAST_MESSAGE" != "." ]]; then
            # 既存のレビュー結果を履歴として保存（セキュアなコピー）
            if [[ -f "$REVIEW_RESULT" ]]; then
                if cp "$REVIEW_RESULT" "$REVIEW_RESULT_PREV" 2>/dev/null; then
                    chmod 600 "$REVIEW_RESULT_PREV" 2>/dev/null || true
                    log_verbose "Saved previous review result (permissions: 600)"
                else
                    log_verbose "WARNING: Failed to save previous review result"
                fi
            fi

            # 新しい結果を書き込み（セキュアな作成）
            echo "$LAST_MESSAGE" > "$REVIEW_RESULT"
            chmod 600 "$REVIEW_RESULT" 2>/dev/null || true
            log_verbose "Extracted last assistant message (${#LAST_MESSAGE} chars)"

            # スコアと詳細情報を取得
            AVG_SCORE=$(jq -r '
                (.security_score // 0) + (.quality_score // 0) + (.efficiency_score // 0) | . / 3 | floor
            ' "$REVIEW_RESULT" 2>/dev/null || echo "0")

            SEC_SCORE=$(jq -r '.security_score // 0' "$REVIEW_RESULT" 2>/dev/null || echo "0")
            QUAL_SCORE=$(jq -r '.quality_score // 0' "$REVIEW_RESULT" 2>/dev/null || echo "0")
            EFF_SCORE=$(jq -r '.efficiency_score // 0' "$REVIEW_RESULT" 2>/dev/null || echo "0")

            STATUS=$(jq -r '.status // "unknown"' "$REVIEW_RESULT" 2>/dev/null || echo "unknown")
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_RESULT" 2>/dev/null)

            # 全Issuesを取得（Slack用）
            ISSUES_ALL=$(jq -r '.issues[]? // empty' "$REVIEW_RESULT" 2>/dev/null)

            # リポジトリ情報を取得
            REPO_NAME="unknown"
            if git rev-parse --git-dir >/dev/null 2>&1; then
                REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
                if [[ -n "$REPO_ROOT" ]]; then
                    REPO_NAME=$(basename "$REPO_ROOT")
                fi
            fi

            # 通知メッセージを構築
            if [[ "$STATUS" == "ok" || "$STATUS" == "warning" ]]; then
                status_emoji=""
                msg_text=""
                sound=""

                if [[ $AVG_SCORE -ge 80 ]]; then
                    status_emoji="✅"
                    msg_text="${AVG_SCORE}/100"
                    sound="Glass"
                elif [[ $AVG_SCORE -ge 70 ]]; then
                    status_emoji="◎"
                    msg_text="${AVG_SCORE}/100"
                    sound="default"
                elif [[ $AVG_SCORE -ge 50 ]]; then
                    status_emoji="⚠️"
                    msg_text="${AVG_SCORE}/100"
                    sound="Basso"
                else
                    status_emoji="⚠️"
                    msg_text="${AVG_SCORE}/100"
                    sound="Sosumi"
                fi

                # レビュー結果をログに記録
                log_message "Review result: ${status_emoji} ${msg_text} (Security:${SEC_SCORE} Quality:${QUAL_SCORE} Efficiency:${EFF_SCORE})"

                # macOS通知（シンプル）
                send_notification "Codex Review" "${status_emoji} ${msg_text}" "$sound"

                # Slack通知（詳細）
                send_slack_notification "$status_emoji" "$AVG_SCORE" "$SEC_SCORE" "$QUAL_SCORE" "$EFF_SCORE" "$SUMMARY" "$ISSUES_ALL" "$REPO_NAME"
            else
                send_notification "Codex Review" "⚠️ レビューエラー" "Basso"
            fi
        else
            log_verbose "WARNING: Could not extract message, falling back to pending"
            echo '{"status":"pending","message":"No valid response"}' > "$REVIEW_RESULT"
        fi

        # JSON妥当性チェック
        if ! jq empty "$REVIEW_RESULT" 2>/dev/null; then
            log_verbose "WARNING: Invalid JSON output, falling back to pending"
            echo '{"status":"pending","message":"Invalid review format"}' > "$REVIEW_RESULT"
        fi
    else
        log_verbose "WARNING: jq not available or no output, falling back to pending"
        echo '{"status":"pending","message":"Missing dependencies"}' > "$REVIEW_RESULT"
    fi
else
    EXIT_CODE=$?

    # ウォッチャープロセスをクリーンアップ（EXITトラップで正式に回収される）
    kill -TERM "$WATCHER_PID" 2>/dev/null || true

    log_message "ERROR: Codex exec failed with exit code $EXIT_CODE"

    # タイムアウトまたはエラー時
    if [[ $EXIT_CODE -eq 143 ]] || [[ $EXIT_CODE -eq 137 ]]; then
        # 143=SIGTERM, 137=SIGKILL（タイムアウト）
        echo '{"status":"pending","message":"Review timeout (>'${CODEX_REVIEW_TIMEOUT}'s)"}' > "$REVIEW_RESULT"
        log_message "Review timeout (${CODEX_REVIEW_TIMEOUT}s exceeded)"
        send_notification "Codex Review" "⏱️ タイムアウト (${CODEX_REVIEW_TIMEOUT}秒超過)" "Funk"
    else
        echo '{"status":"error","message":"Review failed (exit: '$EXIT_CODE')"}' > "$REVIEW_RESULT"
        log_message "Review failed (exit code: $EXIT_CODE)"
        send_notification "Codex Review" "❌ レビュー失敗 (終了コード: $EXIT_CODE)" "Basso"
    fi
fi

log_message "Review process completed"
exit 0
