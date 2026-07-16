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
    --brew              Brewfileからツールをインストール

Example:
    ./install.sh                # 通常のインストール（バックアップあり）
    ./install.sh --force        # 確認なしでインストール
    ./install.sh --no-backup    # バックアップなしでインストール
    ./install.sh --clean-backup # インストール後にバックアップを削除
    ./install.sh --dry-run      # 実際には変更を加えずに動作確認
    ./install.sh --check-deps   # 依存関係のチェックのみ
    ./install.sh --brew         # Brewfileからツールをインストール
EOF
}

# オプション解析
FORCE=false
BACKUP=true
CLEAN_BACKUP=false
DRY_RUN=false
CHECK_DEPS_ONLY=false
BREW_INSTALL=false

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
        --brew)
            BREW_INSTALL=true
            shift
            ;;
        *)
            error "不明なオプション: $1"
            ;;
    esac
done

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 対話式インストーラで追加されるツールをスクリプトの後半からも見えるようにする
# (Homebrew / Claude Code / Deno / mise shims 等)
export PATH="$HOME/.local/bin:$HOME/.deno/bin:$PATH"
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Homebrew インストール関数
# - 未導入時のみ実行 (冪等性)
# - FORCE=false かつ TTY 有りなら確認プロンプトを出す
# - 失敗しても set -e で全体を止めないよう、呼び出し側で `|| true` する
install_homebrew() {
    if command -v brew &> /dev/null; then
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Homebrew をインストール"
        return 0
    fi

    if [ "$FORCE" = false ] && [ -t 0 ]; then
        echo ""
        echo -n "Homebrewがありません。インストールしますか？ (Y/n): "
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            warn "Homebrewインストールをスキップします"
            return 1
        fi
    fi

    # NONINTERACTIVE=1 は sudo -n (パスワードキャッシュ済み前提) を強制するため、
    # 事前に sudo -v で認証を済ませておく必要がある。これがないと macOS admin ユーザー
    # でも "Need sudo access" で失敗する
    info "sudoパスワードを入力してください (Homebrewが /opt/homebrew を作成するために必要)"
    if ! sudo -v; then
        warn "sudo認証に失敗しました。Homebrewインストールを中止します"
        return 1
    fi
    # sudo credential を維持するバックグラウンドプロセスを起動
    # (Homebrew インストールが数分かかる間にキャッシュが切れないように)
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
    local sudo_keepalive_pid=$!
    # bash の job control による "Terminated: 15" メッセージを抑制
    disown "$sudo_keepalive_pid" 2>/dev/null || true
    # サブシェル終了時に必ずバックグラウンドプロセスを止める
    trap 'kill "$sudo_keepalive_pid" 2>/dev/null || true' RETURN

    info "Homebrewをインストール中..."
    if ! NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        warn "Homebrewのインストールに失敗しました"
        return 1
    fi

    # brew を現在のシェルの PATH に追加 (これがないと以降の brew コマンドが失敗する)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    info "Homebrewインストール完了"
}

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
        "git-filter-repo"
        "gitleaks"
        "op"
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

# Brewfileからツールをインストール
if [ "$BREW_INSTALL" = true ]; then
    if ! command -v brew &> /dev/null; then
        error "Homebrewがインストールされていません"
        echo "インストール: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    info "Brewfileからツールをインストールしています..."
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] brew bundle install --file=$DOTFILES_DIR/Brewfile"
    else
        brew bundle install --file="$DOTFILES_DIR/Brewfile"
        info "ツールのインストールが完了しました"
    fi
    exit 0
fi

# ファイル存在チェック関数
validate_files() {
    local missing_files=()
    
    # 必須ファイルのチェック
    local required_files=(
        ".zshrc"
        ".zprofile"
        ".zshenv"
        "config/git/gitconfig"
        "config/gh/config.yml"
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
    echo -n "続行しますか？ (y/N): "
    read -n 1 -r
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
    
    # ディレクトリが存在しない場合は作成
    local dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] ディレクトリを作成: $dest_dir"
        else
            info "ディレクトリを作成: $dest_dir"
            mkdir -p "$dest_dir"
        fi
    fi

    # 既存のファイルやリンクがある場合の処理
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$BACKUP" = true ]; then
            local backup_file="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
            if [ "$DRY_RUN" = true ]; then
                warn "[DRY RUN] 既存のファイルをバックアップ: $dest -> $backup_file"
            else
                warn "既存のファイルをバックアップ: $dest -> $backup_file"
                mv "$dest" "$backup_file"
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                warn "[DRY RUN] 既存のファイルを削除: $dest"
            else
                warn "既存のファイルを削除: $dest"
                rm -rf "$dest"
            fi
        fi
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
create_symlink "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
create_symlink "$DOTFILES_DIR/.inputrc" "$HOME/.inputrc"
create_symlink "$DOTFILES_DIR/.editorconfig" "$HOME/.editorconfig"

# fzf設定
create_symlink "$DOTFILES_DIR/config/fzf/fzf.zsh" "$HOME/.fzf.zsh"

# Git設定
create_symlink "$DOTFILES_DIR/config/git/gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"

# .configディレクトリの設定
create_symlink "$DOTFILES_DIR/config/gh" "$HOME/.config/gh"

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
create_symlink "$DOTFILES_DIR/config/claude/statusline.py" "$HOME/.claude/statusline.py"

# Claude Skills
create_symlink "$DOTFILES_DIR/config/claude/skills" "$HOME/.claude/skills"

# Claude Rules（ワークフロー・協業ルール）
create_symlink "$DOTFILES_DIR/config/claude/rules" "$HOME/.claude/rules"

# Claude Contexts（--system-prompt用コンテキストファイル）
create_symlink "$DOTFILES_DIR/config/claude/contexts" "$HOME/.claude/contexts"

# Claude グローバル設定
create_symlink "$DOTFILES_DIR/config/claude/GLOBAL_SETTINGS.md" "$HOME/.claude/CLAUDE.md"

# Git hooks（core.hooksPathでグローバル適用）
if [ -d "$DOTFILES_DIR/git/hooks" ]; then
    info "Git hooksをセットアップしています..."
    for hook in "$DOTFILES_DIR/git/hooks"/*; do
        if [ -f "$hook" ] && [ ! -x "$hook" ]; then
            if [ "$DRY_RUN" = true ]; then
                info "[DRY RUN] $(basename "$hook") に実行権限を付与"
            else
                chmod +x "$hook"
                info "$(basename "$hook") に実行権限を付与"
            fi
        fi
    done
    # core.hooksPathを動的に設定（ghq rootに依存しない）
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] git config --global core.hooksPath $DOTFILES_DIR/git/hooks"
    else
        git config --global core.hooksPath "$DOTFILES_DIR/git/hooks"
        info "core.hooksPath を設定: $DOTFILES_DIR/git/hooks"
    fi
fi

# mise設定
create_symlink "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"

# direnv設定
if [ ! -d "$HOME/.config/direnv" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] direnv ディレクトリを作成: ~/.config/direnv"
    else
        mkdir -p "$HOME/.config/direnv"
        info "direnv ディレクトリを作成: ~/.config/direnv"
    fi
fi
create_symlink "$DOTFILES_DIR/config/direnv/direnvrc" "$HOME/.config/direnv/direnvrc"

# npmrc設定（pnpmも読む。サプライチェーン対策）
create_symlink "$DOTFILES_DIR/config/npm/npmrc" "$HOME/.npmrc"

# uv設定（サプライチェーン対策）
create_symlink "$DOTFILES_DIR/config/uv/uv.toml" "$HOME/.config/uv/uv.toml"

# Ghostty設定
create_symlink "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

# lazygit設定
create_symlink "$DOTFILES_DIR/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"

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
create_symlink "$DOTFILES_DIR/config/codex/hooks.json" "$HOME/.codex/hooks.json"

# Codex Rules（コマンド実行ポリシー）
if [ ! -d "$HOME/.codex/rules" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Codex Rules ディレクトリを作成: ~/.codex/rules"
    else
        mkdir -p "$HOME/.codex/rules"
        info "Codex Rules ディレクトリを作成: ~/.codex/rules"
    fi
fi
create_symlink "$DOTFILES_DIR/config/codex/rules/dotfiles.rules" "$HOME/.codex/rules/dotfiles.rules"

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

# Codex Agents（サブエージェント）
if [ ! -d "$HOME/.codex/agents" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Codex Agents ディレクトリを作成: ~/.codex/agents"
    else
        mkdir -p "$HOME/.codex/agents"
        info "Codex Agents ディレクトリを作成: ~/.codex/agents"
    fi
fi
if [ -d "$DOTFILES_DIR/config/codex/agents" ]; then
    while IFS= read -r agent_file; do
        agent_name="$(basename "$agent_file")"
        create_symlink "$agent_file" "$HOME/.codex/agents/$agent_name"
    done < <(find "$DOTFILES_DIR/config/codex/agents" -maxdepth 1 -name '*.toml' -type f | sort)
fi

# Claude Rules / Contexts を Codex から参照できるようにする
create_symlink "$DOTFILES_DIR/config/claude/rules" "$HOME/.codex/claude-rules"
create_symlink "$DOTFILES_DIR/config/claude/contexts" "$HOME/.codex/contexts"

# Codex Skills（ユーザー層: ~/.agents/skills、freee-api-skill 等の lock 管理 skill と共存させるため個別 symlink）
if [ ! -d "$HOME/.agents/skills" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Codex Skills ディレクトリを作成: ~/.agents/skills"
    else
        mkdir -p "$HOME/.agents/skills"
        info "Codex Skills ディレクトリを作成: ~/.agents/skills"
    fi
fi
if [ -d "$DOTFILES_DIR/config/codex/skills" ]; then
    while IFS= read -r skill_dir; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        skill_name="$(basename "$skill_dir")"
        create_symlink "$skill_dir" "$HOME/.agents/skills/$skill_name"
    done < <(find "$DOTFILES_DIR/config/codex/skills" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# Claude Skills を Codex Skills としても公開する
if [ -d "$DOTFILES_DIR/config/claude/skills" ]; then
    while IFS= read -r skill_dir; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        skill_name="$(basename "$skill_dir")"
        create_symlink "$skill_dir" "$HOME/.agents/skills/$skill_name"
    done < <(find "$DOTFILES_DIR/config/claude/skills" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# ============================================================================
# dotfiles-private（機密設定ファイルのシンボリックリンク）
# ============================================================================
PRIVATE_DIR="$(cd "$DOTFILES_DIR/.." && pwd)/dotfiles-private"
if [ -d "$PRIVATE_DIR" ]; then
    info "dotfiles-private を検出。機密設定ファイルをリンクしています..."
    while IFS= read -r src; do
        rel="${src#$PRIVATE_DIR/}"
        dest="$DOTFILES_DIR/$rel"
        create_symlink "$src" "$dest"
    done < <(find "$PRIVATE_DIR" -name '*.local.md' -type f -not -path "$PRIVATE_DIR/projects/*")

    # claude-review-coverage allowlist は dotfiles 側のディレクトリ構造と
    # リンク先 ($HOME/.config/...) が一致しないので個別にリンクする
    ALLOWLIST_SRC="$PRIVATE_DIR/config/claude-review-coverage/allowlist.local"
    if [ -f "$ALLOWLIST_SRC" ]; then
        create_symlink "$ALLOWLIST_SRC" "$HOME/.config/claude-review-coverage/allowlist"
    fi

    # projects/ 配下はプロジェクトリポジトリ（~/gh/ 配下）へのミラーリンク
    # 例: projects/github.com/<owner>/<repo>/.claude/skills/foo/SKILL.local.md
    #       -> ~/gh/github.com/<owner>/<repo>/.claude/skills/foo/SKILL.local.md
    # リポジトリ未clone時はリンクを作らず警告のみ（clone後に install.sh 再実行で解消）
    if [ -d "$PRIVATE_DIR/projects" ]; then
        while IFS= read -r src; do
            rel="${src#$PRIVATE_DIR/projects/}"
            repo=$(echo "$rel" | cut -d/ -f1-3)
            if [ -d "$HOME/gh/$repo" ]; then
                create_symlink "$src" "$HOME/gh/$rel"
            else
                warn "projects リンク先リポジトリが未clone: ~/gh/$repo (ghq get $repo)"
            fi
        done < <(find "$PRIVATE_DIR/projects" -name '*.local.*' -type f)
    fi
else
    warn "dotfiles-private が見つかりません (ghq get ryosukesuto/dotfiles-private)"
fi

# orphanチェック: シンボリックリンクでない *.local.md を検出
while IFS= read -r orphan; do
    warn "orphan検出: $orphan（dotfiles-private に移動してください）"
done < <(find "$DOTFILES_DIR" -name '*.local.md' -not -path '*/.git/*' -type f ! -type l 2>/dev/null)

# ============================================================================
# binディレクトリのコマンドに実行権限を付与
# ============================================================================
if [ -d "$DOTFILES_DIR/bin" ]; then
    for cmd in "$DOTFILES_DIR/bin"/*; do
        if [ -f "$cmd" ]; then
            if [ -x "$cmd" ]; then
                # 既に実行権限がある場合はスキップ（冪等性）
                :
            elif [ "$DRY_RUN" = true ]; then
                info "[DRY RUN] $(basename "$cmd") に実行権限を付与"
            else
                chmod +x "$cmd"
                info "$(basename "$cmd") に実行権限を付与"
            fi
        fi
    done
fi

# ============================================================================
# Homebrew と brewパッケージのインストール
# ============================================================================
# Homebrew を未導入なら入れる。失敗しても以降を継続 (mise/pnpm チェーンは
# brew に依存するが、手動で他手段を用意しているユーザーも許容する)
install_homebrew || true

if command -v brew &> /dev/null && [ -f "$DOTFILES_DIR/Brewfile" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] brew bundle install --file=$DOTFILES_DIR/Brewfile"
    else
        # Homebrew 5.0+ は第三者tapに明示的な trust を要求する
        # Brewfile 内の `tap "..."` 宣言と `brew "user/tap/name"` 形式から
        # taps を抽出して自動 trust する。これがないと `k1low/tap/git-wt` 等が
        # "Refusing to load formula ... from untrusted tap" で失敗する
        if brew trust --help &> /dev/null; then
            info "第三者tapを trust しています..."
            while IFS= read -r tap; do
                [ -n "$tap" ] || continue
                brew tap "$tap" &> /dev/null || true
                brew trust "$tap" &> /dev/null || true
            done < <(
                {
                    grep -oE '^tap "[^"]+"' "$DOTFILES_DIR/Brewfile" \
                        | sed -E 's/tap "([^"]+)"/\1/'
                    grep -oE '^brew "[^"]+/[^"]+/[^"]+"' "$DOTFILES_DIR/Brewfile" \
                        | sed -E 's|brew "([^/]+/[^/]+)/.*|\1|'
                    grep -oE '^cask "[^"]+/[^"]+/[^"]+"' "$DOTFILES_DIR/Brewfile" \
                        | sed -E 's|cask "([^/]+/[^/]+)/.*|\1|'
                } | tr '[:upper:]' '[:lower:]' | sort -u
            )
        fi

        # mise は Node.js/pnpm チェーンの起点なので、bundle失敗時の fallback として
        # 先に個別installしておく (brew bundle は formula 検証を先に行うため、
        # 1件でも missing formula があると mise を含む全体が install されない)
        if ! command -v mise &> /dev/null; then
            info "mise を先行installしています..."
            brew install mise 2>/dev/null || warn "mise の先行installに失敗しました"
        fi

        info "Brewfile からツールをインストール中... (初回は数分かかります)"
        if brew bundle install --file="$DOTFILES_DIR/Brewfile"; then
            info "brew bundle install 完了"
        else
            warn "brew bundle install が一部失敗しました (詳細: ./install.sh --brew で再実行)"
        fi
    fi
elif ! command -v brew &> /dev/null; then
    warn "Homebrew が使えないため brew bundle をスキップしました"
fi

# ============================================================================
# miseでツールをインストール
# ============================================================================
if command -v mise &> /dev/null; then
    # mise shims を現在のシェルの PATH に追加
    # (これがないと直後の corepack / node が command -v で見つからない)
    export PATH="$HOME/.local/share/mise/shims:$PATH"

    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] mise install を実行"
    else
        info "mise でツールをインストール中..."
        if mise install --yes; then
            info "mise install 完了"
        else
            warn "mise install に失敗しました（後で手動実行してください）"
        fi
    fi
else
    warn "mise が見つかりません。Homebrew インストール後に再実行してください"
fi

# ============================================================================
# pnpmセットアップ（corepack経由）
# ============================================================================
if command -v corepack &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] corepack enable pnpm を実行"
    else
        info "corepack で pnpm を有効化中..."
        if corepack enable pnpm; then
            info "pnpm の有効化完了"
            # mise 管理下の corepack が新しく作った pnpm shim を mise の shims に登録
            # (これがないと直後の `command -v pnpm` が見つけられない)
            if command -v mise &> /dev/null; then
                mise reshim 2>/dev/null || true
            fi
        else
            warn "pnpm の有効化に失敗しました"
        fi
    fi
    # PNPM_HOME ディレクトリを作成
    PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    if [ ! -d "$PNPM_HOME" ]; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] PNPM_HOME ディレクトリを作成: $PNPM_HOME"
        else
            mkdir -p "$PNPM_HOME"
            info "PNPM_HOME ディレクトリを作成: $PNPM_HOME"
        fi
    fi
else
    warn "corepack が見つかりません。Node.js インストール後に再実行してください"
fi

# ============================================================================
# Claude Codeのインストール（ネイティブインストール）
# ============================================================================
if ! command -v claude &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Claude Code をインストール（ネイティブ）"
    else
        info "Claude Code をインストール中（ネイティブインストール）..."
        curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null && \
            info "Claude Code のインストール完了" || \
            warn "Claude Code のインストールに失敗しました"
    fi
else
    info "Claude Code は既にインストールされています"
fi

# ============================================================================
# Codex CLIのインストール（公式standalone installer）
# ============================================================================
# pnpmはnpmrcのminimum-release-ageを尊重するため、最新版をすぐ導入できる
# standalone installerを使用する。
# 同じコマンドで新規インストールと更新の両方を行う。
# 公式ドキュメント: https://learn.chatgpt.com/docs/codex/cli
codex_install_succeeded=false
if [ "$DRY_RUN" = true ]; then
    info "[DRY RUN] Codex CLI をインストールまたは更新（standalone）"
else
    info "Codex CLI をインストールまたは更新中（standalone）..."
    if (set -o pipefail; curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh); then
        codex_install_succeeded=true
        info "Codex CLI のインストールまたは更新完了"
    else
        warn "Codex CLI のインストールまたは更新に失敗しました"
    fi
fi

# 旧pnpm版が残っているとPNPM_HOMEのPATH優先度によりstandalone版を隠すため、
# standalone版の導入成功後に削除する。
if command -v pnpm &> /dev/null; then
    codex_pnpm_root=$(pnpm root -g 2>/dev/null || true)
    if [ -n "$codex_pnpm_root" ] && [ -d "$codex_pnpm_root/@openai/codex" ]; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] 旧pnpm版 @openai/codex を削除"
        elif [ "$codex_install_succeeded" = true ]; then
            if pnpm remove -g @openai/codex > /dev/null 2>&1; then
                info "旧pnpm版 @openai/codex の削除完了"
            else
                warn "旧pnpm版 @openai/codex の削除に失敗しました"
            fi
        fi
    fi
fi

# ============================================================================
# Denoのインストール
# ============================================================================
if ! command -v deno &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Deno をインストール"
    else
        info "Deno をインストール中..."
        # Deno installer は "Edit shell configs..." で対話プロンプトを出す。
        # dotfiles の zsh/20-path.zsh で ~/.deno/bin を PATH に追加済みなので
        # shell config 変更は不要 (n を回答)
        DENO_INSTALLER=$(mktemp)
        if curl -fsSL https://deno.land/install.sh -o "$DENO_INSTALLER" 2>/dev/null && \
           yes n 2>/dev/null | bash "$DENO_INSTALLER" > /dev/null 2>&1; then
            info "Deno のインストール完了"
        else
            warn "Deno のインストールに失敗しました"
        fi
        rm -f "$DENO_INSTALLER"
    fi
else
    info "Deno は既にインストールされています"
fi

# Deno installer は yes n が効かない環境でも .zshrc / .zprofile に env source を
# 追記することがある。dotfiles で PATH 管理しているため重複除去する
# (行例: `. "/Users/suto.ryosuke/.deno/env"`)
# 注意: macOS の sed -i は symlink に対応しないため、grep + リダイレクトで実装する
# (dotfiles管理下のファイルは symlink 経由のため sed -i.bak では失敗する)
for shell_rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$shell_rc" ] || continue
    if grep -qE '^\. +"[^"]*/\.deno/env"' "$shell_rc" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] Deno env source 行を削除: $shell_rc"
        else
            deno_tmp=$(mktemp)
            # 該当行を除いた内容を tmp に書き出し、symlink 経由で書き戻す
            # (`>` は symlink を辿って target file を書き換える)
            grep -vE '^\. +"[^"]*/\.deno/env"' "$shell_rc" > "$deno_tmp"
            cat "$deno_tmp" > "$shell_rc"
            rm -f "$deno_tmp"
            info "Deno env source 行を削除: $shell_rc (dotfiles で PATH 管理済みのため)"
        fi
    fi
done

# ============================================================================
# グローバルCLIツールのインストール（pnpm）
# ============================================================================
if command -v pnpm &> /dev/null; then
    export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    # pnpm 10+ は $PNPM_HOME/bin に global bin を配置する
    mkdir -p "$PNPM_HOME/bin"
    export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
    PNPM_GLOBAL_PACKAGES=(
        "@google/clasp"
        "@googleworkspace/cli"
        "@bitwarden/cli"
        "dev-browser"
    )
    for pkg in "${PNPM_GLOBAL_PACKAGES[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            info "[DRY RUN] ${pkg} をインストール（pnpm global）"
        else
            info "${pkg} をインストール中..."
            # pnpm 10+ は postinstall scripts の実行可否を対話プロンプトで聞く
            # CI=true + stdin リダイレクトで非対話モードにする (build scripts はスキップ)
            # サプライチェーン対策として build scripts を実行しない方針は npmrc の
            # ignore-scripts=true と一貫している
            if CI=true pnpm add -g "$pkg" < /dev/null 2>&1; then
                info "${pkg} のインストール完了"
            else
                warn "${pkg} のインストールに失敗しました"
            fi
        fi
    done
else
    warn "pnpm が見つかりません。corepack enable pnpm 後に再実行してください"
fi

# ============================================================================
# tflint のインストール（Terraform linter、GitHub Releases経由）
# ============================================================================
# homebrew-core / terraform-linters/tap 双方で入手困難なため直接install
if ! command -v tflint &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] tflint をインストール"
    else
        info "tflint をインストール中..."
        TFLINT_ARCH="amd64"
        if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
            TFLINT_ARCH="arm64"
        fi
        TFLINT_ZIP=$(mktemp -d)/tflint.zip
        mkdir -p "$HOME/.local/bin"
        if curl -sL "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_darwin_${TFLINT_ARCH}.zip" -o "$TFLINT_ZIP" 2>/dev/null && \
           unzip -o -q "$TFLINT_ZIP" -d "$HOME/.local/bin"; then
            info "tflint インストール完了"
        else
            warn "tflint インストール失敗"
        fi
        rm -rf "$(dirname "$TFLINT_ZIP")"
    fi
else
    info "tflint は既にインストールされています"
fi

# ============================================================================
# pipectlのインストール（PipeCD CLI）
# ============================================================================
if ! command -v pipectl &> /dev/null; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] pipectl をインストール（PipeCD CLI）"
    else
        info "pipectl をインストール中..."
        PIPECTL_VERSION=$(curl -s "https://api.github.com/repos/pipe-cd/pipecd/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
        PIPECTL_ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
        # Apple Silicon は arm64
        if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
            PIPECTL_ARCH="arm64"
        fi
        mkdir -p "$HOME/.local/bin"
        curl -Lo /tmp/pipectl "https://github.com/pipe-cd/pipecd/releases/download/${PIPECTL_VERSION}/pipectl_${PIPECTL_VERSION}_darwin_${PIPECTL_ARCH}" 2>/dev/null && \
            chmod +x /tmp/pipectl && \
            mv /tmp/pipectl "$HOME/.local/bin/pipectl" && \
            info "pipectl ${PIPECTL_VERSION} のインストール完了" || \
            warn "pipectl のインストールに失敗しました"
    fi
else
    info "pipectl は既にインストールされています"
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

# AWS認証はフェデレーション方式（環境変数）を使用
# ~/.aws/config, ~/.aws/credentials は不要

# AIツールの初回認証案内
if command -v claude &> /dev/null || command -v codex &> /dev/null; then
    info "ヒント: AIツールの初回起動時に認証が必要です"
    if command -v claude &> /dev/null; then
        echo "  claude  # Anthropic APIキーまたはOAuthで認証"
    fi
    if command -v codex &> /dev/null; then
        echo "  codex   # OpenAI APIキーで認証"
    fi
fi

# 補完用ディレクトリの作成
if [ ! -d "$HOME/.zsh/cache" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] 補完キャッシュディレクトリを作成: ~/.zsh/cache"
    else
        mkdir -p "$HOME/.zsh/cache"
        info "補完キャッシュディレクトリを作成: ~/.zsh/cache"
    fi
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
        echo -n "これらを削除してもよろしいですか？ (y/N): "
        read -n 1 -r
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
echo "  # Brewfileから一括インストール"
echo "  ./install.sh --brew"
echo ""
echo "  # または個別にインストール"
echo "  brew bundle install --file=Brewfile"
