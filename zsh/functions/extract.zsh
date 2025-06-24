#!/usr/bin/env zsh
# ============================================================================
# extract.zsh - 圧縮ファイル展開ユーティリティ
# ============================================================================
# このファイルは遅延読み込みされ、extract関数が必要な時のみロードされます。

# 様々な形式の圧縮ファイルを展開
extract() {
    if [[ $# -eq 0 ]]; then
        echo "使用方法: extract <file1> [file2] ..."
        echo ""
        echo "サポートされている形式:"
        echo "  *.tar.bz2, *.tar.gz, *.tar.xz, *.tar.zst"
        echo "  *.bz2, *.rar, *.gz, *.tar"
        echo "  *.tbz2, *.tgz, *.zip, *.Z"
        echo "  *.7z, *.deb, *.tar.lz"
        echo "  *.xz, *.exe, *.msi"
        return 1
    fi
    
    local success=0
    local total=$#
    
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo "❌ '$file' はファイルではありません"
            continue
        fi
        
        echo "📦 展開中: $file"
        
        case "$file" in
            *.tar.bz2|*.tbz2)
                tar xjf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.tar.gz|*.tgz)
                tar xzf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.tar.xz)
                tar xJf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.tar.zst)
                tar --zstd -xf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.tar.lz)
                tar --lzip -xf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.tar)
                tar xf "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.bz2)
                bunzip2 -k "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.gz)
                gunzip -k "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.xz)
                unxz -k "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.zip)
                if command -v unzip &> /dev/null; then
                    unzip "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                else
                    echo "❌ unzipがインストールされていません"
                fi
                ;;
            *.rar)
                if command -v unrar &> /dev/null; then
                    unrar x "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                elif command -v rar &> /dev/null; then
                    rar x "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                else
                    echo "❌ unrarまたはrarがインストールされていません"
                fi
                ;;
            *.7z)
                if command -v 7z &> /dev/null; then
                    7z x "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                elif command -v 7za &> /dev/null; then
                    7za x "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                else
                    echo "❌ 7zがインストールされていません"
                fi
                ;;
            *.Z)
                uncompress "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                ;;
            *.deb)
                if command -v ar &> /dev/null; then
                    ar x "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                else
                    echo "❌ arがインストールされていません"
                fi
                ;;
            *.exe|*.msi)
                if command -v cabextract &> /dev/null; then
                    cabextract "$file" && echo "✅ 展開完了: $file" || echo "❌ 展開失敗: $file"
                else
                    echo "❌ cabextractがインストールされていません"
                    echo "インストール方法: brew install cabextract"
                fi
                ;;
            *)
                echo "❌ '$file' の形式は認識できません"
                echo "サポートされている形式は 'extract' と入力して確認してください"
                ;;
        esac
        
        [[ $? -eq 0 ]] && ((success++))
    done
    
    echo ""
    echo "📊 結果: $success/$total ファイルを展開しました"
}

# 圧縮ファイル作成のヘルパー関数
compress() {
    if [[ $# -lt 2 ]]; then
        echo "使用方法: compress <format> <file/directory> [output_name]"
        echo ""
        echo "サポートされている形式:"
        echo "  tar.gz, tar.bz2, tar.xz, tar.zst"
        echo "  zip, 7z"
        echo ""
        echo "例:"
        echo "  compress tar.gz mydir"
        echo "  compress zip myfile.txt output.zip"
        return 1
    fi
    
    local format="$1"
    local input="$2"
    local output="${3:-$(basename "$input").${format}}"
    
    if [[ ! -e "$input" ]]; then
        echo "❌ '$input' が存在しません"
        return 1
    fi
    
    echo "📦 圧縮中: $input -> $output"
    
    case "$format" in
        tar.gz|tgz)
            tar czf "$output" "$input" && echo "✅ 圧縮完了: $output"
            ;;
        tar.bz2|tbz2)
            tar cjf "$output" "$input" && echo "✅ 圧縮完了: $output"
            ;;
        tar.xz)
            tar cJf "$output" "$input" && echo "✅ 圧縮完了: $output"
            ;;
        tar.zst)
            if command -v zstd &> /dev/null; then
                tar --zstd -cf "$output" "$input" && echo "✅ 圧縮完了: $output"
            else
                echo "❌ zstdがインストールされていません"
                echo "インストール方法: brew install zstd"
            fi
            ;;
        zip)
            if command -v zip &> /dev/null; then
                zip -r "$output" "$input" && echo "✅ 圧縮完了: $output"
            else
                echo "❌ zipがインストールされていません"
            fi
            ;;
        7z)
            if command -v 7z &> /dev/null; then
                7z a "$output" "$input" && echo "✅ 圧縮完了: $output"
            else
                echo "❌ 7zがインストールされていません"
                echo "インストール方法: brew install p7zip"
            fi
            ;;
        *)
            echo "❌ 不明な形式: $format"
            return 1
            ;;
    esac
}