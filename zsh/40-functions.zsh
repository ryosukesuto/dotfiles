#!/usr/bin/env zsh
# ============================================================================
# 40-functions.zsh - コア関数定義
# ============================================================================
# このファイルは頻繁に使用される基本的な関数と遅延読み込み設定を提供します。

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
# 遅延読み込み関数
# ============================================================================
# 関数ディレクトリのパス
DOTFILES_FUNCTIONS_DIR="${DOTFILES_DIR:-$HOME/src/github.com/ryosukesuto/dotfiles}/zsh/functions"

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

# Obsidian関数（遅延読み込み）
th() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/obsidian.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/obsidian.zsh"
        th "$@"
    else
        echo "Obsidian関数が見つかりません"
        return 1
    fi
}

# Gemini検索関数（遅延読み込み）- 使用状況に応じて削除可能
if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
    # Gemini関数のスタブ定義
    for func in gsearch gemini-search gtech gnews; do
        eval "
        $func() {
            if [[ -f \"$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh\" ]]; then
                source \"$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh\"
                $func \"\$@\"
            else
                echo \"Gemini検索関数が見つかりません\"
                return 1
            fi
        }
        "
    done
fi