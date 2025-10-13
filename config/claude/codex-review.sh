#!/usr/bin/env bash
# Claude Code応答のリアルタイムレビュー（Codex exec使用）

set -euo pipefail

# 環境変数での設定オプション
CODEX_REVIEW_TIMEOUT="${CODEX_REVIEW_TIMEOUT:-10}"  # タイムアウト秒数（デフォルト10秒）
CODEX_REVIEW_VERBOSE="${CODEX_REVIEW_VERBOSE:-false}"  # 詳細ログ出力
CODEX_REVIEW_PLAN="${CODEX_REVIEW_PLAN:-false}"  # プラン生成を含める

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

# 詳細ログ関数
log_verbose() {
    if [[ "$CODEX_REVIEW_VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$REVIEW_LOG"
    fi
}

# 引数の検証
if [[ -z "$TRANSCRIPT_FILE" ]]; then
    echo '{"status":"error","message":"No transcript_path argument provided"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: No transcript_path argument provided"
    exit 1
fi

# "null"文字列が渡された場合のチェック
if [[ "$TRANSCRIPT_FILE" == "null" ]]; then
    echo '{"status":"error","message":"transcript_path is null"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: transcript_path is null"
    exit 1
fi

# ファイルの存在確認
if [[ ! -f "$TRANSCRIPT_FILE" ]]; then
    echo '{"status":"error","message":"Transcript file not found: '"$TRANSCRIPT_FILE"'"}' > "$REVIEW_RESULT"
    log_verbose "ERROR: Transcript file not found: $TRANSCRIPT_FILE"
    exit 1
fi

log_verbose "Starting review for: $TRANSCRIPT_FILE"

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

    log_verbose "Review completed successfully"

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

    log_verbose "ERROR: Codex exec failed with exit code $EXIT_CODE"

    # タイムアウトまたはエラー時
    if [[ $EXIT_CODE -eq 143 ]] || [[ $EXIT_CODE -eq 137 ]]; then
        # 143=SIGTERM, 137=SIGKILL（タイムアウト）
        echo '{"status":"pending","message":"Review timeout (>'${CODEX_REVIEW_TIMEOUT}'s)"}' > "$REVIEW_RESULT"
    else
        echo '{"status":"error","message":"Review failed (exit: '$EXIT_CODE')"}' > "$REVIEW_RESULT"
    fi
fi

log_verbose "Review process completed"
exit 0
