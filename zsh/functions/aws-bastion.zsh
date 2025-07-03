#!/usr/bin/env zsh
# ============================================================================
# aws-bastion.zsh - AWS SSM Session Manager Bastion接続
# ============================================================================
# このファイルは遅延読み込みされ、AWS Bastion機能が必要な時のみロードされます。

# AWS SSM Session Manager経由でBastionサーバーに接続
aws-bastion() {
    local profile="${1:-prod}"
    local instance_id="${2}"
    local region="${3:-ap-northeast-1}"
    
    # インスタンスIDが指定されていない場合はヘルプを表示
    if [[ -z "$instance_id" ]]; then
        echo "使用方法: aws-bastion [profile] <instance-id> [region]"
        echo "例: aws-bastion prod i-1234567890abcdef0"
        echo "または aws-bastion-select を使用してインタラクティブに選択"
        return 1
    fi
    
    echo "🔐 AWS SSO ログイン中..."
    aws sso login --profile "$profile"
    
    echo "🚀 踏み台サーバーへのSSMセッションを開始中..."
    aws ssm start-session --target "$instance_id" --profile "$profile" --region "$region"
}

# インタラクティブにBastionサーバーを選択して接続
aws-bastion-select() {
    local profile="${1:-prod}"
    local region="${2:-ap-northeast-1}"
    
    echo "🔐 AWS SSO ログイン中..."
    aws sso login --profile "$profile"
    
    echo "🔍 利用可能なインスタンスを検索中..."
    
    # bastionタグを持つ実行中のインスタンスを取得
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag-key,Values=bastion" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
        --output text \
        --profile "$profile" \
        --region "$region" 2>/dev/null)
    
    # bastionタグを持つインスタンスが見つからない場合は、全ての実行中のインスタンスを取得
    if [[ -z "$instances" ]]; then
        echo "⚠️  bastionタグを持つインスタンスが見つかりません。全ての実行中のインスタンスを表示します..."
        instances=$(aws ec2 describe-instances \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
            --output text \
            --profile "$profile" \
            --region "$region" 2>/dev/null)
    fi
    
    if [[ -z "$instances" ]]; then
        echo "❌ 実行中のインスタンスが見つかりません"
        return 1
    fi
    
    # fzfまたはpecoで選択
    local selected
    if command -v fzf &> /dev/null; then
        selected=$(echo "$instances" | fzf --header="接続するインスタンスを選択してください" --height=50% --layout=reverse)
    elif command -v peco &> /dev/null; then
        selected=$(echo "$instances" | peco --prompt="接続するインスタンスを選択 >")
    else
        # fzfもpecoもない場合は番号選択
        echo "インスタンス一覧:"
        echo "$instances" | nl
        echo -n "接続するインスタンスの番号を入力してください: "
        read num
        selected=$(echo "$instances" | sed -n "${num}p")
    fi
    
    if [[ -n "$selected" ]]; then
        local instance_id=$(echo "$selected" | awk '{print $1}')
        echo "🚀 ${instance_id} へのSSMセッションを開始中..."
        aws ssm start-session --target "$instance_id" --profile "$profile" --region "$region"
    else
        echo "❌ インスタンスが選択されませんでした"
        return 1
    fi
}

# エイリアスも定義（互換性のため）
alias bastion='aws-bastion'
alias bastion-select='aws-bastion-select'