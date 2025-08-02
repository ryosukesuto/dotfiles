#!/usr/bin/env zsh
# ============================================================================
# 30-aliases.zsh - 体系化されたエイリアス定義
# ============================================================================
# 効率的で安全なエイリアス設定

# ============================================================================
# エイリアス設定ヘルパー関数
# ============================================================================
# 条件付きエイリアス設定関数
_safe_alias() {
    local alias_name="$1"
    local command="$2"
    local target_command="$3"
    
    # コマンドが存在する場合のみエイリアスを設定
    if command -v "$target_command" &> /dev/null; then
        alias "$alias_name"="$command"
        return 0
    fi
    return 1
}

# カテゴリ別エイリアス設定関数
_setup_category_aliases() {
    local category="$1"
    local -a aliases_def
    
    case "$category" in
        "tmux")
            aliases_def=(
                "t:tmux:tmux"
                "ta:tmux attach:tmux"
                "tl:tmux list-sessions:tmux"
                "tn:tmux new-session:tmux"
                "tk:tmux kill-session:tmux"
            )
            ;;
        "aws")
            aliases_def=(
                "bastion:aws-bastion:aws"
                "bastion-select:aws-bastion-select:aws"
                "bastion-prod:aws-bastion prod:aws"
                "bastion-dev:aws-bastion dev:aws"
                "bastion-staging:aws-bastion staging:aws"
            )
            ;;
        "editor")
            aliases_def=(
                "v:vim:vim"
                "vi:vim:vim"
                "vimplug:vim +PlugInstall +qall:vim"
            )
            ;;
        "system")
            aliases_def=(
                "h:history:echo"
                "j:jobs -l:echo"
                "reload:source ~/.zshrc:echo"
                "path:echo -e \${PATH//:/\\\\n}:echo"
            )
            ;;
        "git")
            aliases_def=(
                "g:git:git"
                "gs:git status:git"
                "ga:git add:git"
                "gc:git commit:git"
                "gp:git push:git"
                "gl:git log --oneline:git"
                "gd:git diff:git"
                "gb:git branch:git"
                "gco:git checkout:git"
            )
            ;;
        "modern")
            # モダンなコマンドラインツール
            aliases_def=(
                "ls:eza --group-directories-first:eza"
                "ll:eza -l --group-directories-first:eza"
                "la:eza -la --group-directories-first:eza"
                "tree:eza --tree:eza"
                "cat:bat:bat"
                "grep:rg:rg"
                "find:fd:fd"
            )
            ;;
    esac
    
    # エイリアス設定実行
    local count=0
    for alias_def in "${aliases_def[@]}"; do
        local alias_name="${alias_def%%:*}"
        local remaining="${alias_def#*:}"
        local command="${remaining%%:*}"
        local target_command="${remaining#*:}"
        
        if _safe_alias "$alias_name" "$command" "$target_command"; then
            ((count++))
        fi
    done
    
    # デバッグモード時にカウント表示
    if [[ -n "$DOTFILES_DEBUG" ]]; then
        echo "[$category] $count aliases set"
    fi
}

# ============================================================================
# カテゴリ別エイリアス設定
# ============================================================================
# セッション管理
_setup_category_aliases "tmux"

# AWS/クラウド関連
_setup_category_aliases "aws"

# エディタ関連
_setup_category_aliases "editor"

# Git関連（条件付き）
_setup_category_aliases "git"

# モダンツール（条件付き置換）
_setup_category_aliases "modern"

# システムユーティリティ（常時設定）
_setup_category_aliases "system"

# ============================================================================
# 特殊なエイリアス
# ============================================================================
# 安全な削除（確認付き）
if command -v rm &> /dev/null; then
    alias rm='rm -i'
    alias cp='cp -i'
    alias mv='mv -i'
fi

# sudo関連（セキュリティ考慮）
if command -v sudo &> /dev/null; then
    # sudoでエイリアスを使用可能にする
    alias sudo='sudo '
fi

# ============================================================================
# プラットフォーム固有エイリアス
# ============================================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS固有
    alias flushdns='sudo dscacheutil -flushcache'
    alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
    alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
    
    # macOS専用のlsエイリアス（ezaがない場合）
    if ! command -v eza &> /dev/null; then
        alias ls='ls -G'
        alias ll='ls -lG'
        alias la='ls -laG'
    fi
    
elif [[ "$OSTYPE" == "linux"* ]]; then
    # Linux固有
    if ! command -v eza &> /dev/null; then
        alias ls='ls --color=auto'
        alias ll='ls -l --color=auto'
        alias la='ls -la --color=auto'
    fi
    
    # Linuxでのメモリ/プロセス管理
    alias psmem='ps auxf | sort -nr -k 4'
    alias pscpu='ps auxf | sort -nr -k 3'
fi

# ============================================================================
# 開発環境固有エイリアス
# ============================================================================
# Docker関連（条件付き）
if command -v docker &> /dev/null; then
    alias d='docker'
    alias dc='docker-compose'
    alias dps='docker ps'
    alias dimg='docker images'
    alias dclean='docker system prune -f'
fi

# Kubernetes関連（条件付き）
if command -v kubectl &> /dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
fi

# ============================================================================
# エイリアス管理ユーティリティ
# ============================================================================
# 設定されたエイリアスの表示
list_aliases() {
    echo "=== 設定済みエイリアス ==="
    alias | sort | while IFS='=' read -r alias_name alias_command; do
        printf "%-15s -> %s\n" "$alias_name" "$alias_command"
    done
}

# カテゴリ別エイリアス表示
show_category_aliases() {
    local category="$1"
    
    if [[ -z "$category" ]]; then
        echo "使用法: show_category_aliases <category>"
        echo "カテゴリ: tmux, aws, editor, git, modern, system, docker, k8s"
        return 1
    fi
    
    echo "=== $category エイリアス ==="
    case "$category" in
        "tmux") alias | grep -E '^(t|ta|tl|tn|tk)=' ;;
        "aws") alias | grep -E '^bastion' ;;
        "editor") alias | grep -E '^(v|vi|vimplug)=' ;;
        "git") alias | grep -E '^g[a-z]*=' ;;
        "modern") alias | grep -E '^(ls|ll|la|tree|cat|grep|find)=' ;;
        "system") alias | grep -E '^(h|j|reload|path)=' ;;
        "docker") alias | grep -E '^d[a-z]*=' ;;
        "k8s") alias | grep -E '^k[a-z]*=' ;;
        *) echo "不明なカテゴリ: $category" >&2; return 1 ;;
    esac
}

# エイリアスの競合チェック
check_alias_conflicts() {
    echo "=== エイリアス競合チェック ==="
    local conflicts=()
    
    # 既存のコマンドと同名のエイリアスを検出
    alias | while IFS='=' read -r alias_name alias_command; do
        if command -v "$alias_name" &> /dev/null && [[ "$alias_command" != "$alias_name"* ]]; then
            echo "競合: $alias_name (コマンド) -> $alias_command (エイリアス)"
        fi
    done
}

# ============================================================================
# クリーンアップ
# ============================================================================
# ヘルパー関数をクリーンアップ
unfunction _safe_alias _setup_category_aliases