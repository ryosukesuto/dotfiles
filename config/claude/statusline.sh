#!/bin/bash
# Claude Code status line script
# Git repository status display with colors

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "~"')
DIR_NAME="${DIR##*/}"

# コンテキスト使用率
CONTEXT_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
CONTEXT_PCT=${CONTEXT_PCT%.*}  # 整数部分のみ

# ANSIカラーコード
C_RESET="\033[0m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_CYAN="\033[36m"
C_RED="\033[31m"
C_DIM="\033[2m"

# Git情報取得
git_info() {
    # Gitリポジトリかチェック
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return
    fi

    local branch

    # ブランチ名
    branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        branch=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    # ahead/behind
    local ahead behind sync=""
    ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null) || ahead=0
    behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null) || behind=0
    ahead=${ahead:-0}
    behind=${behind:-0}

    [ "$ahead" -gt 0 ] 2>/dev/null && sync+="${C_GREEN}↑${ahead}${C_RESET}"
    [ "$behind" -gt 0 ] 2>/dev/null && sync+="${C_RED}↓${behind}${C_RESET}"

    # ステータス取得（git status --porcelainを1回だけ実行）
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

    # stash
    local stashed
    stashed=$(git stash list 2>/dev/null | wc -l)
    stashed=$((stashed + 0))

    # ステータス文字列構築（色付き）
    local markers=""
    [ "$staged" -gt 0 ] && markers+="${C_GREEN}+${staged}${C_RESET}"
    [ "$modified" -gt 0 ] && markers+="${C_YELLOW}!${modified}${C_RESET}"
    [ "$untracked" -gt 0 ] && markers+="${C_BLUE}?${untracked}${C_RESET}"
    [ "$deleted" -gt 0 ] && markers+="${C_RED}x${deleted}${C_RESET}"
    [ "$stashed" -gt 0 ] && markers+="${C_MAGENTA}\$${stashed}${C_RESET}"

    # Git状態（rebase/merge等）
    local git_dir state="" worktree=""
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
        state="${C_YELLOW}|REBASING${C_RESET}"
    elif [ -f "$git_dir/MERGE_HEAD" ]; then
        state="${C_YELLOW}|MERGING${C_RESET}"
    elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
        state="${C_YELLOW}|PICKING${C_RESET}"
    fi

    # Worktree検出（.gitがファイルの場合はworktree）
    if [ -f ".git" ]; then
        worktree="${C_BLUE}[wt]${C_RESET}"
    fi

    # 出力構築
    local status_line=" ${C_MAGENTA}${branch}${C_RESET}${state}"
    [ -n "$worktree" ] && status_line+=" ${worktree}"
    [ -n "$sync" ] && status_line+=" ${sync}"
    [ -n "$markers" ] && status_line+=" [${markers}]"

    echo -e "$status_line"
}

GIT_INFO=$(git_info)

# セッション経過時間（時:分:秒形式）
DURATION_MS=$(echo "$input" | jq '.cost.total_duration_ms // 0')
DURATION_SEC=$((DURATION_MS / 1000))
DURATION_HOUR=$((DURATION_SEC / 3600))
DURATION_MIN=$(((DURATION_SEC % 3600) / 60))
DURATION_SEC_REM=$((DURATION_SEC % 60))
DURATION_STR=$(printf "%d:%02d:%02d" $DURATION_HOUR $DURATION_MIN $DURATION_SEC_REM)

# コンテキスト使用率の色分け（80%以上で黄色、90%以上で赤）
if [ "$CONTEXT_PCT" -ge 90 ] 2>/dev/null; then
    CONTEXT_COLOR="${C_RED}"
elif [ "$CONTEXT_PCT" -ge 80 ] 2>/dev/null; then
    CONTEXT_COLOR="${C_YELLOW}"
else
    CONTEXT_COLOR="${C_DIM}"
fi

echo -e "${C_DIM}[${C_GREEN}${MODEL}${C_DIM}]${C_RESET} ${C_CYAN}${DIR_NAME}${C_RESET}${GIT_INFO} ${C_DIM}${DURATION_STR}${C_RESET} ${CONTEXT_COLOR}ctx:${CONTEXT_PCT}%${C_RESET}"
