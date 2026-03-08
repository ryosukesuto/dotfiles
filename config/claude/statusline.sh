#!/bin/bash
# Claude Code status line script
# Line 1: Model | Dir/Git info | Duration | Context%
# Line 2: 5h rate limit progress bar
# Line 3: 7d rate limit progress bar
#
# Rate limit usage is fetched via Haiku probe (OAuth token from Keychain).
# This may violate Anthropic Consumer ToS Section 3(7). Use at your own risk.

input=$(cat)

# ---------- Parse stdin (single jq call) ----------
eval "$(echo "$input" | jq -r '
  "MODEL=" + (.model.display_name // "Unknown" | @sh),
  "DIR=" + (.workspace.current_dir // .cwd // "~" | @sh),
  "CONTEXT_PCT=" + (.context_window.used_percentage // 0 | tostring),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | tostring),
  "CC_VERSION=" + (.version // "0.0.0" | @sh)
' 2>/dev/null)"

DIR_NAME="${DIR##*/}"
CONTEXT_PCT=${CONTEXT_PCT%.*}

# ---------- ANSI Colors ----------
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_MAGENTA=$'\033[35m'
C_CYAN=$'\033[36m'
C_RED=$'\033[31m'
C_DIM=$'\033[2m'
# Rate limit bar colors (RGB)
RL_GREEN=$'\e[38;2;151;201;195m'
RL_YELLOW=$'\e[38;2;229;192;123m'
RL_RED=$'\e[38;2;224;108;117m'
RL_GRAY=$'\e[38;2;74;88;92m'

# ---------- Git info ----------
git_info() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return
    fi

    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        branch=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    local ahead behind sync=""
    ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null) || ahead=0
    behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null) || behind=0
    ahead=${ahead:-0}
    behind=${behind:-0}

    [ "$ahead" -gt 0 ] 2>/dev/null && sync+="${C_GREEN}↑${ahead}${C_RESET}"
    [ "$behind" -gt 0 ] 2>/dev/null && sync+="${C_RED}↓${behind}${C_RESET}"

    local git_status modified=0 staged=0 untracked=0 deleted=0
    git_status=$(git status --porcelain 2>/dev/null)

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        xy="${line:0:2}"
        case "$xy" in
            "??") ((untracked++)) ;;
            " M"|" T"|"MM") ((modified++)) ;;
            " D") ((deleted++)) ;;
            M*|A*|R*|D*) ((staged++)) ;;
        esac
    done <<< "$git_status"

    local stashed
    stashed=$(git stash list 2>/dev/null | wc -l)
    stashed=$((stashed + 0))

    local markers=""
    [ "$staged" -gt 0 ] && markers+="${C_GREEN}+${staged}${C_RESET}"
    [ "$modified" -gt 0 ] && markers+="${C_YELLOW}!${modified}${C_RESET}"
    [ "$untracked" -gt 0 ] && markers+="${C_BLUE}?${untracked}${C_RESET}"
    [ "$deleted" -gt 0 ] && markers+="${C_RED}x${deleted}${C_RESET}"
    [ "$stashed" -gt 0 ] && markers+="${C_MAGENTA}\$${stashed}${C_RESET}"

    local git_dir state="" worktree=""
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
        state="${C_YELLOW}|REBASING${C_RESET}"
    elif [ -f "$git_dir/MERGE_HEAD" ]; then
        state="${C_YELLOW}|MERGING${C_RESET}"
    elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
        state="${C_YELLOW}|PICKING${C_RESET}"
    fi

    if [ -f ".git" ]; then
        worktree="${C_BLUE}[wt]${C_RESET}"
    fi

    local status_line=" ${C_MAGENTA}${branch}${C_RESET}${state}"
    [ -n "$worktree" ] && status_line+=" ${worktree}"
    [ -n "$sync" ] && status_line+=" ${sync}"
    [ -n "$markers" ] && status_line+=" [${markers}]"

    echo -e "$status_line"
}

GIT_INFO=$(git_info)

# ---------- Duration ----------
DURATION_SEC=$((DURATION_MS / 1000))
DURATION_HOUR=$((DURATION_SEC / 3600))
DURATION_MIN=$(((DURATION_SEC % 3600) / 60))
DURATION_SEC_REM=$((DURATION_SEC % 60))
DURATION_STR=$(printf "%d:%02d:%02d" $DURATION_HOUR $DURATION_MIN $DURATION_SEC_REM)

# ---------- Context color ----------
if [ "$CONTEXT_PCT" -ge 90 ] 2>/dev/null; then
    CONTEXT_COLOR="${C_RED}"
elif [ "$CONTEXT_PCT" -ge 80 ] 2>/dev/null; then
    CONTEXT_COLOR="${C_YELLOW}"
else
    CONTEXT_COLOR="${C_DIM}"
fi

# ==========================================================================
# Rate limit usage via Haiku probe (cached)
# ==========================================================================

CACHE_FILE="/tmp/claude-usage-cache-${USER:-$(id -un)}.json"
CACHE_TTL=360

rl_color_for_pct() {
    local pct="${1:-0}"
    if [ -z "$pct" ] || [ "$pct" = "null" ]; then
        printf '%s' "$RL_GRAY"; return
    fi
    local ipct
    ipct=$(printf "%.0f" "$pct" 2>/dev/null) || ipct=0
    if [ "$ipct" -ge 80 ]; then
        printf '%s' "$RL_RED"
    elif [ "$ipct" -ge 50 ]; then
        printf '%s' "$RL_YELLOW"
    else
        printf '%s' "$RL_GREEN"
    fi
}

progress_bar() {
    local pct="${1:-0}"
    local filled
    filled=$(awk "BEGIN{v=int($pct / 10 + 0.5); if(v>10)v=10; if(v<0)v=0; printf \"%d\", v}" 2>/dev/null) || filled=0
    local bar="" i
    for i in $(seq 1 10); do
        if [ "$i" -le "$filled" ]; then
            bar+="▰"
        else
            bar+="▱"
        fi
    done
    printf '%s' "$bar"
}

to_pct() {
    local val="$1"
    if [ -z "$val" ] || [ "$val" = "null" ] || [ "$val" = "0" ]; then
        echo ""; return
    fi
    awk "BEGIN{printf \"%.0f\", $val * 100}" 2>/dev/null || echo ""
}

format_epoch_time() {
    local epoch="$1" format="$2"
    [ -z "$epoch" ] || [ "$epoch" = "0" ] && return
    local result
    result=$(LC_ALL=en_US.UTF-8 TZ="Asia/Tokyo" date -j -f "%s" "$epoch" "$format" 2>/dev/null || \
             LC_ALL=en_US.UTF-8 TZ="Asia/Tokyo" date -d "@${epoch}" "$format" 2>/dev/null || echo "")
    echo "$result" | sed 's/AM/am/;s/PM/pm/'
}

fetch_usage() {
    local token
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
    [ -z "$token" ] && return 1

    local access_token
    if echo "$token" | jq -e . >/dev/null 2>&1; then
        access_token=$(echo "$token" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    else
        access_token="$token"
    fi
    [ -z "$access_token" ] && return 1

    local headers
    headers=$(curl -sD- --max-time 8 -o /dev/null \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/${CC_VERSION:-0.0.0}" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "anthropic-version: 2023-06-01" \
        -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"h"}]}' \
        "https://api.anthropic.com/v1/messages" 2>/dev/null || true)
    [ -z "$headers" ] && return 1

    local h5_util h5_reset h7_util h7_reset
    h5_util=$(echo "$headers" | grep -i 'anthropic-ratelimit-unified-5h-utilization' | tr -d '\r' | awk '{print $2}')
    h5_reset=$(echo "$headers" | grep -i 'anthropic-ratelimit-unified-5h-reset' | tr -d '\r' | awk '{print $2}')
    h7_util=$(echo "$headers" | grep -i 'anthropic-ratelimit-unified-7d-utilization' | tr -d '\r' | awk '{print $2}')
    h7_reset=$(echo "$headers" | grep -i 'anthropic-ratelimit-unified-7d-reset' | tr -d '\r' | awk '{print $2}')

    [ -z "$h5_util" ] && return 1

    jq -n \
        --arg h5u "$h5_util" --arg h5r "$h5_reset" \
        --arg h7u "$h7_util" --arg h7r "$h7_reset" \
        '{five_hour_util: $h5u, five_hour_reset: $h5r, seven_day_util: $h7u, seven_day_reset: $h7r}' \
        > "$CACHE_FILE"
    return 0
}

load_usage() {
    local data="$1"
    eval "$(echo "$data" | jq -r '
        "FIVE_HOUR_UTIL=" + (.five_hour_util // empty),
        "FIVE_HOUR_RESET=" + (.five_hour_reset // empty),
        "SEVEN_DAY_UTIL=" + (.seven_day_util // empty),
        "SEVEN_DAY_RESET=" + (.seven_day_reset // empty)
    ' 2>/dev/null)"
}

# Check cache
FIVE_HOUR_UTIL="" FIVE_HOUR_RESET="" SEVEN_DAY_UTIL="" SEVEN_DAY_RESET=""
USE_CACHE=false
if [ -f "$CACHE_FILE" ]; then
    cache_age=$(( $(date +%s) - $(stat -f '%m' "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$cache_age" -lt "$CACHE_TTL" ]; then
        USE_CACHE=true
    fi
fi

if $USE_CACHE; then
    load_usage "$(cat "$CACHE_FILE")"
else
    if fetch_usage; then
        load_usage "$(cat "$CACHE_FILE")"
    elif [ -f "$CACHE_FILE" ]; then
        load_usage "$(cat "$CACHE_FILE")"
    fi
fi

FIVE_HOUR_PCT=$(to_pct "$FIVE_HOUR_UTIL")
SEVEN_DAY_PCT=$(to_pct "$SEVEN_DAY_UTIL")

# Reset time display
five_reset_display=""
if [ -n "$FIVE_HOUR_RESET" ] && [ "$FIVE_HOUR_RESET" != "0" ]; then
    five_reset_display="Reset $(format_epoch_time "$FIVE_HOUR_RESET" "+%-I%p")"
fi

seven_reset_display=""
if [ -n "$SEVEN_DAY_RESET" ] && [ "$SEVEN_DAY_RESET" != "0" ]; then
    seven_reset_display="Reset $(format_epoch_time "$SEVEN_DAY_RESET" "+%-m/%-d %-I%p")"
fi

# ==========================================================================
# Output
# ==========================================================================

# Line 1: Model | Dir/Git | Duration | Context%
echo -e "${C_DIM}[${C_GREEN}${MODEL}${C_DIM}]${C_RESET} ${C_CYAN}${DIR_NAME}${C_RESET}${GIT_INFO} ${C_DIM}${DURATION_STR}${C_RESET} ${CONTEXT_COLOR}ctx:${CONTEXT_PCT}%${C_RESET}"

# Line 2: 5h rate limit
if [ -n "$FIVE_HOUR_PCT" ]; then
    c5=$(rl_color_for_pct "$FIVE_HOUR_PCT")
    bar5=$(progress_bar "$FIVE_HOUR_PCT")
    line2="${c5}5h ${bar5} ${FIVE_HOUR_PCT}%${C_RESET}"
    [ -n "$five_reset_display" ] && line2+="  ${C_DIM}${five_reset_display}${C_RESET}"
else
    line2="${RL_GRAY}5h ▱▱▱▱▱▱▱▱▱▱ --%${C_RESET}"
fi

# Line 3: 7d rate limit
if [ -n "$SEVEN_DAY_PCT" ]; then
    c7=$(rl_color_for_pct "$SEVEN_DAY_PCT")
    bar7=$(progress_bar "$SEVEN_DAY_PCT")
    line3="${c7}7d ${bar7} ${SEVEN_DAY_PCT}%${C_RESET}"
    [ -n "$seven_reset_display" ] && line3+="  ${C_DIM}${seven_reset_display}${C_RESET}"
else
    line3="${RL_GRAY}7d ▱▱▱▱▱▱▱▱▱▱ --%${C_RESET}"
fi

echo -e "$line2"
printf '%s' "$line3"
