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

# リポジトリの定期的な更新
alias update-repo='git fetch origin && git pull origin master && echo "✅ リポジトリが更新されました！"'

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

# 補完設定（初回のみ実行）
_setup_ls_completions() {
    # 一度だけ実行
    typeset -g _ls_completions_setup
    [[ -n "$_ls_completions_setup" ]] && return
    _ls_completions_setup=1
    
    if command -v eza &> /dev/null; then
        # ezaの補完関数を使用してエイリアスに適用
        if (( ${+_comps[eza]} )); then
            compdef _eza ls
            compdef _eza ll
            compdef _eza la
            compdef _eza tree
            compdef _eza lt
        fi
    else
        # 通常のlsの補完を使用
        if (( ${+_comps[ls]} )); then
            compdef _ls ll
            compdef _ls la
        fi
    fi
    
    # フックから自分自身を削除
    add-zsh-hook -d precmd _setup_ls_completions
}

# 補完設定をprecmdフックに追加（初回のみ実行）
autoload -Uz add-zsh-hook
add-zsh-hook precmd _setup_ls_completions

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

# AWS SSM便利エイリアス
if command -v aws &> /dev/null; then
    alias bastion='aws-bastion'
    alias bastion-select='aws-bastion-select'
    alias bastion-prod='aws-bastion prod'
    alias bastion-dev='aws-bastion dev'
    alias bastion-staging='aws-bastion staging'
fi

# Vim
if command -v vim &> /dev/null; then
    alias v='vim'
    alias vi='vim'
    # Vimでプラグインインストール
    alias vimplug='vim +PlugInstall +qall'
fi

# SSH関連 - DOTFILES_DIRの動的取得
if [[ -z "$DOTFILES_DIR" ]]; then
    # Get the directory where dotfiles are located
    if [[ -L ~/.zshrc ]]; then
        DOTFILES_DIR="$(dirname "$(readlink ~/.zshrc)")"
    else
        DOTFILES_DIR="${HOME}/src/github.com/ryosukesuto/dotfiles"
    fi
fi

if [[ -f "${DOTFILES_DIR}/ssh/ssh-utils.sh" ]]; then
    alias ssh-utils="bash '${DOTFILES_DIR}/ssh/ssh-utils.sh'"
    alias ssh-list="bash '${DOTFILES_DIR}/ssh/ssh-utils.sh' list-hosts"
    alias ssh-test="bash '${DOTFILES_DIR}/ssh/ssh-utils.sh' test-connection"
    alias ssh-keygen-ed25519="bash '${DOTFILES_DIR}/ssh/ssh-utils.sh' generate-key ed25519"
    alias ssh-security="bash '${DOTFILES_DIR}/ssh/ssh-utils.sh' check-security"
fi
