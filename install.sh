#!/bin/bash

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# シンボリックリンクを作成する関数
create_symlink() {
    local src="$1"
    local dest="$2"
    
    # 既存のファイルやリンクがある場合はバックアップ
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        echo "既存のファイルをバックアップ: $dest -> ${dest}.backup"
        mv "$dest" "${dest}.backup"
    fi
    
    # シンボリックリンクを作成
    ln -sf "$src" "$dest"
    echo "シンボリックリンク作成: $src -> $dest"
}

echo "dotfilesのセットアップを開始します..."

# ホームディレクトリ直下のドットファイル
create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
# .viminfoは個人的な履歴ファイルのため除外

# .configディレクトリの作成とシンボリックリンク
mkdir -p "$HOME/.config"
create_symlink "$DOTFILES_DIR/.config/gh" "$HOME/.config/gh"

echo "dotfilesのセットアップが完了しました！"
echo "新しいターミナルを開くか、'source ~/.zshrc'を実行して設定を反映してください。"