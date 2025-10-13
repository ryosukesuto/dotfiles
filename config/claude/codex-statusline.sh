#!/usr/bin/env bash
# Claude Code StatusLine - Codexレビュー結果の詳細表示

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
# Codexレビュー情報表示（詳細版）
# ============================================================================
get_codex_review() {
    local REVIEW_FILE="/tmp/claude-codex-review.json"

    if [[ ! -f "$REVIEW_FILE" ]]; then
        return
    fi

    local STATUS SUMMARY SEC_SCORE QUAL_SCORE EFF_SCORE AVG_SCORE ISSUES
    STATUS=$(jq -r '.status // "unknown"' "$REVIEW_FILE" 2>/dev/null)

    case "$STATUS" in
        "ok")
            SEC_SCORE=$(jq -r '.security_score // 0' "$REVIEW_FILE" 2>/dev/null)
            QUAL_SCORE=$(jq -r '.quality_score // 0' "$REVIEW_FILE" 2>/dev/null)
            EFF_SCORE=$(jq -r '.efficiency_score // 0' "$REVIEW_FILE" 2>/dev/null)
            AVG_SCORE=$(( (SEC_SCORE + QUAL_SCORE + EFF_SCORE) / 3 ))
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_FILE" 2>/dev/null)
            ISSUES=$(jq -r '.issues[]? // empty' "$REVIEW_FILE" 2>/dev/null)

            printf "${COLOR_GREEN}${COLOR_BOLD}✓ Codex Review${COLOR_RESET}\n"
            printf "  ${COLOR_DIM}Score:${COLOR_RESET} %s/100 (🔒%s 💎%s ⚡%s)\n" "$AVG_SCORE" "$SEC_SCORE" "$QUAL_SCORE" "$EFF_SCORE"
            if [[ -n "$SUMMARY" ]]; then
                printf "  ${COLOR_DIM}Summary:${COLOR_RESET} %s\n" "$SUMMARY"
            fi
            if [[ -n "$ISSUES" ]]; then
                printf "  ${COLOR_YELLOW}${COLOR_DIM}Issues:${COLOR_RESET}\n"
                while IFS= read -r issue; do
                    printf "    • %s\n" "$issue"
                done <<< "$ISSUES"
            fi
            ;;
        "warning")
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_FILE" 2>/dev/null)
            ISSUES=$(jq -r '.issues[]? // empty' "$REVIEW_FILE" 2>/dev/null)

            printf "${COLOR_YELLOW}${COLOR_BOLD}⚠ Codex Review - Warning${COLOR_RESET}\n"
            if [[ -n "$SUMMARY" ]]; then
                printf "  ${COLOR_DIM}Summary:${COLOR_RESET} %s\n" "$SUMMARY"
            fi
            if [[ -n "$ISSUES" ]]; then
                printf "  ${COLOR_YELLOW}${COLOR_DIM}Issues:${COLOR_RESET}\n"
                while IFS= read -r issue; do
                    printf "    • %s\n" "$issue"
                done <<< "$ISSUES"
            fi
            ;;
        "error")
            SUMMARY=$(jq -r '.summary // ""' "$REVIEW_FILE" 2>/dev/null)
            printf "${COLOR_RED}${COLOR_BOLD}✗ Codex Review - Error${COLOR_RESET}\n"
            if [[ -n "$SUMMARY" ]]; then
                printf "  %s\n" "$SUMMARY"
            fi
            ;;
        "pending")
            printf "${COLOR_CYAN}◐ Reviewing...${COLOR_RESET}"
            ;;
    esac
}

# ============================================================================
# ステータスライン構築
# ============================================================================
# Codexレビュー情報のみ出力
CODEX_INFO=$(get_codex_review)

if [[ -n "$CODEX_INFO" ]]; then
    printf "%b" "$CODEX_INFO"
fi
