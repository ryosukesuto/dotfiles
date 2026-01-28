#!/usr/bin/env zsh
# プロンプト設定（vcs_info使用で高速化）

autoload -Uz colors && colors
autoload -Uz vcs_info
setopt PROMPT_SUBST

# vcs_info設定
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %F{green}(%b%u%c)%f'
zstyle ':vcs_info:*' actionformats ' %F{green}(%b|%a%u%c)%f'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '+'
zstyle ':vcs_info:*' unstagedstr '*'

# 環境情報を生成（事故防止用）
_prompt_env_info() {
  local info=()

  # ENV（prd/prodは赤で警告）
  if [[ -n "$ENV" ]]; then
    if [[ "$ENV" =~ ^(prd|prod|production)$ ]]; then
      info+=("%F{red}ENV:${ENV}%f")
    else
      info+=("%F{blue}ENV:${ENV}%f")
    fi
  fi

  # AWS_PROFILE
  if [[ -n "$AWS_PROFILE" ]]; then
    info+=("%F{yellow}AWS:${AWS_PROFILE}%f")
  fi

  # GCP_PROJECT
  if [[ -n "$GOOGLE_CLOUD_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GOOGLE_CLOUD_PROJECT}%f")
  elif [[ -n "$GCP_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GCP_PROJECT}%f")
  fi

  # 情報があれば表示
  if [[ ${#info[@]} -gt 0 ]]; then
    echo "[${(j: :)info}] "
  fi
}

# precmdでvcs_infoを更新（プロンプト表示前に1回だけ実行）
precmd() { vcs_info; __update_tab_title }

# タブタイトル設定
# 形式: repo:branch* または repo@wt:branch* (worktree内)
# tmux内: rename-windowでウィンドウ名を直接設定（OSC 2を無視する設定のため）
# tmux外: OSC 2でターミナルタイトルを設定
__update_tab_title() {
  local title repo branch dirty wt
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    repo=$(basename "$(git rev-parse --show-toplevel)")
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    # ブランチ名を短縮: "username/xxx" → "xxx", "feature/xxx" → "f/xxx"
    case "$branch" in
      feature/*) branch="f/${branch#feature/}" ;;
      fix/*) branch="x/${branch#fix/}" ;;
      bugfix/*) branch="b/${branch#bugfix/}" ;;
      hotfix/*) branch="h/${branch#hotfix/}" ;;
      */*) branch="${branch##*/}" ;;  # その他のprefix（ユーザー名等）は除去
    esac
    # worktree内ならディレクトリ名を追加
    wt=${PWD:t}
    [[ "$wt" != "$repo" ]] && repo="${repo}@${wt}"
    # 未コミット変更があれば*を追加
    git diff --quiet --ignore-submodules -- 2>/dev/null || dirty="*"
    title="${repo}:${branch}${dirty}"
  else
    title="${PWD:t}"
  fi
  # tmux内: ウィンドウ名を直接設定
  # tmux外: OSC 2でタイトル設定
  if [[ -n "$TMUX" ]]; then
    tmux rename-window "$title"
  else
    print -Pn "\e]2;${title}\a"
  fi
}

# プロンプト設定
PROMPT='$(_prompt_env_info)%F{cyan}%~%f${vcs_info_msg_0_}
%F{yellow}>%f '
RPROMPT='%F{8}%T%f'
