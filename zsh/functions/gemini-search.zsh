#!/usr/bin/env zsh
# Gemini CLI Web検索関数

# メイン検索関数
function gsearch() {
    if [[ $# -eq 0 ]]; then
        echo "使用方法: gsearch <検索クエリ>"
        echo "例: gsearch React 19 新機能"
        return 1
    fi
    
    # Gemini CLIがインストールされているか確認
    if ! command -v gemini &> /dev/null; then
        echo "エラー: Gemini CLIがインストールされていません"
        echo "インストール: npm install -g @google/gemini-cli"
        return 1
    fi
    
    gemini --prompt "WebSearch: $*"
}

# 日本語検索用エイリアス
function gs() {
    gsearch "$@"
}

# 技術検索特化関数
function gtech() {
    if [[ $# -eq 0 ]]; then
        echo "使用方法: gtech <技術キーワード>"
        echo "例: gtech Next.js 14 app router"
        return 1
    fi
    
    gemini --prompt "WebSearch: $* site:stackoverflow.com OR site:github.com OR site:dev.to OR site:zenn.dev OR site:qiita.com"
}

# ニュース検索関数
function gnews() {
    if [[ $# -eq 0 ]]; then
        echo "使用方法: gnews <トピック>"
        echo "例: gnews AI 最新動向"
        return 1
    fi
    
    local current_date=$(date "+%Y年%m月")
    gemini --prompt "WebSearch: $* $current_date 最新ニュース"
}

# 検索履歴を保存する関数（オプション）
function gsearch-with-history() {
    local query="$*"
    local history_file="$HOME/.gemini_search_history"
    
    # 検索実行
    gsearch "$@"
    
    # 履歴に保存
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $query" >> "$history_file"
}

# 検索履歴を表示
function gsearch-history() {
    local history_file="$HOME/.gemini_search_history"
    if [[ -f "$history_file" ]]; then
        tail -n 20 "$history_file"
    else
        echo "検索履歴がありません"
    fi
}