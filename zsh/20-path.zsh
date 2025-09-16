#!/usr/bin/env zsh
# ============================================================================
# 20-path.zsh - 効率的なPATH環境変数管理
# ============================================================================
# パフォーマンスを重視したPATH管理とセキュリティ配慮

# ============================================================================
# PATH配列の設定
# ============================================================================
# path配列の重複を自動的に削除（typeset -Uの活用）
typeset -U path PATH

# PATH管理用のヘルパー配列
typeset -a _path_candidates

# ============================================================================
# セキュアなパス追加関数
# ============================================================================
# パスを安全に追加する関数
_add_secure_path() {
    local new_path="$1"
    local prepend="${2:-false}"
    
    # パスの存在確認（グロブ展開時のNull_Globで安全性確保）
    if [[ -d "$new_path" ]]; then
        # セキュリティチェック：書き込み権限がない、シンボリックリンクでない、または信頼できる場所
        if [[ ! -w "$new_path" ]] || _is_trusted_path "$new_path"; then
            if [[ "$prepend" == "true" ]]; then
                path=("$new_path" $path)
            else
                path+=("$new_path")
            fi
        fi
    fi
}

# 信頼できるパスかチェックする関数
_is_trusted_path() {
    local check_path="$1"
    local trusted_patterns=(
        '/usr/bin'
        '/usr/local/bin'
        '/opt/homebrew/bin'
        "$HOME/.local/bin"
        "$HOME/bin"
        "$HOME/.local/share/mise/shims"
        "$HOME/.gem/ruby/*/bin"
        '/System/*'
        '/usr/sbin'
    )
    
    for pattern in "${trusted_patterns[@]}"; do
        if [[ "$check_path" == ${~pattern} ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================================================
# 最優先パス（バージョン管理ツール）
# ============================================================================
# miseのshims（最優先）
_add_secure_path "$HOME/.local/share/mise/shims" true

# ============================================================================
# ローカルバイナリ（ユーザー環境）
# ============================================================================
# 効率化：配列で一括処理
_path_candidates=(
    "$HOME/src/github.com/ryosukesuto/dotfiles/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
)

for candidate in "${_path_candidates[@]}"; do
    _add_secure_path "$candidate" true
done

# ============================================================================
# Homebrew設定（macOS対応）
# ============================================================================
# Homebrewの検出と設定（一度の判定で効率化）
if [[ -d "/opt/homebrew" ]]; then
    # Apple Silicon Mac
    _homebrew_paths=(
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
    )
    for brew_path in "${_homebrew_paths[@]}"; do
        _add_secure_path "$brew_path"
    done
    
    # Homebrew環境変数（条件付き設定）
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    
elif [[ -d "/usr/local/Homebrew" ]]; then
    # Intel Mac
    _homebrew_paths=(
        "/usr/local/bin"
        "/usr/local/sbin"
    )
    for brew_path in "${_homebrew_paths[@]}"; do
        _add_secure_path "$brew_path"
    done
    
    export HOMEBREW_PREFIX="/usr/local"
    export HOMEBREW_CELLAR="/usr/local/Cellar"
    export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
fi

# ============================================================================
# 開発ツール関連
# ============================================================================
# Ruby gems（ユーザー領域のgem）
# Bundlerなどユーザー領域にインストールされたgemのため
_add_secure_path "$HOME/.gem/ruby/2.6.0/bin"

# Google Cloud SDK（条件付き追加）
_add_secure_path "$HOME/google-cloud-sdk/bin"

# AWS CLI v2（複数の可能な場所をチェック）
_aws_paths=(
    "/usr/local/aws-cli/v2/current/bin"
    "/opt/homebrew/bin"  # Homebrew経由でインストールされた場合
)

for aws_path in "${_aws_paths[@]}"; do
    if [[ -f "$aws_path/aws" ]]; then
        _add_secure_path "$aws_path"
        break  # 最初に見つかったものを使用
    fi
done

# ============================================================================
# システムパス（フォールバック）
# ============================================================================
# 基本的なシステムパスを最後に追加（既存の場合は無視）
_system_paths=(
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/local/sbin"
    "/usr/sbin"
    "/sbin"
)

for sys_path in "${_system_paths[@]}"; do
    _add_secure_path "$sys_path"
done

# ============================================================================
# PATH診断機能
# ============================================================================
# PATH診断関数
path_diagnostic() {
    echo "=== PATH診断 ==="
    echo "PATHエントリ数: ${#path[@]}"
    echo ""
    
    local i=1
    for p in "${path[@]}"; do
        local status="❌"
        local security="🔒"
        
        if [[ -d "$p" ]]; then
            status="✅"
        fi
        
        if ! _is_trusted_path "$p"; then
            security="⚠️"
        fi
        
        printf "%2d. %s %s %s\n" $i "$status" "$security" "$p"
        ((i++))
    done
    
    echo ""
    echo "凡例: ✅=存在 ❌=不存在 🔒=信頼済み ⚠️=要注意"
}

# 重複パスの検出
find_duplicate_paths() {
    echo "=== 重複パス検出 ==="
    local -A seen_paths
    local duplicates=()
    
    for p in "${path[@]}"; do
        if [[ -n "${seen_paths[$p]}" ]]; then
            duplicates+=("$p")
        else
            seen_paths[$p]=1
        fi
    done
    
    if [[ ${#duplicates[@]} -eq 0 ]]; then
        echo "重複パスはありません"
    else
        echo "重複パス:"
        printf "  %s\n" "${duplicates[@]}"
    fi
}

# PATHクリーンアップ（重複除去）
clean_path() {
    typeset -U path PATH
    echo "PATHをクリーンアップしました"
    path_diagnostic
}

# ============================================================================
# クリーンアップ
# ============================================================================
# 一時変数をクリア
unset _path_candidates _homebrew_paths _aws_paths _system_paths

# PATH最終確認（デバッグモード時）
if [[ -n "$DOTFILES_DEBUG" ]]; then
    echo "PATH initialized with ${#path[@]} entries"
fi