#!/usr/bin/env zsh
# ============================================================================
# 40-functions.zsh - セキュアな遅延読み込み機構
# ============================================================================
# セキュリティとパフォーマンスを重視した関数定義と遅延読み込み設定

# ============================================================================
# ディレクトリナビゲーション（ghq + fzf/peco）
# ============================================================================
if command -v ghq &> /dev/null; then
    if command -v fzf &> /dev/null; then
        # fzfを使ったバージョン（Ctrl+]）
        fzf-src() {
            local selected_dir
            selected_dir=$(ghq list -p | fzf --query "$LBUFFER" --height 40% --reverse)
            if [[ -n "$selected_dir" ]]; then
                BUFFER="cd ${(q)selected_dir}"  # クォートしてセキュア
                zle accept-line
            fi
            zle clear-screen
        }
        zle -N fzf-src
        bindkey '^]' fzf-src
        
    elif command -v peco &> /dev/null; then
        # pecoを使ったバージョン（Ctrl+g）
        peco-src() {
            local selected_dir
            selected_dir=$(ghq list -p | peco --query "$LBUFFER")
            if [[ -n "$selected_dir" ]]; then
                BUFFER="cd ${(q)selected_dir}"  # クォートしてセキュア
                zle accept-line
            fi
            zle clear-screen
        }
        zle -N peco-src
        bindkey '^g' peco-src
    fi
fi

# ============================================================================
# セキュアな遅延読み込み機構
# ============================================================================
# 関数ディレクトリのパス（絶対パス）
typeset -g DOTFILES_FUNCTIONS_DIR="$HOME/src/github.com/ryosukesuto/dotfiles/zsh/functions"

# 読み込み済み関数のトラッキング
typeset -gA _LOADED_FUNCTIONS

# セキュアなファイル検証関数
_validate_function_file() {
    local file_path="$1"
    
    # ファイル存在チェック
    [[ -f "$file_path" ]] || return 1
    
    # 所有者チェック（自分所有のファイルのみ）
    [[ -O "$file_path" ]] || return 1
    
    # 権限チェック（他者による書き込み権限なし）
    local perms
    perms=$(stat -f "%Mp%Lp" "$file_path" 2>/dev/null || stat -c "%a" "$file_path" 2>/dev/null)
    [[ "$perms" != *"2"* && "$perms" != *"6"* ]] || return 1
    
    # 基本的な内容検証（危険なパターンのチェック）
    if grep -qE '(rm\s+-rf|sudo\s+rm|curl.*\||wget.*\||>\s*/dev/)' "$file_path" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

# エラーログ記録関数
_log_function_error() {
    local func_name="$1"
    local error_msg="$2"
    local log_file="$HOME/.cache/dotfiles-errors.log"
    
    # ログディレクトリ作成
    mkdir -p "$(dirname "$log_file")"
    
    # タイムスタンプ付きでログ記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $func_name - $error_msg" >> "$log_file"
}

# 改善された遅延読み込み関数作成ヘルパー
create_lazy_function() {
    local func_name="$1"
    local source_file="$2"
    local error_msg="${3:-"$func_name function not available"}"
    
    # 入力検証
    if [[ -z "$func_name" || -z "$source_file" ]]; then
        echo "Usage: create_lazy_function <function_name> <source_file> [error_message]" >&2
        return 1
    fi
    
    # 関数名の妥当性チェック（英数字、ハイフン、アンダースコアのみ）
    if [[ ! "$func_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        _log_function_error "$func_name" "Invalid function name"
        return 1
    fi
    
    # 関数定義（evalの代わりにfunction構文を使用）
    function "$func_name"() {
        local file_path="$DOTFILES_FUNCTIONS_DIR/$source_file"
        
        # 既に読み込み済みの場合は再読み込みしない
        if [[ -n "${_LOADED_FUNCTIONS[$func_name]}" ]]; then
            "$func_name" "$@"
            return $?
        fi
        
        # ファイル検証
        if ! _validate_function_file "$file_path"; then
            _log_function_error "$func_name" "File validation failed: $file_path"
            echo "$error_msg" >&2
            return 1
        fi
        
        # セキュアにファイルを読み込み
        if source "$file_path" 2>/dev/null; then
            _LOADED_FUNCTIONS[$func_name]="$file_path"
            # 再帰呼び出しで実際の関数を実行
            "$func_name" "$@"
            return $?
        else
            _log_function_error "$func_name" "Failed to source: $file_path"
            echo "$error_msg" >&2
            return 1
        fi
    }
}

# パフォーマンス測定機能付きの関数作成ヘルパー
create_perf_lazy_function() {
    local func_name="$1"
    local source_file="$2"
    local error_msg="${3:-"$func_name function not available"}"
    
    function "$func_name"() {
        local start_time end_time elapsed
        
        # 高精度タイマー開始
        if (( ${+EPOCHREALTIME} )); then
            start_time=${EPOCHREALTIME%.*}
        else
            start_time=$(date +%s)
        fi
        
        # 通常の遅延読み込み処理
        create_lazy_function "$func_name" "$source_file" "$error_msg"
        local result=$?
        
        # 高精度タイマー終了
        if (( ${+EPOCHREALTIME} )); then
            end_time=${EPOCHREALTIME%.*}
            elapsed=$((end_time - start_time))
        else
            end_time=$(date +%s)
            elapsed=$((end_time - start_time))
        fi
        
        # 遅い読み込みの警告（1秒以上）
        if [[ $elapsed -gt 1 ]]; then
            echo "Warning: Slow function loading: $func_name (${elapsed}ms)" >&2
        fi
        
        return $result
    }
}

# ============================================================================
# 関数定義（遅延読み込み）
# ============================================================================
# AWS Bastion関連
create_lazy_function "aws-bastion" "aws-bastion.zsh"
create_lazy_function "aws-bastion-select" "aws-bastion.zsh"

# ユーティリティ関数
create_lazy_function "extract" "extract.zsh"
create_lazy_function "diag" "diagnostics.zsh"
create_lazy_function "diagnose" "diagnostics.zsh"

# オプション機能（遅い可能性があるためパフォーマンス測定付き）
if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
    for func in gsearch gemini-search gtech gnews; do
        create_perf_lazy_function "$func" "gemini-search.zsh"
    done
fi

if [[ -f "$DOTFILES_FUNCTIONS_DIR/obsidian-claude.zsh" ]]; then
    for func in obsc obs-task obs-meeting obs-claude-recent; do
        create_perf_lazy_function "$func" "obsidian-claude.zsh"
    done
fi

# ============================================================================
# ユーティリティ関数
# ============================================================================
# 読み込み済み関数の表示
list_loaded_functions() {
    echo "=== 読み込み済み関数 ==="
    for func_name file_path in ${(kv)_LOADED_FUNCTIONS}; do
        echo "$func_name -> $file_path"
    done
}

# 関数キャッシュのクリア
clear_function_cache() {
    local count=${#_LOADED_FUNCTIONS}
    _LOADED_FUNCTIONS=()
    echo "関数キャッシュをクリア（${count}個の関数）"
}

# エラーログの表示
show_function_errors() {
    local log_file="$HOME/.cache/dotfiles-errors.log"
    if [[ -f "$log_file" ]]; then
        echo "=== 関数エラーログ ==="
        tail -20 "$log_file"
    else
        echo "エラーログが見つかりません"
    fi
}