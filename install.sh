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
    -h, --help          このヘルプを表示
    -f, --force         確認なしでインストール
    -b, --backup        既存ファイルをバックアップ（デフォルト）
    -n, --no-backup     バックアップを作成しない
    -c, --clean-backup  インストール後にバックアップファイルを削除
    -d, --dry-run       実際には変更を加えずに動作を確認
    --check-deps        依存関係のチェックのみ実行

Example:
    ./install.sh                # 通常のインストール（バックアップあり）
    ./install.sh --force        # 確認なしでインストール
    ./install.sh --no-backup    # バックアップなしでインストール
    ./install.sh --clean-backup # インストール後にバックアップを削除
    ./install.sh --dry-run      # 実際には変更を加えずに動作確認
    ./install.sh --check-deps   # 依存関係のチェックのみ
EOF
}

# オプション解析
FORCE=false
BACKUP=true
CLEAN_BACKUP=false
DRY_RUN=false
CHECK_DEPS_ONLY=false

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
        -c|--clean-backup)
            CLEAN_BACKUP=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --check-deps)
            CHECK_DEPS_ONLY=true
            shift
            ;;
        *)
            error "不明なオプション: $1"
            ;;
    esac
done

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依存関係チェック関数
check_dependencies() {
    local missing_deps=()
    
    # 必須コマンドのチェック
    local required_commands=(
        "git"
        "zsh"
        "curl"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # 推奨コマンドのチェック
    local recommended_commands=(
        "brew"
        "fzf"
        "eza"
        "bat"
        "rg"
        "fd"
        "gh"
        "aws"
        "mise"
    )
    
    local missing_recommended=()
    for cmd in "${recommended_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_recommended+=("$cmd")
        fi
    done
    
    # 結果を表示
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "必須コマンドが見つかりません: ${missing_deps[*]}"
        echo "これらのコマンドをインストールしてから再実行してください。"
        return 1
    fi
    
    if [[ ${#missing_recommended[@]} -gt 0 ]]; then
        warn "推奨コマンドが見つかりません: ${missing_recommended[*]}"
        echo "これらのコマンドは後でインストールすることをお勧めします。"
        echo ""
    fi
    
    info "依存関係チェック完了"
    return 0
}

# 依存関係チェックのみモード
if [ "$CHECK_DEPS_ONLY" = true ]; then
    info "依存関係をチェックしています..."
    check_dependencies
    exit $?
fi

# ファイル存在チェック関数
validate_files() {
    local missing_files=()
    
    # 必須ファイルのチェック
    local required_files=(
        ".zshrc"
        ".zprofile"
        "config/git/gitconfig"
        "config/gh/config.yml"
        "config/gh/hosts.yml"
        "config/tmux/tmux.conf"
        "config/vim/vimrc"
        "config/ssh/config"
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

# 依存関係チェックを実行
check_dependencies

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
    
    # ソースファイルが存在するかチェック
    if [ ! -e "$src" ]; then
        error "ソースファイルが存在しません: $src"
        return 1
    fi
    
    # バックアップファイルは対象外
    if [[ "$src" == *.backup.* ]]; then
        warn "バックアップファイルはスキップ: $src"
        return 0
    fi
    
    # 既にシンボリックリンクが存在し、同じ場所を指している場合はスキップ
    if [ -L "$dest" ]; then
        local current_link=$(readlink "$dest")
        if [ "$current_link" = "$src" ]; then
            info "既に正しくリンクされています: $dest -> $src"
            return 0
        fi
    fi
    
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
    
    # ドライランモードのチェック
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] シンボリックリンク作成: $src -> $dest"
        return 0
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
create_symlink "$DOTFILES_DIR/.inputrc" "$HOME/.inputrc"
create_symlink "$DOTFILES_DIR/.editorconfig" "$HOME/.editorconfig"

# fzf設定
create_symlink "$DOTFILES_DIR/config/fzf/fzf.zsh" "$HOME/.fzf.zsh"

# Git設定
create_symlink "$DOTFILES_DIR/config/git/gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"

# .configディレクトリの設定
create_symlink "$DOTFILES_DIR/config/gh" "$HOME/.config/gh"

# Claude設定
if [ -f "$DOTFILES_DIR/config/claude/claude_desktop_config.json.local" ]; then
    create_symlink "$DOTFILES_DIR/config/claude/claude_desktop_config.json.local" "$HOME/.config/claude/claude_desktop_config.json"
else
    create_symlink "$DOTFILES_DIR/config/claude/claude_desktop_config.json" "$HOME/.config/claude/claude_desktop_config.json"
fi

# tmux設定
create_symlink "$DOTFILES_DIR/config/tmux/tmux.conf" "$HOME/.tmux.conf"

# Vim設定
create_symlink "$DOTFILES_DIR/config/vim/vimrc" "$HOME/.vimrc"

# SSH設定
create_symlink "$DOTFILES_DIR/config/ssh/config" "$HOME/.ssh/config"

# SSH接続用ディレクトリを作成
if [ ! -d "$HOME/.ssh/sockets" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] SSH socket ディレクトリを作成: ~/.ssh/sockets"
    else
        mkdir -p "$HOME/.ssh/sockets"
        chmod 700 "$HOME/.ssh/sockets"
        info "SSH socket ディレクトリを作成: ~/.ssh/sockets"
    fi
fi

# Claude Desktop設定
if [ ! -d "$HOME/.claude" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Claude ディレクトリを作成: ~/.claude"
    else
        mkdir -p "$HOME/.claude"
        info "Claude ディレクトリを作成: ~/.claude"
    fi
fi
create_symlink "$DOTFILES_DIR/config/claude/settings.json" "$HOME/.claude/settings.json"

# Claude ユーザー固有コマンドのシンボリックリンク作成
create_symlink "$DOTFILES_DIR/config/claude/commands" "$HOME/.claude/commands"

# Git hooks（dotfilesリポジトリ用）
if [ -d "$DOTFILES_DIR/git/hooks" ]; then
    info "Git hooksをセットアップしています..."
    # .git/hooks ディレクトリが存在することを確認
    if [ -d "$DOTFILES_DIR/.git/hooks" ]; then
        for hook in "$DOTFILES_DIR/git/hooks"/*; do
            if [ -f "$hook" ]; then
                hook_name=$(basename "$hook")
                create_symlink "$hook" "$DOTFILES_DIR/.git/hooks/$hook_name"
            fi
        done
    fi
fi

# mise設定
create_symlink "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"

# Codex CLI設定
if [ ! -d "$HOME/.codex" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Codex ディレクトリを作成: ~/.codex"
    else
        mkdir -p "$HOME/.codex"
        info "Codex ディレクトリを作成: ~/.codex"
    fi
fi
create_symlink "$DOTFILES_DIR/config/codex/config.toml" "$HOME/.codex/config.toml"
create_symlink "$DOTFILES_DIR/config/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"

# Codex CLIカスタムプロンプト
if [ ! -d "$HOME/.codex/prompts" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Codex プロンプトディレクトリを作成: ~/.codex/prompts"
    else
        mkdir -p "$HOME/.codex/prompts"
        info "Codex プロンプトディレクトリを作成: ~/.codex/prompts"
    fi
fi
create_symlink "$DOTFILES_DIR/config/codex/prompts/create-pr-pro.md" "$HOME/.codex/prompts/create-pr-pro.md"

# AWS設定は手動でテンプレートからコピー
# create_symlink "$DOTFILES_DIR/config/aws/config" "$HOME/.aws/config"

# ============================================================================
# binディレクトリのコマンドに実行権限を付与
# ============================================================================
info "binディレクトリのコマンドに実行権限を付与"
if [ -d "$DOTFILES_DIR/bin" ]; then
    for cmd in "$DOTFILES_DIR/bin"/*; do
        if [ -f "$cmd" ]; then
            if [ "$DRY_RUN" = true ]; then
                info "[DRY RUN] $(basename "$cmd") に実行権限を付与"
            else
                chmod +x "$cmd"
                info "$(basename "$cmd") に実行権限を付与"
            fi
        fi
    done
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    info "ドライランモードでの確認が完了しました！"
    echo ""
    echo "実際にインストールするには、--dry-run オプションなしで実行してください。"
else
    info "dotfilesのインストールが完了しました！"
fi
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
    echo "  cp $DOTFILES_DIR/config/aws/config.template ~/.aws/config"
    echo "  # その後、実際の値を入力してください"
fi

if [ ! -f "$HOME/.aws/credentials" ]; then
    warn "重要: AWS認証情報を ~/.aws/credentials に設定してください"
    echo "テンプレートファイルを参考にしてください:"
    echo "  cp $DOTFILES_DIR/config/aws/credentials.template ~/.aws/credentials"
    echo "  # その後、実際の認証情報を入力してください"
fi

if [ ! -f "$DOTFILES_DIR/config/claude/claude_desktop_config.json.local" ]; then
    warn "重要: Claude MCP設定をカスタマイズする場合は claude_desktop_config.json.local を作成してください"
    echo "テンプレートファイルを参考にしてください:"
    echo "  cp $DOTFILES_DIR/config/claude/claude_desktop_config.json.local.example $DOTFILES_DIR/config/claude/claude_desktop_config.json.local"
    echo "  # その後、実際のAPIトークンを入力してください"
fi

if ! command -v codex &> /dev/null; then
    info "ヒント: Codex CLIをインストールしてください"
    echo "インストール方法:"
    echo "  # npmを使用する場合"
    echo "  npm install -g @openai/codex"
    echo "  # またはHomebrewを使用する場合"
    echo "  brew install codex"
    echo ""
    echo "設定ファイルは既に配置されています:"
    echo "  - ~/.codex/config.toml (基本設定)"
    echo "  - ~/.codex/AGENTS.md (カスタムインストラクション)"
fi

# 補完用ディレクトリの作成
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$HOME/.zsh/cache"
fi

# バックアップファイルの削除（安全化版）
if [ "$CLEAN_BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
    info "バックアップファイルを検索しています..."

    # 削除対象ファイルを一時ファイルに保存
    temp_list=$(mktemp)
    /usr/bin/find "$HOME" -maxdepth 3 -name '*backup*' \( -type f -o -type l -o -type d \) \
        -not -path "$HOME/Library/*" \
        -not -path "$HOME/.Trash/*" \
        -not -path "$HOME/Pictures/*" \
        2>/dev/null > "$temp_list"

    file_count=$(wc -l < "$temp_list" | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        info "削除対象のバックアップファイルは見つかりませんでした"
        rm -f "$temp_list"
    else
        echo ""
        warn "以下の${file_count}個のバックアップファイル/ディレクトリが見つかりました:"
        head -20 "$temp_list"
        if [ "$file_count" -gt 20 ]; then
            echo "... 他 $((file_count - 20)) 件"
        fi
        echo ""
        read -p "これらを削除してもよろしいですか？ (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "バックアップファイルを削除しています..."
            deleted_count=0
            while IFS= read -r file; do
                if [ -e "$file" ] || [ -L "$file" ]; then
                    if rm -rf "$file" 2>/dev/null; then
                        ((deleted_count++))
                        info "削除: $file"
                    else
                        warn "削除失敗: $file"
                    fi
                fi
            done < "$temp_list"
            info "バックアップファイルの削除が完了しました（${deleted_count}/${file_count}件）"
        else
            info "削除をキャンセルしました"
        fi

        rm -f "$temp_list"
    fi
else
    # バックアップファイルの削除案内
    backup_files=$(/usr/bin/find "$HOME" -maxdepth 3 -name "*backup*" \( -type f -o -type l -o -type d \) -not -path "$HOME/Library/*" -not -path "$HOME/.Trash/*" -not -path "$HOME/Pictures/*" 2>/dev/null | head -10)
    if [ -n "$backup_files" ]; then
        echo ""
        warn "バックアップファイルが見つかりました:"
        echo "$backup_files"
        echo ""
        echo "不要な場合は以下のコマンドで削除できます:"
        echo "  ./install.sh --clean-backup  # 確認プロンプト付きで安全に削除"
    fi
fi

info "推奨ツールのインストール案内:"
echo "  # パッケージマネージャー"
echo "  curl https://mise.run | sh"
echo "  mise install"
echo ""
echo "  # その他のツール"
echo "  brew install fzf eza bat ripgrep fd-find"
