#!/usr/bin/env zsh
# プロンプト設定（非同期dirty checkで高速化）
#
# 従来: vcs_info の check-for-changes=true が毎回 git diff-index / git diff-files を
#        同期実行 → 大きいリポジトリで100-500msのブロッキング
# 改善: ブランチ名は vcs_info で即時取得、dirty状態は zle -F で非同期チェック
#        → プロンプト表示を待たせず、結果が返り次第プロンプトを再描画

autoload -Uz colors && colors
autoload -Uz vcs_info add-zsh-hook
setopt PROMPT_SUBST

# vcs_info: ブランチ名のみ取得（check-for-changes無効で高速）
# msg_0_ / msg_1_: ブランチ名（actionformats時は branch|action）
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats '%b' '%b'
zstyle ':vcs_info:*' actionformats '%b|%a' '%b|%a'
zstyle ':vcs_info:*' check-for-changes false

# --- 非同期dirty check（zle -F でバックグラウンド完了時にプロンプト再描画） ---
typeset -gi _dirty_fd=0
typeset -g  _dirty_result=""

_start_dirty_check() {
  # 前回のfdが残っていたら閉じる
  if (( _dirty_fd )); then
    zle -F $_dirty_fd 2>/dev/null
    exec {_dirty_fd}<&- 2>/dev/null
    _dirty_fd=0
  fi
  # git リポジトリ外なら空にして終了
  [[ -n "$vcs_info_msg_0_" ]] || { _dirty_result=""; return }
  exec {_dirty_fd}< <(
    local s="" u=""
    git diff-index --quiet HEAD --cached 2>/dev/null || s="+"
    git diff-files --quiet 2>/dev/null || u="*"
    printf '%s' "${s}${u}"
  )
  zle -F $_dirty_fd _on_dirty_result
}

_on_dirty_result() {
  local fd=$1 new=""
  read -r new <&$fd 2>/dev/null
  zle -F $fd 2>/dev/null
  exec {fd}<&- 2>/dev/null
  _dirty_fd=0
  [[ "$_dirty_result" == "$new" ]] && return
  _dirty_result="$new"
  zle && zle reset-prompt
}

# --- 環境情報キャッシュ（サブシェルfork排除） ---
typeset -g _prompt_env_cache=""

_update_prompt_env_cache() {
  local info=()
  if [[ -n "$ENV" ]]; then
    if [[ "$ENV" =~ ^(prd|prod|production)$ ]]; then
      info+=("%F{red}ENV:${ENV}%f")
    else
      info+=("%F{blue}ENV:${ENV}%f")
    fi
  fi
  [[ -n "$AWS_PROFILE" ]] && info+=("%F{yellow}AWS:${AWS_PROFILE}%f")
  if [[ -n "$GOOGLE_CLOUD_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GOOGLE_CLOUD_PROJECT}%f")
  elif [[ -n "$GCP_PROJECT" ]]; then
    info+=("%F{cyan}GCP:${GCP_PROJECT}%f")
  fi
  (( ${#info[@]} )) && _prompt_env_cache="[${(j: :)info}] " || _prompt_env_cache=""
}

# --- リポジトリ名キャッシュ（chpwdでのみ更新） ---
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

# --- タブタイトル ---
# 形式: repo:branch* または repo@wt:branch* (worktree内)
# tmux内: rename-window、tmux外: OSC 2
typeset -g _tab_title_prev=""

__update_tab_title() {
  local title
  if [[ -n "$_tab_repo" && -n "$vcs_info_msg_1_" ]]; then
    local branch=$vcs_info_msg_1_
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
    [[ "$_dirty_result" == *'*'* ]] && dirty="*"
    title="${_tab_repo}${_tab_wt}:${branch}${dirty}"
  else
    title="${PWD:t}"
  fi
  [[ "$title" == "$_tab_title_prev" ]] && return
  _tab_title_prev="$title"
  if [[ -n "$TMUX" ]]; then
    tmux rename-window "$title"
  else
    print -Pn "\e]2;${title}\a"
  fi
}

# --- precmd フック ---
_precmd_vcs() { vcs_info; _update_prompt_env_cache; __update_tab_title; _start_dirty_check }
add-zsh-hook precmd _precmd_vcs

# --- プロンプト ---
# vcs_info_msg_0_ = ブランチ名、_dirty_result = 非同期で取得した +（staged）*（unstaged）
PROMPT='${_prompt_env_cache}%F{cyan}%~%f${vcs_info_msg_0_:+ %F{green}(${vcs_info_msg_0_}${_dirty_result})%f}
%F{yellow}>%f '
RPROMPT='%F{8}%T%f'
