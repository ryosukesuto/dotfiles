#!/usr/bin/env zsh
# ============================================================================
# aws-bastion.zsh - AWS SSM Session Manager Bastion接続
# ============================================================================
# このファイルは遅延読み込みされ、AWS Bastion機能が必要な時のみロードされます。

# AWS SSM Session Manager経由でBastionサーバーに接続
aws-bastion() {
    # AWS CLIの存在確認
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLIがインストールされていません" >&2
        echo "インストール方法: brew install awscli" >&2
        return 1
    fi
    
    # Session Manager Pluginの存在確認
    if ! command -v session-manager-plugin &> /dev/null; then
        echo "❌ AWS Session Manager Pluginがインストールされていません" >&2
        echo "インストール方法: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html" >&2
        return 1
    fi
    
    local instance_id="$1"
    
    if [[ -z "$instance_id" ]]; then
        echo "使用方法: aws-bastion <instance-id>"
        echo "または aws-bastion-select を使用してインタラクティブに選択"
        return 1
    fi
    
    # プロファイル指定がある場合は使用
    local profile_option=""
    if [[ -n "$AWS_PROFILE" ]]; then
        profile_option="--profile $AWS_PROFILE"
    fi
    
    echo "🔐 Bastionサーバーに接続中: $instance_id"
    echo "プロファイル: ${AWS_PROFILE:-default}"
    
    # SSM Session Manager経由で接続
    aws ssm start-session \
        --target "$instance_id" \
        $profile_option \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters '{
            "host": ["localhost"],
            "portNumber": ["3306"],
            "localPortNumber": ["3306"]
        }'
}

# インタラクティブにBastionサーバーを選択して接続
aws-bastion-select() {
    # 依存コマンドの確認
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLIがインストールされていません" >&2
        return 1
    fi
    
    if ! command -v fzf &> /dev/null && ! command -v peco &> /dev/null; then
        echo "❌ fzfまたはpecoがインストールされていません" >&2
        echo "インストール方法: brew install fzf" >&2
        return 1
    fi
    
    # プロファイル指定
    local profile_option=""
    if [[ -n "$AWS_PROFILE" ]]; then
        profile_option="--profile $AWS_PROFILE"
    fi
    
    echo "🔍 Bastionサーバーを検索中..."
    echo "プロファイル: ${AWS_PROFILE:-default}"
    
    # EC2インスタンスのリストを取得（Bastion タグでフィルタ）
    local instances
    instances=$(aws ec2 describe-instances \
        $profile_option \
        --filters "Name=tag:Name,Values=*[Bb]astion*" \
                 "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`] | [0].Value,PrivateIpAddress,PublicIpAddress]' \
        --output text 2>/dev/null)
    
    if [[ -z "$instances" ]]; then
        # Bastionタグがない場合は全てのrunningインスタンスを取得
        echo "⚠️  'Bastion'タグのインスタンスが見つかりません。全てのインスタンスを表示します。"
        instances=$(aws ec2 describe-instances \
            $profile_option \
            --filters "Name=instance-state-name,Values=running" \
            --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`] | [0].Value,PrivateIpAddress,PublicIpAddress]' \
            --output text 2>/dev/null)
    fi
    
    if [[ -z "$instances" ]]; then
        echo "❌ 実行中のインスタンスが見つかりません" >&2
        return 1
    fi
    
    # フォーマットして表示
    local formatted_instances
    formatted_instances=$(echo "$instances" | awk '{
        printf "%-20s %-40s %-15s %-15s\n", $1, $2, $3, $4
    }')
    
    # セレクターを使用して選択
    local selected
    if command -v fzf &> /dev/null; then
        selected=$(echo "$formatted_instances" | fzf \
            --header="インスタンスID      名前                                     プライベートIP   パブリックIP" \
            --height=40% \
            --reverse)
    else
        selected=$(echo "$formatted_instances" | peco \
            --prompt="Bastionサーバーを選択 >")
    fi
    
    if [[ -n "$selected" ]]; then
        local instance_id=$(echo "$selected" | awk '{print $1}')
        aws-bastion "$instance_id"
    else
        echo "❌ キャンセルされました" >&2
        return 1
    fi
}

# エイリアスも定義（互換性のため）
alias bastion='aws-bastion'
alias bastion-select='aws-bastion-select'