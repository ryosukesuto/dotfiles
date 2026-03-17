#!/usr/bin/env zsh
# プロンプト設定（vcs_info使用で高速化）

autoload -Uz colors && colors
autoload -Uz vcs_info add-zsh-hook
setopt PROMPT_SUBST

# vcs_info設定
# msg_0_: プロンプト表示用、msg_1_: タブタイトル用（ブランチ名 dirty指標）
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %F{green}(%b%u%c)%f' '%b %u%c'
zstyle ':vcs_info:*' actionformats ' %F{green}(%b|%a%u%c)%f' '%b %u%c'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '+'
zstyle ':vcs_info:*' unstagedstr '*'

# 環境情報キャッシュ（サブシェルfork排除 — precmdで変数に格納しPROMPTから参照）
typeset -g _prompt_env_cache=""

_update_prompt_env_cache() {
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

  if [[ ${#info[@]} -gt 0 ]]; then
    _prompt_env_cache="[${(j: :)info}] "
  else
    _prompt_env_cache=""
  fi
}

# リポジトリ名キャッシュ（chpwdでのみ更新、precmd毎回のgit rev-parseを排除）
typeset -g _tab_repo="" _tab_wt=""

_update_tab_repo_cache() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    _tab_repo=$(basename "$(git rev-parse --show-toplevel)")
    local wt=${PWD:t}
    [[ "$wt" != "$_tab_repo" ]] && _tab_wt="@${wt}" || _tab_wt=""
  else
    _tab_repo="" _tab_wt=""
  fi
}

add-zsh-hook chpwd _update_tab_repo_cache
_update_tab_repo_cache  # 初期値

# precmdでvcs_info・環境情報・タブタイトルを更新
add-zsh-hook precmd _precmd_vcs
_precmd_vcs() { vcs_info; _update_prompt_env_cache; __update_tab_title }

# タブタイトル設定（vcs_info_msg_1_ を再利用、追加のgitコマンドなし）
# 形式: repo:branch* または repo@wt:branch* (worktree内)
# tmux内: rename-windowでウィンドウ名を直接設定（タイトル変更時のみ）
# tmux外: OSC 2でターミナルタイトルを設定
typeset -g _tab_title_prev=""

__update_tab_title() {
  local title
  if [[ -n "$_tab_repo" && -n "$vcs_info_msg_1_" ]]; then
    local branch=${vcs_info_msg_1_%% *}
    local markers=${vcs_info_msg_1_#* }
    branch=${branch#heads/}
    branch=${branch%%|*}
    case "$branch" in
      feature/*) branch="f/${branch#feature/}" ;;
      fix/*) branch="x/${branch#fix/}" ;;
      bugfix/*) branch="b/${branch#bugfix/}" ;;
      hotfix/*) branch="h/${branch#hotfix/}" ;;
      */*) branch="${branch##*/}" ;;
    esac
    local dirty=""
    [[ "$markers" == *'*'* ]] && dirty="*"
    title="${_tab_repo}${_tab_wt}:${branch}${dirty}"
  else
    title="${PWD:t}"
  fi
  # タイトル未変更ならスキップ（tmux rename-windowのIPC削減）
  [[ "$title" == "$_tab_title_prev" ]] && return
  _tab_title_prev="$title"
  if [[ -n "$TMUX" ]]; then
    tmux rename-window "$title"
  else
    print -Pn "\e]2;${title}\a"
  fi
}

# プロンプト設定
PROMPT='${_prompt_env_cache}%F{cyan}%~%f${vcs_info_msg_0_}
%F{yellow}>%f '
RPROMPT='%F{8}%T%f'
