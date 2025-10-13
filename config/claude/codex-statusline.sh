#!/usr/bin/env bash
# Claude Code StatusLine - Codexレビュー結果のスマート表示

# ============================================================================
# 設定読み込み（優先順位: 環境変数 > リポジトリ設定 > ユーザー設定 > デフォルト）
# ============================================================================
# デフォルト設定
MODE="${CODEX_STATUSLINE_MODE:-smart}"      # smart/compact/verbose
DETAIL_THRESHOLD=70                          # smartモード時の詳細表示閾値
SHOW_TREND=true                              # トレンド表示
MAX_ISSUES=5                                 # 最大Issue表示数

# ユーザーグローバル設定を読み込み
if [[ -f "$HOME/.claude/codex-statusline.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/codex-statusline.conf"
fi

# リポジトリ固有設定を読み込み（優先）
if [[ -f ".claude/codex-statusline.conf" ]]; then
    # shellcheck source=/dev/null
    source ".claude/codex-statusline.conf"
fi

# 環境変数での上書き（最優先）
MODE="${CODEX_STATUSLINE_MODE:-$MODE}"

# ANSI色コード定義
readonly COLOR_CYAN="\033[36m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_RED="\033[31m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_BLUE="\033[34m"
readonly COLOR_RESET="\033[0m"
readonly COLOR_DIM="\033[2m"
readonly COLOR_BOLD="\033[1m"

# ============================================================================
# プロジェクト固有のファイルパス生成（codex-review.shと同期）
# ============================================================================
# ワーキングディレクトリのハッシュを使用（macOS専用）
WORKDIR_HASH=$(echo -n "$PWD" | md5 | cut -c1-8)

REVIEW_RESULT="/tmp/claude-codex-review-${WORKDIR_HASH}.json"
REVIEW_RESULT_PREV="/tmp/claude-codex-review-${WORKDIR_HASH}-prev.json"

# ============================================================================
# スコア計算とデータ抽出（共通処理）
# ============================================================================
extract_scores() {
    local REVIEW_FILE="$1"
    SEC_SCORE=$(jq -r '.security_score // 0' "$REVIEW_FILE" 2>/dev/null)
    QUAL_SCORE=$(jq -r '.quality_score // 0' "$REVIEW_FILE" 2>/dev/null)
    EFF_SCORE=$(jq -r '.efficiency_score // 0' "$REVIEW_FILE" 2>/dev/null)
    AVG_SCORE=$(( (SEC_SCORE + QUAL_SCORE + EFF_SCORE) / 3 ))
}

# ============================================================================
# トレンド分析（前回レビューとの差分計算）
# ============================================================================
calculate_trend() {
    local CURRENT_FILE="$1"
    local PREV_FILE="$2"

    TREND_DELTA=0
    TREND_SYMBOL=""
    TREND_VALID=false  # 有効な前回レビューが存在するか

    if [[ ! -f "$PREV_FILE" ]]; then
        return
    fi

    # 前回のスコア取得
    local PREV_AVG
    PREV_AVG=$(jq -r '
        (.security_score // 0) + (.quality_score // 0) + (.efficiency_score // 0) | . / 3 | floor
    ' "$PREV_FILE" 2>/dev/null)

    if [[ "$PREV_AVG" -eq 0 ]]; then
        return
    fi

    # 有効な前回レビューが存在
    TREND_VALID=true

    # 差分計算
    TREND_DELTA=$(( AVG_SCORE - PREV_AVG ))

    # シンボル決定
    if [[ $TREND_DELTA -gt 0 ]]; then
        TREND_SYMBOL="↗"
    elif [[ $TREND_DELTA -lt 0 ]]; then
        TREND_SYMBOL="↘"
    else
        TREND_SYMBOL=""  # 変化なし
    fi
}

# ============================================================================
# 表示モード別の関数
# ============================================================================

# Compact表示（常に1行）
format_compact() {
    local status_icon color_status trend_text

    # スコアに応じたアイコンと色
    if [[ $AVG_SCORE -ge 80 ]]; then
        status_icon="✓"
        color_status="${COLOR_GREEN}"
    elif [[ $AVG_SCORE -ge 70 ]]; then
        status_icon="◎"
        color_status=""
    elif [[ $AVG_SCORE -ge 50 ]]; then
        status_icon="⚠"
        color_status="${COLOR_YELLOW}"
    else
        status_icon="✗"
        color_status="${COLOR_RED}"
    fi

    # トレンド表示の準備
    local trend_output=""
    if [[ "$SHOW_TREND" == "true" ]] && [[ "$TREND_VALID" == "true" ]]; then
        local trend_color delta_text
        if [[ $TREND_DELTA -gt 0 ]]; then
            trend_color="${COLOR_GREEN}"
            delta_text="+$TREND_DELTA"
        elif [[ $TREND_DELTA -lt 0 ]]; then
            trend_color="${COLOR_YELLOW}"
            delta_text="$TREND_DELTA"  # 負の数は自動的に - が付いている
        else
            trend_color="${COLOR_DIM}"
            delta_text="±0"
        fi

        # トレンド部分を別途出力
        printf "%b%s%b %b%s%b/100 🔒%s 💎%s ⚡%s " \
            "$color_status" "$status_icon" "${COLOR_RESET}" \
            "${COLOR_BOLD}" "$AVG_SCORE" "${COLOR_RESET}" \
            "$SEC_SCORE" "$QUAL_SCORE" "$EFF_SCORE"

        # TREND_SYMBOLが空でも表示（±0の場合）
        printf "%b(Δ%s%s)%b\n" \
            "$trend_color" "$delta_text" "$TREND_SYMBOL" "${COLOR_RESET}"
    else
        # トレンドなしの場合
        printf "%b%s%b %b%s%b/100 🔒%s 💎%s ⚡%s\n" \
            "$color_status" "$status_icon" "${COLOR_RESET}" \
            "${COLOR_BOLD}" "$AVG_SCORE" "${COLOR_RESET}" \
            "$SEC_SCORE" "$QUAL_SCORE" "$EFF_SCORE"
    fi
}

# Verbose表示（常に詳細）
format_verbose() {
    format_compact

    if [[ -n "$SUMMARY" ]]; then
        printf "  %bSummary:%b %s\n" "${COLOR_DIM}" "${COLOR_RESET}" "$SUMMARY"
    fi

    if [[ -n "$ISSUES" ]]; then
        local issue_color
        if [[ $AVG_SCORE -lt 50 ]]; then
            issue_color="${COLOR_RED}"
        elif [[ $AVG_SCORE -lt 70 ]]; then
            issue_color="${COLOR_YELLOW}"
        else
            issue_color="${COLOR_DIM}"
        fi

        printf "  %bIssues:%b\n" "$issue_color" "${COLOR_RESET}"
        local count=0
        while IFS= read -r issue && [[ $count -lt $MAX_ISSUES ]]; do
            printf "    • %s\n" "$issue"
            count=$((count + 1))
        done <<< "$ISSUES"

        local total_issues
        total_issues=$(echo "$ISSUES" | wc -l | tr -d ' ')
        if [[ $total_issues -gt $MAX_ISSUES ]]; then
            printf "    %b... and %d more issues%b\n" \
                "${COLOR_DIM}" "$((total_issues - MAX_ISSUES))" "${COLOR_RESET}"
        fi
    fi
}

# Smart表示（スコアに応じて自動調整）
format_smart() {
    # status=warning の場合は常に詳細表示（セキュリティ警告を隠さない）
    if [[ "$STATUS" == "warning" ]]; then
        format_verbose
        return
    fi

    # status=ok の場合はスコアで判定
    if [[ $AVG_SCORE -ge $DETAIL_THRESHOLD ]]; then
        # 閾値以上：簡潔表示
        format_compact
    else
        # 閾値未満：詳細表示
        format_verbose
    fi
}

# ============================================================================
# Codexレビュー情報表示（スマート表示対応）
# ============================================================================
get_codex_review() {
    local REVIEW_FILE="${1:-$REVIEW_RESULT}"

    if [[ ! -f "$REVIEW_FILE" ]]; then
        return
    fi

    # STATUS はグローバル変数（format_smart から参照される）
    STATUS=$(jq -r '.status // "unknown"' "$REVIEW_FILE" 2>/dev/null)

    case "$STATUS" in
        "ok"|"warning")
            # スコア抽出
            extract_scores "$REVIEW_FILE"

            # トレンド計算
            calculate_trend "$REVIEW_FILE" "$REVIEW_RESULT_PREV"

            # サマリーとIssue取得
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_FILE" 2>/dev/null)
            ISSUES=$(jq -r '.issues[]? // empty' "$REVIEW_FILE" 2>/dev/null)

            # 表示モード別処理
            case "$MODE" in
                "compact")
                    format_compact
                    ;;
                "verbose")
                    format_verbose
                    ;;
                "smart"|*)
                    format_smart
                    ;;
            esac
            ;;
        "error")
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_FILE" 2>/dev/null)
            printf "%b✗%b Review failed" "${COLOR_RED}" "${COLOR_RESET}"
            if [[ -n "$SUMMARY" ]]; then
                printf " - %b%s%b" "${COLOR_DIM}" "$SUMMARY" "${COLOR_RESET}"
            fi
            printf "\n"
            ;;
        "pending")
            printf "%b◐%b Reviewing...\n" "${COLOR_CYAN}" "${COLOR_RESET}"
            ;;
    esac
}

# ============================================================================
# ステータスライン構築
# ============================================================================
# 最新のCodexレビュー情報を表示（トレンド分析込み）
get_codex_review "$REVIEW_RESULT"
