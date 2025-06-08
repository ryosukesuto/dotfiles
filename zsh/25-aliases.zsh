# Git関連エイリアス
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gb='git branch'

# ディレクトリ移動
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# 安全なコマンド
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ls関連（モダンなツールがある場合は置き換え）
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
    alias ll='eza -l --icons'
    alias la='eza -la --icons'
    alias tree='eza --tree --icons'
    alias lt='eza --tree --level=2 --icons'
else
    alias ll='ls -l'
    alias la='ls -la'
fi

# cat代替（batがある場合）
if command -v bat &> /dev/null; then
    alias cat='bat'
    alias less='bat'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# grep代替（ripgrepがある場合）
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# find代替（fdがある場合）
if command -v fd &> /dev/null; then
    alias find='fd'
fi

# その他便利なエイリアス
alias h='history'
alias j='jobs -l'
alias reload='source ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'

# ネットワーク
alias ping='ping -c 5'
alias ports='netstat -tuln'

# Docker（あれば）
if command -v docker &> /dev/null; then
    alias d='docker'
    alias dc='docker-compose'
    alias dps='docker ps'
    alias dimg='docker images'
fi

# Kubernetes（あれば）
if command -v kubectl &> /dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
fi

# tmux（あれば）
if command -v tmux &> /dev/null; then
    alias t='tmux'
    alias ta='tmux attach'
    alias tl='tmux list-sessions'
    alias tn='tmux new-session'
    alias tk='tmux kill-session'
fi