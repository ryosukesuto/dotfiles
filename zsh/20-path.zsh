#!/usr/bin/env zsh
# ============================================================================
# 20-path.zsh - PATH環境変数の最適化管理
# ============================================================================
# このファイルはPATH環境変数を効率的に管理します。
# Zshのpath配列を使用することで、重複の自動削除と高速な処理を実現します。

# ============================================================================
# PATH配列の設定
# ============================================================================
# path配列の重複を自動的に削除
typeset -U path PATH

# ============================================================================
# 基本的なディレクトリの追加
# ============================================================================
# (N-/)は以下の意味:
# N: NULL_GLOBオプション - マッチしない場合は何も返さない
# -: シンボリックリンクを辿る
# /: ディレクトリのみマッチ

# ローカルバイナリ（最優先）
path=(
    $HOME/.local/bin(N-/)
    $HOME/bin(N-/)
    $path
)

# ============================================================================
# Homebrew設定（macOS）
# ============================================================================
# Apple Silicon Mac
if [[ -d "/opt/homebrew" ]]; then
    path=(
        /opt/homebrew/bin(N-/)
        /opt/homebrew/sbin(N-/)
        $path
    )
    # Homebrewの環境変数も設定
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
# Intel Mac
elif [[ -d "/usr/local/Homebrew" ]]; then
    path=(
        /usr/local/bin(N-/)
        /usr/local/sbin(N-/)
        $path
    )
    export HOMEBREW_PREFIX="/usr/local"
    export HOMEBREW_CELLAR="/usr/local/Cellar"
    export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
fi

# ============================================================================
# プログラミング言語関連
# ============================================================================
# Go
export GOPATH="$HOME"
path=($GOPATH/bin(N-/) $path)

# Python (pyenv)
export PYENV_ROOT="$HOME/.pyenv"
path=($PYENV_ROOT/bin(N-/) $path)

# Ruby (rbenv)
if [[ -d "$HOME/.rbenv" ]]; then
    export RBENV_ROOT="$HOME/.rbenv"
    path=($RBENV_ROOT/bin(N-/) $path)
fi

# Node.js (volta)
if [[ -d "$HOME/.volta" ]]; then
    export VOLTA_HOME="$HOME/.volta"
    path=($VOLTA_HOME/bin(N-/) $path)
fi

# Rust
path=($HOME/.cargo/bin(N-/) $path)

# ============================================================================
# 開発ツール関連
# ============================================================================
# Terraform (tfenv)
path=($HOME/.tfenv/bin(N-/) $path)

# Google Cloud SDK
if [[ -d "$HOME/google-cloud-sdk" ]]; then
    path=($HOME/google-cloud-sdk/bin(N-/) $path)
fi

# AWS CLI v2
path=(/usr/local/aws-cli/v2/current/bin(N-/) $path)

# ============================================================================
# システムパスの確保
# ============================================================================
# 基本的なシステムパスを最後に追加（既に含まれている場合は無視される）
path=(
    $path
    /usr/local/bin(N-/)
    /usr/bin(N-/)
    /bin(N-/)
    /usr/local/sbin(N-/)
    /usr/sbin(N-/)
    /sbin(N-/)
)

# ============================================================================
# PATH診断関数（デバッグ用）
# ============================================================================
path_info() {
    echo "=== PATH Information ==="
    echo "Number of directories: ${#path[@]}"
    echo ""
    echo "=== Current PATH directories ==="
    local i=1
    for dir in $path; do
        if [[ -d "$dir" ]]; then
            printf "%2d: ✓ %s\n" $i "$dir"
        else
            printf "%2d: ✗ %s (not found)\n" $i "$dir"
        fi
        ((i++))
    done
    echo ""
    echo "=== PATH string ==="
    echo "$PATH"
}

# ============================================================================
# 動的PATH管理関数（互換性のため残す）
# ============================================================================
# 既存のスクリプトとの互換性のため、関数も提供
path_prepend() {
    local dir
    for dir in "$@"; do
        if [[ -d "$dir" ]]; then
            path=("$dir" $path)
        fi
    done
}

path_append() {
    local dir
    for dir in "$@"; do
        if [[ -d "$dir" ]]; then
            path=($path "$dir")
        fi
    done
}

path_remove() {
    local dir
    for dir in "$@"; do
        path=("${(@)path:#$dir}")
    done
}