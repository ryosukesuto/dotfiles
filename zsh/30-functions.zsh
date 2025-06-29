#!/usr/bin/env zsh
# ============================================================================
# 30-functions.zsh - コア関数と遅延読み込み設定
# ============================================================================
# このファイルは頻繁に使用される基本的な関数のみを定義し、
# 大きな関数や診断ツールは遅延読み込みします。

# ============================================================================
# 基本的なユーティリティ関数
# ============================================================================
# ディレクトリ作成と移動を同時に行う
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# ファイル/ディレクトリのサイズを表示
sizeof() {
    du -sh "$@"
}

# ============================================================================
# ディレクトリナビゲーション（ghq + fzf/peco）
# ============================================================================
if command -v fzf &> /dev/null && command -v ghq &> /dev/null; then
    # fzfを使ったバージョン
    function fzf-src() {
        local selected_dir=$(ghq list -p | fzf --query "$LBUFFER" --height 40% --reverse)
        if [[ -n "$selected_dir" ]]; then
            BUFFER="cd ${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N fzf-src
    bindkey '^]' fzf-src
elif command -v peco &> /dev/null && command -v ghq &> /dev/null; then
    # pecoを使ったバージョン
    function peco-src() {
        local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
        if [[ -n "$selected_dir" ]]; then
            BUFFER="cd ${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N peco-src
    bindkey '^g' peco-src
fi

# ============================================================================
# 遅延読み込み関数の定義
# ============================================================================
# 関数ディレクトリのパス
DOTFILES_FUNCTIONS_DIR="${DOTFILES_DIR:-$HOME/dotfiles}/zsh/functions"

# 圧縮ファイル展開（遅延読み込み）
extract() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/extract.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/extract.zsh"
        extract "$@"
    else
        # フォールバック実装
        if [[ -f "$1" ]]; then
            case "$1" in
                *.tar.bz2)   tar xjf "$1"     ;;
                *.tar.gz)    tar xzf "$1"     ;;
                *.bz2)       bunzip2 "$1"     ;;
                *.rar)       unrar x "$1"     ;;
                *.gz)        gunzip "$1"      ;;
                *.tar)       tar xf "$1"      ;;
                *.tbz2)      tar xjf "$1"     ;;
                *.tgz)       tar xzf "$1"     ;;
                *.zip)       unzip "$1"       ;;
                *.Z)         uncompress "$1"  ;;
                *.7z)        7z x "$1"        ;;
                *)           echo "'$1' cannot be extracted via extract()" ;;
            esac
        else
            echo "'$1' is not a valid file"
        fi
    fi
}

# AWS Bastion関連（遅延読み込み）
aws-bastion() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh"
        aws-bastion "$@"
    else
        echo "aws-bastion function not found"
        return 1
    fi
}

aws-bastion-select() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/aws-bastion.zsh"
        aws-bastion-select "$@"
    else
        echo "aws-bastion-select function not found"
        return 1
    fi
}

# Dotfiles診断（遅延読み込み）
dotfiles-diag() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/diagnostics.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/diagnostics.zsh"
        dotfiles-diag "$@"
    else
        echo "診断ツールが見つかりません。以下を確認してください："
        echo "- $DOTFILES_FUNCTIONS_DIR/diagnostics.zsh が存在するか"
        echo "- DOTFILES_DIR 環境変数が正しく設定されているか"
        return 1
    fi
}

# Gemini検索関数（遅延読み込み）
gsearch() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gsearch "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

gemini-search() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gemini-search "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

gtech() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gtech "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

gnews() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gnews "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

gsearch-with-history() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gsearch-with-history "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

gsearch-history() {
    if [[ -f "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh" ]]; then
        source "$DOTFILES_FUNCTIONS_DIR/gemini-search.zsh"
        gsearch-history "$@"
    else
        echo "Gemini検索関数が見つかりません"
        return 1
    fi
}

# ============================================================================
# Obsidian関連の関数
# ============================================================================
# Obsidian thinoに直接メモを追加
th() {
    if [[ -z "$1" ]]; then
        echo "使用方法: th <メモ内容>"
        return 1
    fi
    
    # Obsidian VaultのパスはCLAUDE.mdの設定から
    local vault_path="$HOME/src/github.com/ryosukesuto/obsidian-notes"
    local today=$(date +%Y-%m-%d)
    local daily_note="$vault_path/01_Daily/${today}.md"
    local timestamp=$(date "+%Y/%m/%d %H:%M:%S")
    
    # デイリーノートが存在しない場合は作成
    if [[ ! -f "$daily_note" ]]; then
        echo "# ${today}" > "$daily_note"
        echo "" >> "$daily_note"
        echo "## メモ" >> "$daily_note"
    fi
    
    # メモセクションが存在しない場合は追加
    if ! grep -q "^## メモ" "$daily_note"; then
        echo "" >> "$daily_note"
        echo "## メモ" >> "$daily_note"
    fi
    
    # メモを追加
    local new_memo="- ${timestamp}: $*"
    
    # ファイル全体を読み込んで処理
    local temp_file="${daily_note}.tmp"
    local in_memo_section=0
    local memo_added=0
    local last_memo_line=0
    local line_num=0
    
    # 行番号を記録しながら処理
    while IFS= read -r line; do
        ((line_num++))
        if [[ "$line" == "## メモ" ]]; then
            in_memo_section=1
        elif [[ $in_memo_section -eq 1 ]]; then
            if [[ "$line" =~ ^-[[:space:]] ]]; then
                # メモ行を見つけたら、その行番号を記録
                last_memo_line=$line_num
            elif [[ "$line" =~ ^##[[:space:]] ]] || [[ -z "$line" && $last_memo_line -gt 0 ]]; then
                # 次のセクションまたは空行（メモの後）に到達
                in_memo_section=0
            fi
        fi
    done < "$daily_note"
    
    # 最後のメモ行の後に新しいメモを挿入
    if [[ $last_memo_line -gt 0 ]]; then
        # 最後のメモ行の後に挿入
        awk -v line="$last_memo_line" -v memo="$new_memo" 'NR==line{print; print memo; next} 1' "$daily_note" > "$temp_file"
    else
        # メモセクションはあるが、まだメモがない場合
        awk -v memo="$new_memo" '/^## メモ$/{print; print memo; next} 1' "$daily_note" > "$temp_file"
    fi
    
    # mvのエイリアスを無効化して実行（-iオプションを避ける）
    /bin/mv -f "$temp_file" "$daily_note"
    echo "✅ メモを追加しました: $*"
}

# Obsidianを開く
obs() {
    local vault_path="$HOME/src/github.com/ryosukesuto/obsidian-notes"
    open "obsidian://open?vault=$(basename "$vault_path")"
}

# Claude Codeでノートを検索
obs-search() {
    local vault_path="$HOME/src/github.com/ryosukesuto/obsidian-notes"
    if [[ -f "$vault_path/scripts/claude-search.sh" ]]; then
        "$vault_path/scripts/claude-search.sh" "$@"
    else
        echo "claude-search.sh が見つかりません"
        return 1
    fi
}

# エイリアス
alias obs-s='obs-search search'
alias obs-weekly='obs-search summary weekly'
alias obs-todo='obs-search todo'

# 10秒アクション追加（10 second action）
tsa() {
    if [[ -z "$1" ]]; then
        echo "使用方法: tsa <10秒アクション>"
        echo "例: tsa 'VSCodeを開く'"
        return 1
    fi
    
    # 10秒アクション専用の絵文字を付けて記録
    th "⚡ 10秒アクション: $*"
}

# 10秒アクション完了
tsad() {
    if [[ -z "$1" ]]; then
        echo "使用方法: tsad <完了した10秒アクション>"
        return 1
    fi
    
    # 完了マークを付けて記録
    th "⚡✅ 10秒アクション完了: $*"
}

# タスクを10秒アクションに分解するヘルパー
task-break() {
    echo "🎯 タスクを10秒アクションに分解します"
    echo ""
    echo "以下のプロンプトをClaude/ChatGPTで使用してください："
    echo "---"
    cat "$HOME/src/github.com/ryosukesuto/obsidian-notes/05_Tech/Prompts/10sec-action.md" | head -20
    echo "---"
    echo ""
    echo "タスク: $*"
}

# ============================================================================
# クイックエイリアス的な関数
# ============================================================================
# 一つ上のディレクトリに移動してls
up() {
    cd .. && ls
}

# Git リポジトリのルートに移動
cdgr() {
    cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
}

# 最近変更されたファイルを表示
recent() {
    local count=${1:-10}
    if command -v eza &> /dev/null; then
        eza -la --sort=modified --reverse | head -n "$count"
    else
        ls -lat | head -n "$count"
    fi
}

# ============================================================================
# 環境情報表示（シンプル版）
# ============================================================================
# 詳細版はdotfiles-diagを使用
env-info() {
    echo "=== 基本環境情報 ==="
    echo "Shell: $SHELL ($ZSH_VERSION)"
    echo "OS: $(uname -s) $(uname -r)"
    echo "User: $USER"
    echo "Home: $HOME"
    echo ""
    echo "詳細な診断情報は 'dotfiles-diag' コマンドを使用してください。"
}