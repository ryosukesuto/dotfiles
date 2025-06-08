#!/bin/bash

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ログ関数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# ヘルプ表示
show_help() {
    cat << EOF
Usage: ./uninstall.sh [OPTIONS]

Options:
    -h, --help      このヘルプを表示
    -f, --force     確認なしでアンインストール
    -r, --restore   バックアップから復元

Example:
    ./uninstall.sh          # 通常のアンインストール
    ./uninstall.sh --force  # 確認なしでアンインストール
    ./uninstall.sh --restore # バックアップファイルから復元
EOF
}

# オプション解析
FORCE=false
RESTORE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -r|--restore)
            RESTORE=true
            shift
            ;;
        *)
            error "不明なオプション: $1"
            ;;
    esac
done

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 確認プロンプト
if [ "$FORCE" = false ]; then
    echo "dotfilesのシンボリックリンクを削除します"
    if [ "$RESTORE" = true ]; then
        echo "バックアップファイルがある場合は復元します"
    fi
    echo ""
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "アンインストールをキャンセルしました"
        exit 0
    fi
fi

# シンボリックリンクを削除する関数
remove_symlink() {
    local link="$1"
    
    if [ -L "$link" ]; then
        # シンボリックリンクの場合のみ削除
        rm "$link"
        info "シンボリックリンクを削除: $link"
        
        # バックアップから復元
        if [ "$RESTORE" = true ]; then
            # 最新のバックアップファイルを探す
            local backup_pattern="${link}.backup.*"
            local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -n1)
            
            if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
                mv "$latest_backup" "$link"
                info "バックアップから復元: $latest_backup -> $link"
            fi
        fi
    else
        warn "シンボリックリンクではありません（スキップ）: $link"
    fi
}

echo ""
info "dotfilesのアンインストールを開始します..."
echo ""

# アンインストール対象のファイル
remove_symlink "$HOME/.zshrc"
remove_symlink "$HOME/.zprofile"
remove_symlink "$HOME/.gitconfig"
remove_symlink "$HOME/.config/gh"

echo ""
info "dotfilesのアンインストールが完了しました！"

# バックアップファイルの情報
if [ "$RESTORE" = false ]; then
    echo ""
    echo "バックアップファイルが残っている場合があります:"
    echo "  ~/.*.backup.*"
    echo ""
    echo "手動で削除するか、--restore オプションで復元できます"
fi