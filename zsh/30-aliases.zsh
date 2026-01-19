#!/usr/bin/env zsh
# エイリアス定義

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# tmux
alias t='tmux'
alias ta='tmux attach'
alias tl='tmux list-sessions'
alias tc='tmux new-session \; split-window -v -p 30 \; select-pane -t 1 \; send-keys "claude" Enter'

# エディタ
alias v='vim'
alias vi='vim'

# システム
alias reload='source ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'

# モダンツール（存在する場合のみ）
(( $+commands[eza] )) && {
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first'
    alias la='eza -la --group-directories-first'
    alias tree='eza --tree'
}
(( $+commands[bat] )) && alias b='bat'
(( $+commands[rg] )) && alias grep='rg'

# Docker（存在する場合のみ）
(( $+commands[docker] )) && {
    alias d='docker'
    alias dc='docker-compose'
    alias dps='docker ps'
}

# macOS固有
[[ "$OSTYPE" == darwin* ]] && {
    alias flushdns='sudo dscacheutil -flushcache'
}

# 安全な操作（対話シェルのみ）
if [[ -o interactive ]]; then
    alias rm='rm -i'
    alias cp='cp -i'
    alias mv='mv -i'
fi
