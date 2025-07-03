#!/bin/bash
# th-oneliner.sh - ワンライナーで実行できるth関数の例

# 使用例:
# 1. 直接実行
# echo "- $(date '+%Y/%m/%d %H:%M:%S'): テストメモ" >> ~/src/github.com/ryosukesuto/obsidian-notes/01_Daily/$(date +%Y-%m-%d).md

# 2. 関数として定義（どこでも実行可能）
th_quick() {
    local vault="$HOME/src/github.com/ryosukesuto/obsidian-notes"
    local today=$(date +%Y-%m-%d)
    local file="$vault/01_Daily/$today.md"
    local timestamp=$(date '+%Y/%m/%d %H:%M:%S')
    
    # ディレクトリとファイルの作成
    mkdir -p "$vault/01_Daily"
    [ ! -f "$file" ] && printf "# %s\n\n## 📝 メモ\n" "$today" > "$file"
    
    # メモ追加
    echo "- $timestamp: $*" >> "$file"
    echo "✅ メモを追加しました: $*"
}

# 実行例
# th_quick "これはテストメモです"