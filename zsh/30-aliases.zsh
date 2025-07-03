#!/usr/bin/env zsh
# ============================================================================
# 30-aliases.zsh - 必要最小限のエイリアス定義
# ============================================================================
# このファイルは日常的に使用する最小限のエイリアスを定義します。

# ============================================================================
# tmuxセッション管理
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