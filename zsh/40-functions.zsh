#!/usr/bin/env zsh
# ============================================================================
# 40-functions.zsh - コア関数定義
# ============================================================================
# このファイルは頻繁に使用される基本的な関数と遅延読み込み設定を提供します。

# ============================================================================
# ディレクトリナビゲーション（ghq + fzf/peco）
# ============================================================================
# fzfを優先、なければpecoを使用
if command -v ghq &> /dev/null; then
    if command -v fzf &> /dev/null; then
        # fzfを使ったバージョン（Ctrl+]）
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
    elif command -v peco &> /dev/null; then
        # pecoを使ったバージョン（Ctrl+g）
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
fi

# ============================================================================
# 遅延読み込み設定
# ============================================================================
# 関数ディレクトリのパス
DOTFILES_FUNCTIONS_DIR="${DOTFILES_DIR:-$HOME/src/github.com/ryosukesuto/dotfiles}/zsh/functions"

# ============================================================================
# 遅延読み込み関数のヘルパー
# ============================================================================
# 遅延読み込み関数を作成するヘルパー関数
# 使用例: create_lazy_function "aws-bastion" "aws-bastion.zsh"
function create_lazy_function() {
    local func_name=$1
    local source_file=$2
    local error_msg=${3:-"$func_name function not found"}
    
    eval "
    $func_name() {
        if [[ -f \"$DOTFILES_FUNCTIONS_DIR/$source_file\" ]]; then
            source \"$DOTFILES_FUNCTIONS_DIR/$source_file\"
            $func_name \"\$@\"
        else
            echo \"$error_msg\" >&2
            return 1
        fi
    }
    "
}

# ============================================================================
# AWS Bastion関連（遅延読み込み）
# ============================================================================
create_lazy_function "aws-bastion" "aws-bastion.zsh"
create_lazy_function "aws-bastion-select" "aws-bastion.zsh"

# ============================================================================
# ユーティリティ関数（遅延読み込み）
# ============================================================================
# アーカイブ展開関数
create_lazy_function "extract" "extract.zsh" "extract function not found"

# 診断関数
create_lazy_function "diag" "diagnostics.zsh" "diagnostics function not found"
create_lazy_function "diagnose" "diagnostics.zsh" "diagnostics function not found"

# ============================================================================
# Obsidian関数（Zsh環境用）
# ============================================================================
# Claude Code（Bash）は bin/th を直接使用
# Zsh環境ではオプションでzsh関数版を使用可能
if [[ -f "$DOTFILES_FUNCTIONS_DIR/obsidian.zsh" ]]; then
    # Zsh関数版を使いたい場合は以下のコメントを外す
    # source "$DOTFILES_FUNCTIONS_DIR/obsidian.zsh"
    # alias th-zsh=th  # zsh関数版にエイリアス
    :  # 現在はbin/thを使用
fi

# ============================================================================
# Gemini検索関数（遅延読み込み）- オプション
# ============================================================================
if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
    # Gemini関数のスタブ定義
    for func in gsearch gemini-search gtech gnews; do
        create_lazy_function "$func" "gemini-search.zsh" "Gemini検索関数が見つかりません"
    done
fi

# ============================================================================
# Obsidian-Claude連携関数（遅延読み込み）
# ============================================================================
if [[ -f "$DOTFILES_FUNCTIONS_DIR/obsidian-claude.zsh" ]]; then
    # Obsidian-Claude関数のスタブ定義
    create_lazy_function "obsc" "obsidian-claude.zsh" "Obsidian-Claude連携関数が見つかりません"
    create_lazy_function "obs-task" "obsidian-claude.zsh" "Obsidian-Claude連携関数が見つかりません"
    create_lazy_function "obs-meeting" "obsidian-claude.zsh" "Obsidian-Claude連携関数が見つかりません"
    create_lazy_function "obs-claude-recent" "obsidian-claude.zsh" "Obsidian-Claude連携関数が見つかりません"
fi

# ============================================================================
# クリーンアップ
# ============================================================================
# ヘルパー関数を削除（グローバル名前空間を汚染しない）
unfunction create_lazy_function