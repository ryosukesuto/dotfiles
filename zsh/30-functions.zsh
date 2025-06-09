# ディレクトリ作成と移動を同時に行う
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# ファイル/ディレクトリのサイズを表示
sizeof() {
  if command -v dust &> /dev/null; then
    dust "$@"
  else
    du -sh "$@"
  fi
}

# 圧縮ファイルの展開
extract() {
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
}

# ghqとfzf/pecoを使った高速ディレクトリ移動
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
  # pecoを使ったバージョン（元の実装）
  function peco-src() {
    local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
    if [[ -n "$selected_dir" ]]; then
      BUFFER="cd ${selected_dir}"
      zle accept-line
    fi
    zle clear-screen
  }
  zle -N peco-src
  bindkey '^]' peco-src
fi

# Git操作の便利関数
gacp() {
  git add . && git commit -m "$1" && git push
}

# ポート番号で実行中のプロセスを表示
port() {
  lsof -i :"$1"
}

# クリップボードにコピー（macOS）
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias copy='pbcopy'
  alias paste='pbpaste'
fi

# AWS SSM 踏み台サーバー接続
aws-bastion() {
  local profile="${1:-prod}"
  local instance_id="${2:-i-0e64e6cac72e4d659}"
  local region="${3:-ap-northeast-1}"
  
  echo "🔐 AWS SSO ログイン中..."
  aws sso login --profile "$profile"
  
  echo "🚀 踏み台サーバーへのSSMセッションを開始中..."
  aws ssm start-session --target "$instance_id" --profile "$profile" --region "$region"
}

# AWS SSM 踏み台サーバー選択接続
aws-bastion-select() {
  local profile="${1:-prod}"
  local region="${2:-ap-northeast-1}"
  
  echo "🔐 AWS SSO ログイン中..."
  aws sso login --profile "$profile"
  
  echo "🔍 利用可能な踏み台サーバーを取得中..."
  local instances=$(aws ec2 describe-instances \
    --profile "$profile" \
    --region "$region" \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value | [0]]" \
    --output text | grep -i bastion | sort -k2)
  
  if [[ -z "$instances" ]]; then
    echo "⚠️  踏み台サーバーが見つかりません。全インスタンスを表示します..."
    instances=$(aws ec2 describe-instances \
      --profile "$profile" \
      --region "$region" \
      --filters "Name=instance-state-name,Values=running" \
      --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value | [0]]" \
      --output text | sort -k2)
  fi
  
  if [[ -z "$instances" ]]; then
    echo "❌ 実行中のインスタンスが見つかりません"
    return 1
  fi
  
  local selected=$(echo "$instances" | fzf --prompt="踏み台サーバーを選択: " --height=40% --reverse)
  
  if [[ -n "$selected" ]]; then
    local instance_id=$(echo "$selected" | awk '{print $1}')
    echo "🚀 踏み台サーバーへのSSMセッションを開始中: $instance_id"
    aws ssm start-session --target "$instance_id" --profile "$profile" --region "$region"
  fi
}

# システム診断機能
dotfiles-diag() {
  echo "🔍 Dotfiles環境診断"
  echo "===================="
  
  # シェル環境
  echo -n "Zsh: "
  if [[ -n "$ZSH_VERSION" ]]; then
    echo "✅ $ZSH_VERSION"
  else
    echo "❌ Zsh が実行されていません"
  fi
  
  # パッケージマネージャー
  echo -n "Homebrew: "
  if command -v brew &> /dev/null; then
    echo "✅ $(brew --version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  # バージョン管理
  echo -n "pyenv: "
  if command -v pyenv &> /dev/null; then
    echo "✅ $(pyenv --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "rbenv: "
  if command -v rbenv &> /dev/null; then
    echo "✅ $(rbenv --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "nodenv: "
  if command -v nodenv &> /dev/null; then
    echo "✅ $(nodenv --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  # 開発ツール
  echo -n "Git: "
  if command -v git &> /dev/null; then
    echo "✅ $(git --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "ghq: "
  if command -v ghq &> /dev/null; then
    echo "✅ $(ghq --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "fzf: "
  if command -v fzf &> /dev/null; then
    echo "✅ $(fzf --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "tmux: "
  if command -v tmux &> /dev/null; then
    echo "✅ $(tmux -V)"
  else
    echo "❌ インストールされていません"
  fi
  
  # モダンなCLIツール
  echo -n "eza (ls alternative): "
  if command -v eza &> /dev/null; then
    echo "✅ $(eza --version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "bat (cat alternative): "
  if command -v bat &> /dev/null; then
    echo "✅ $(bat --version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "ripgrep (grep alternative): "
  if command -v rg &> /dev/null; then
    echo "✅ $(rg --version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "fd (find alternative): "
  if command -v fd &> /dev/null; then
    echo "✅ $(fd --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  # クラウドツール
  echo -n "AWS CLI: "
  if command -v aws &> /dev/null; then
    echo "✅ $(aws --version 2>&1 | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "Terraform: "
  if command -v terraform &> /dev/null; then
    echo "✅ $(terraform version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "kubectl: "
  if command -v kubectl &> /dev/null; then
    echo "✅ $(kubectl version --client --short 2>/dev/null || echo "Client installed")"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "Docker: "
  if command -v docker &> /dev/null; then
    echo "✅ $(docker --version)"
  else
    echo "❌ インストールされていません"
  fi
  
  echo -n "GitHub CLI: "
  if command -v gh &> /dev/null; then
    echo "✅ $(gh --version | head -n1)"
  else
    echo "❌ インストールされていません"
  fi
  
  # 設定ファイル確認
  echo ""
  echo "📁 設定ファイル状況"
  echo "=================="
  
  local dotfiles_dir
  if [[ -L ~/.zshrc ]]; then
    dotfiles_dir="$(dirname "$(readlink ~/.zshrc)")"
    echo "✅ dotfilesは $dotfiles_dir にリンクされています"
  else
    echo "❌ .zshrcがシンボリックリンクではありません"
  fi
  
  echo -n "Git設定: "
  if [[ -f ~/.gitconfig ]]; then
    echo "✅ ~/.gitconfig が存在します"
  else
    echo "❌ ~/.gitconfig が見つかりません"
  fi
  
  echo -n "SSH設定: "
  if [[ -f ~/.ssh/config ]]; then
    echo "✅ ~/.ssh/config が存在します"
  else
    echo "❌ ~/.ssh/config が見つかりません"
  fi
  
  echo -n "tmux設定: "
  if [[ -f ~/.tmux.conf ]]; then
    echo "✅ ~/.tmux.conf が存在します"
  else
    echo "❌ ~/.tmux.conf が見つかりません"
  fi
  
  echo ""
  echo "⚡ パフォーマンス情報"
  echo "=================="
  echo "プロンプトキャッシュ: $_prompt_cache_ttl 秒"
  echo "ツール遅延読み込み: $([ $_tools_init_done -eq 1 ] && echo "初期化済み" || echo "未初期化")"
}

# fzfの設定と関数
if command -v fzf &> /dev/null; then
  # fzfのデフォルト設定
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
  
  # ripgrepがあればfzfのデフォルトコマンドに設定
  if command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  fi
  
  # fzfのキーバインドを安全に設定
  if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  elif [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
    source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
    source /opt/homebrew/opt/fzf/shell/completion.zsh
  fi
fi