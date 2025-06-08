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
Usage: ./install.sh [OPTIONS]

Options:
    -h, --help      このヘルプを表示
    -f, --force     確認なしでインストール
    -b, --backup    既存ファイルをバックアップ（デフォルト）
    -n, --no-backup バックアップを作成しない

Example:
    ./install.sh            # 通常のインストール（バックアップあり）
    ./install.sh --force    # 確認なしでインストール
    ./install.sh --no-backup # バックアップなしでインストール
EOF
}

# オプション解析
FORCE=false
BACKUP=true

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
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -n|--no-backup)
            BACKUP=false
            shift
            ;;
        *)
            error "不明なオプション: $1"
            ;;
    esac
done

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ファイル存在チェック関数
validate_files() {
    local missing_files=()
    
    # 必須ファイルのチェック
    local required_files=(
        ".zshrc"
        ".zprofile"
        "git/gitconfig"
        "config/gh/config.yml"
        "config/gh/hosts.yml"
        "tmux/tmux.conf"
        "vim/vimrc"
        "ssh/config"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$DOTFILES_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "必須ファイルが見つかりません: ${missing_files[*]}"
        echo "リポジトリが破損している可能性があります。"
        return 1
    fi
    
    info "ファイル存在チェック完了"
    return 0
}

# ファイル存在チェックを実行
validate_files

# 確認プロンプト
if [ "$FORCE" = false ]; then
    echo "以下のディレクトリからdotfilesをインストールします:"
    echo "  $DOTFILES_DIR"
    echo ""
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "インストールをキャンセルしました"
        exit 0
    fi
fi

# シンボリックリンクを作成する関数
create_symlink() {
    local src="$1"
    local dest="$2"
    
    # 既存のファイルやリンクがある場合の処理
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$BACKUP" = true ]; then
            local backup_file="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
            warn "既存のファイルをバックアップ: $dest -> $backup_file"
            mv "$dest" "$backup_file"
        else
            warn "既存のファイルを削除: $dest"
            rm -rf "$dest"
        fi
    fi
    
    # ディレクトリが存在しない場合は作成
    local dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        info "ディレクトリを作成: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    # シンボリックリンクを作成
    ln -sf "$src" "$dest"
    info "シンボリックリンク作成: $src -> $dest"
}

echo ""
info "dotfilesのインストールを開始します..."
echo ""

# ホームディレクトリ直下のドットファイル
create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"

# Git設定
create_symlink "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

# .configディレクトリの設定
create_symlink "$DOTFILES_DIR/config/gh" "$HOME/.config/gh"

# tmux設定
create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# Vim設定
create_symlink "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"

# SSH設定
create_symlink "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"

# SSH接続用ディレクトリを作成
if [ ! -d "$HOME/.ssh/sockets" ]; then
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh/sockets"
    info "SSH socket ディレクトリを作成: ~/.ssh/sockets"
fi

# AWS設定は手動でテンプレートからコピー
# create_symlink "$DOTFILES_DIR/aws/config" "$HOME/.aws/config"

echo ""
info "dotfilesのインストールが完了しました！"
echo ""
echo "次のステップ:"
echo "  1. 新しいターミナルを開く"
echo "  2. または 'source ~/.zshrc' を実行して設定を反映"
echo ""

# ローカル設定ファイルの案内
if [ ! -f "$HOME/.zshrc.local" ]; then
    info "ヒント: マシン固有の設定は ~/.zshrc.local に記述できます"
fi

if [ ! -f "$HOME/.gitconfig.local" ]; then
    warn "重要: Git ユーザー情報を ~/.gitconfig.local に設定してください"
    echo "例:"
    echo "  [user]"
    echo "      name = Your Name"
    echo "      email = your.email@example.com"
fi

if [ ! -f "$HOME/.env.local" ]; then
    info "ヒント: プロジェクト固有の環境変数は ~/.env.local に記述できます"
    echo "例:"
    echo "  export DBT_PROJECT_ID=your-project-id"
    echo "  export DBT_DATA_POLICY_TAG_ID=your-tag-id"
fi

if [ ! -f "$HOME/.aws/config" ]; then
    warn "重要: AWS設定ファイルを ~/.aws/config に作成してください"
    echo "テンプレートファイルを参考にしてください:"
    echo "  cp $DOTFILES_DIR/aws/config.template ~/.aws/config"
    echo "  # その後、実際の値を入力してください"
fi

if [ ! -f "$HOME/.aws/credentials" ]; then
    warn "重要: AWS認証情報を ~/.aws/credentials に設定してください"
    echo "テンプレートファイルを参考にしてください:"
    echo "  cp $DOTFILES_DIR/aws/credentials.template ~/.aws/credentials"
    echo "  # その後、実際の認証情報を入力してください"
fi

# 補完用ディレクトリの作成
mkdir -p "$HOME/.zsh/cache"

info "推奨ツールのインストール案内:"
echo "  brew install fzf eza bat ripgrep fd-find"