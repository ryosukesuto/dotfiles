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

# precmdでvcs_infoを更新（プロンプト表示前に1回だけ実行）
precmd() { vcs_info }

# プロンプト設定
PROMPT='%F{cyan}%~%f${vcs_info_msg_0_}
%F{yellow}>%f '
RPROMPT='%F{8}%T%f'
