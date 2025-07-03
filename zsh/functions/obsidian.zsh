#!/usr/bin/env zsh
# ============================================================================
# obsidian.zsh - Obsidianデイリーノート関数
# ============================================================================
# このファイルはObsidianのデイリーノートにメモを追加する関数を提供します。

# Obsidianデイリーノートにメモを追加
th() {
    if [[ -z "$1" ]]; then
        echo "使用方法: th <メモ内容>"
        return 1
    fi
    
    local vault_path="$HOME/src/github.com/ryosukesuto/obsidian-notes"
    local today=$(date +%Y-%m-%d)
    local daily_note="$vault_path/01_Daily/${today}.md"
    local timestamp=$(date "+%Y/%m/%d %H:%M:%S")
    
    # デイリーノートが存在しない場合は作成
    if [[ ! -f "$daily_note" ]]; then
        echo "# ${today}" > "$daily_note"
        echo "" >> "$daily_note"
        echo "## 📝 メモ" >> "$daily_note"
    fi
    
    # メモセクションが存在しない場合は追加
    if ! rg -q "^## 📝 メモ" "$daily_note"; then
        echo "" >> "$daily_note"
        echo "## 📝 メモ" >> "$daily_note"
    fi
    
    # 新しいメモを追加
    local new_memo="- ${timestamp}: $*"
    local temp_file="${daily_note}.tmp"
    local in_memo_section=0
    local memo_added=0
    local last_memo_line=0
    local line_num=0
    
    # メモセクションの最後を見つける
    while IFS= read -r line; do
        ((line_num++))
        if [[ "$line" == "## 📝 メモ" ]]; then
            in_memo_section=1
        elif [[ $in_memo_section -eq 1 ]]; then
            if [[ "$line" =~ ^-[[:space:]] ]]; then
                last_memo_line=$line_num
            elif [[ "$line" =~ ^##[[:space:]] ]] || [[ -z "$line" && $last_memo_line -gt 0 ]]; then
                in_memo_section=0
            fi
        fi
    done < "$daily_note"
    
    # メモを適切な位置に挿入
    if [[ $last_memo_line -gt 0 ]]; then
        awk -v line="$last_memo_line" -v memo="$new_memo" 'NR==line{print; print memo; next} 1' "$daily_note" > "$temp_file"
    else
        awk -v memo="$new_memo" '/^## 📝 メモ$/{print; print memo; next} 1' "$daily_note" > "$temp_file"
    fi
    
    /bin/mv -f "$temp_file" "$daily_note"
    echo "✅ メモを追加しました: $*"
}