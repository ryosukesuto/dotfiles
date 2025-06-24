#!/usr/bin/env zsh
# ============================================================================
# 30-functions.zsh - コア関数と遅延読み込み設定
# ============================================================================
# このファイルは頻繁に使用される基本的な関数のみを定義し、
# 大きな関数や診断ツールは遅延読み込みします。

# ============================================================================
# 基本的なユーティリティ関数
# ============================================================================
# ディレクトリ作成と移動を同時に行う
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# ファイル/ディレクトリのサイズを表示
sizeof() {
    du -sh "$@"
}

# ============================================================================
# ディレクトリナビゲーション（ghq + fzf/peco）
# ============================================================================
if command -v fzf &> /dev/null && command -v ghq &> /dev/null; then
    # fzfを使ったバージョン
    function fzf-src() {
        local selected_dir=$(ghq list -p | fzf --query "$LBUFFER" --height 40% --reverse)
        if [[ -n "$selected_dir" ]]; then
            BUFFER="cd ${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N fzf-src
    bindkey '^]' fzf-src
elif command -v peco &> /dev/null && command -v ghq &> /dev/null; then
    # pecoを使ったバージョン
    function peco-src() {
        local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
        if [[ -n "$selected_dir" ]]; then
            BUFFER="cd ${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N peco-src
    bindkey '^g' peco-src
fi

# ============================================================================
# 遅延読み込み関数の定義
# ============================================================================
# 関数ディレクトリのパス
DOTFILES_FUNCTIONS_DIR="${DOTFILES_DIR:-$HOME/dotfiles}/zsh/functions"

# 圧縮ファイル展開（遅延読み込み）
extract() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/extract.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/extract.zsh"
        extract "$@"
    else
        # フォールバック実装
        if [[ -f "$1" ]]; then
            case "$1" in
                *.tar.bz2)   tar xjf "$1"     ;;
                *.tar.gz)    tar xzf "$1"     ;;
                *.bz2)       bunzip2 "$1"     ;;
                *.rar)       unrar x "$1"     ;;
                *.gz)        gunzip "$1"      ;;
                *.tar)       tar xf "$1"      ;;
                *.tbz2)      tar xjf "$1"     ;;
                *.tgz)       tar xzf "$1"     ;;
                *.zip)       unzip "$1"       ;;
                *.Z)         uncompress "$1"  ;;
                *.7z)        7z x "$1"        ;;
                *)           echo "'$1' cannot be extracted via extract()" ;;
            esac
        else
            echo "'$1' is not a valid file"
        fi
    fi
}

# AWS Bastion関連（遅延読み込み）
aws-bastion() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh"
        aws-bastion "$@"
    else
        echo "aws-bastion function not found"
        return 1
    fi
}

aws-bastion-select() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh"
        aws-bastion-select "$@"
    else
        echo "aws-bastion-select function not found"
        return 1
    fi
}

# Dotfiles診断（遅延読み込み）
dotfiles-diag() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/diagnostics.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/diagnostics.zsh"
        dotfiles-diag "$@"
    else
        echo "診断ツールが見つかりません。以下を確認してください："
        echo "- $DOTFILES_FUNCTIONS_DIR/diagnostics.zsh が存在するか"
        echo "- DOTFILES_DIR 環境変数が正しく設定されているか"
        return 1
    fi
}

# ============================================================================
# クイックエイリアス的な関数
# ============================================================================
# 一つ上のディレクトリに移動してls
up() {
    cd .. && ls
}

# Git リポジトリのルートに移動
cdgr() {
    cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
}

# 最近変更されたファイルを表示
recent() {
    local count=${1:-10}
    if command -v eza &> /dev/null; then
        eza -la --sort=modified --reverse | head -n "$count"
    else
        ls -lat | head -n "$count"
    fi
}

# ============================================================================
# 環境情報表示（シンプル版）
# ============================================================================
# 詳細版はdotfiles-diagを使用
env-info() {
    echo "=== 基本環境情報 ==="
    echo "Shell: $SHELL ($ZSH_VERSION)"
    echo "OS: $(uname -s) $(uname -r)"
    echo "User: $USER"
    echo "Home: $HOME"
    echo ""
    echo "詳細な診断情報は 'dotfiles-diag' コマンドを使用してください。"
}