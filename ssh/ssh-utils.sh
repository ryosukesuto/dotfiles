#!/bin/bash

# SSH管理ユーティリティスクリプト
# SSH設定の管理と便利なコマンド集

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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
}

# ヘルプ表示
show_help() {
    cat << EOF
SSH管理ユーティリティ

使用方法:
    ssh-utils <command> [options]

コマンド:
    list-hosts          設定されているホスト一覧を表示
    test-connection     ホストへの接続テスト
    generate-key        新しいSSHキーを生成
    add-host            新しいホスト設定を追加
    backup-keys         SSHキーをバックアップ
    check-security      SSH設定のセキュリティチェック
    cleanup             古い接続ソケットをクリーンアップ

例:
    ssh-utils list-hosts
    ssh-utils test-connection github.com
    ssh-utils generate-key ed25519 mykey
EOF
}

# ホスト一覧表示
list_hosts() {
    info "設定されているSSHホスト一覧:"
    echo ""
    
    if [[ -f ~/.ssh/config ]]; then
        grep "^Host " ~/.ssh/config | grep -v "\*" | while read -r line; do
            host=$(echo "$line" | awk '{print $2}')
            echo -e "${BLUE}  $host${NC}"
        done
    else
        warn "SSH設定ファイルが見つかりません"
    fi
}

# 接続テスト
test_connection() {
    local host="$1"
    
    if [[ -z "$host" ]]; then
        error "ホスト名を指定してください"
        return 1
    fi
    
    info "接続テスト中: $host"
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" exit 2>/dev/null; then
        info "✅ $host への接続成功"
    else
        warn "❌ $host への接続失敗"
    fi
}

# SSH鍵生成
generate_key() {
    local key_type="${1:-ed25519}"
    local key_name="${2:-id_$key_type}"
    local key_path="$HOME/.ssh/$key_name"
    
    info "SSH鍵を生成中..."
    echo "鍵タイプ: $key_type"
    echo "保存先: $key_path"
    echo ""
    
    read -p "メールアドレスを入力してください: " email
    
    if [[ -z "$email" ]]; then
        error "メールアドレスが必要です"
        return 1
    fi
    
    ssh-keygen -t "$key_type" -f "$key_path" -C "$email"
    
    if [[ $? -eq 0 ]]; then
        info "SSH鍵が生成されました: $key_path"
        info "公開鍵:"
        cat "${key_path}.pub"
        echo ""
        info "公開鍵をクリップボードにコピーしますか？ (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            cat "${key_path}.pub" | pbcopy
            info "公開鍵をクリップボードにコピーしました"
        fi
    fi
}

# ホスト設定追加
add_host() {
    local host_alias="$1"
    local hostname="$2"
    local user="$3"
    local key_file="$4"
    
    if [[ -z "$host_alias" ]] || [[ -z "$hostname" ]]; then
        echo "使用方法: add-host <エイリアス> <ホスト名> [ユーザー] [鍵ファイル]"
        return 1
    fi
    
    user="${user:-$(whoami)}"
    key_file="${key_file:-~/.ssh/id_ed25519}"
    
    info "新しいホスト設定を追加中..."
    
    cat >> ~/.ssh/config << EOF

# $host_alias - $(date +%Y-%m-%d)
Host $host_alias
    HostName $hostname
    User $user
    Port 22
    IdentityFile $key_file
    IdentitiesOnly yes
EOF
    
    info "ホスト設定を追加しました: $host_alias"
}

# SSHキーバックアップ
backup_keys() {
    local backup_dir="$HOME/.ssh/backup/$(date +%Y%m%d_%H%M%S)"
    
    info "SSHキーをバックアップ中..."
    mkdir -p "$backup_dir"
    
    cp ~/.ssh/id_* "$backup_dir/" 2>/dev/null
    cp ~/.ssh/config "$backup_dir/" 2>/dev/null
    
    info "バックアップ完了: $backup_dir"
}

# セキュリティチェック
check_security() {
    info "SSH設定のセキュリティチェック中..."
    echo ""
    
    # 鍵ファイルのパーミッションチェック
    info "🔑 鍵ファイルのパーミッションチェック:"
    for key in ~/.ssh/id_*; do
        if [[ -f "$key" ]] && [[ ! "$key" == *.pub ]]; then
            perm=$(stat -f %A "$key")
            if [[ "$perm" == "600" ]]; then
                echo -e "  ✅ $(basename "$key"): $perm"
            else
                echo -e "  ❌ $(basename "$key"): $perm (should be 600)"
                warn "修正: chmod 600 $key"
            fi
        fi
    done
    
    echo ""
    
    # SSH設定ファイルのチェック
    info "⚙️  SSH設定ファイルのチェック:"
    if [[ -f ~/.ssh/config ]]; then
        perm=$(stat -f %A ~/.ssh/config)
        if [[ "$perm" == "644" ]] || [[ "$perm" == "600" ]]; then
            echo -e "  ✅ config: $perm"
        else
            echo -e "  ❌ config: $perm (should be 600 or 644)"
        fi
        
        # 危険な設定をチェック
        if grep -q "StrictHostKeyChecking no" ~/.ssh/config; then
            warn "⚠️  StrictHostKeyChecking no が検出されました"
        fi
        
        if grep -q "PasswordAuthentication yes" ~/.ssh/config; then
            warn "⚠️  PasswordAuthentication yes が検出されました"
        fi
    fi
    
    echo ""
    info "セキュリティチェック完了"
}

# 古い接続ソケットのクリーンアップ
cleanup() {
    info "古いSSH接続ソケットをクリーンアップ中..."
    
    local socket_dir="$HOME/.ssh/sockets"
    
    if [[ -d "$socket_dir" ]]; then
        find "$socket_dir" -type s -mtime +1 -delete
        info "クリーンアップ完了"
    else
        info "ソケットディレクトリが見つかりません"
    fi
}

# メイン処理
main() {
    case "${1:-help}" in
        "list-hosts"|"list")
            list_hosts
            ;;
        "test-connection"|"test")
            test_connection "$2"
            ;;
        "generate-key"|"genkey")
            generate_key "$2" "$3"
            ;;
        "add-host"|"add")
            add_host "$2" "$3" "$4" "$5"
            ;;
        "backup-keys"|"backup")
            backup_keys
            ;;
        "check-security"|"security")
            check_security
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "不明なコマンド: $1"
            show_help
            exit 1
            ;;
    esac
}

# スクリプトとして実行された場合
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi