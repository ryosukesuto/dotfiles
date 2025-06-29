#!/usr/bin/env zsh
# ============================================================================
# 25-aliases.zsh - Zsh エイリアス定義
# ============================================================================
# このファイルは各種コマンドのエイリアスを定義します。
# モダンなCLIツールが利用可能な場合は、それらを優先的に使用します。

# ============================================================================
# 基本的なコマンドの安全性向上
# ============================================================================
# ファイル操作時の誤操作を防ぐため、確認プロンプトを表示
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ============================================================================
# ディレクトリ移動
# ============================================================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# ============================================================================
# ls コマンドの拡張（ezaまたは標準ls）
# ============================================================================
if command -v eza &> /dev/null; then
    # ezaが利用可能な場合
    alias ls='eza --icons'
    alias ll='eza -l --icons'
    alias la='eza -la --icons'
    alias tree='eza --tree --icons'
    alias lt='eza --tree --level=2 --icons'
else
    # 標準のlsを使用
    alias ll='ls -l'
    alias la='ls -la'
fi

# ============================================================================
# モダンなCLIツールへの置き換え
# ============================================================================
# bat（catの代替）
if command -v bat &> /dev/null; then
    alias cat='bat'
    alias less='bat'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ripgrep（grepの代替）
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# fd（findの代替）
if command -v fd &> /dev/null; then
    alias find='fd'
fi

# ============================================================================
# Git エイリアス
# ============================================================================
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

# ============================================================================
# コンテナ関連（Docker/Kubernetes）
# ============================================================================
if command -v docker &> /dev/null; then
    alias d='docker'
    alias dc='docker-compose'
    alias dps='docker ps'
    alias dimg='docker images'
fi

# ============================================================================
# セッション管理（tmux）
# ============================================================================
if command -v tmux &> /dev/null; then
    alias t='tmux'
    alias ta='tmux attach'
    alias tl='tmux list-sessions'
    alias tn='tmux new-session'
    alias tk='tmux kill-session'
fi

# ============================================================================
# AWS関連
# ============================================================================
if command -v aws &> /dev/null; then
    alias bastion='aws-bastion'
    alias bastion-select='aws-bastion-select'
    alias bastion-prod='aws-bastion prod'
    alias bastion-dev='aws-bastion dev'
    alias bastion-staging='aws-bastion staging'
fi

# ============================================================================
# エディタ関連
# ============================================================================
if command -v vim &> /dev/null; then
    alias v='vim'
    alias vi='vim'
    # Vimでプラグインインストール
    alias vimplug='vim +PlugInstall +qall'
fi

# ============================================================================
# システムユーティリティ
# ============================================================================
alias h='history'
alias j='jobs -l'
alias reload='source ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'

# ============================================================================
# ネットワーク関連
# ============================================================================
alias ping='ping -c 5'
alias ports='netstat -tuln'

# ============================================================================
# OS固有のエイリアス
# ============================================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS専用
    alias copy='pbcopy'
    alias paste='pbpaste'
fi

# ============================================================================
# 補完設定の初期化
# ============================================================================
# エイリアスに対する補完を設定する関数
_setup_alias_completions() {
    # ezaの補完設定
    if command -v eza &> /dev/null && (( ${+_comps[eza]} )); then
        compdef _eza ls ll la tree lt
    elif (( ${+_comps[ls]} )); then
        # 標準lsの補完設定
        compdef _ls ll la
    fi
    
    # Gitエイリアスの補完設定
    if (( ${+_comps[git]} )); then
        compdef _git g
        compdef _git-status gs
        compdef _git-add ga
        compdef _git-commit gc
        compdef _git-diff gd gdc
        compdef _git-log gl gla
        compdef _git-push gp
        compdef _git-pull gpl
        compdef _git-checkout gco
        compdef _git-branch gb
    fi
    
    # Dockerエイリアスの補完設定
    if command -v docker &> /dev/null && (( ${+_comps[docker]} )); then
        compdef _docker d
        compdef _docker-compose dc
    fi
    
    # tmuxエイリアスの補完設定
    if command -v tmux &> /dev/null && (( ${+_comps[tmux]} )); then
        compdef _tmux t ta tl tn tk
    fi
    
    # Vimエイリアスの補完設定
    if command -v vim &> /dev/null && (( ${+_comps[vim]} )); then
        compdef _vim v vi
    fi
}

# 補完システムが初期化された後に補完設定を行う
# add-zsh-hookを使用して、補完が利用可能になった時点で設定
autoload -Uz add-zsh-hook
() {
    local setup_done=0
    _try_setup_completions() {
        # 既に設定済みの場合はスキップ
        [[ $setup_done -eq 1 ]] && return
        
        # 補完システムが初期化されているか確認
        if (( ${+_comps} )); then
            _setup_alias_completions
            setup_done=1
            # フックを削除
            add-zsh-hook -d precmd _try_setup_completions
        fi
    }
    # 既存のフックを削除してから追加（重複防止）
    add-zsh-hook -d precmd _try_setup_completions 2>/dev/null
    add-zsh-hook precmd _try_setup_completions
}