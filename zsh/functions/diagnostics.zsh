#!/usr/bin/env zsh
# ============================================================================
# diagnostics.zsh - Dotfiles診断ツール
# ============================================================================
# このファイルは遅延読み込みされ、診断が必要な時のみロードされます。

# Dotfiles環境の診断
dotfiles-diag() {
    echo "🔍 Dotfiles診断ツール"
    echo "===================="
    
    # 基本情報
    echo ""
    echo "📊 基本情報"
    echo "----------"
    echo "日時: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "ユーザー: $USER"
    echo "ホスト: $HOST"
    echo "OS: $(uname -s) $(uname -r)"
    echo "シェル: $SHELL"
    echo "Zshバージョン: $ZSH_VERSION"
    
    # 環境変数
    echo ""
    echo "🔧 重要な環境変数"
    echo "----------------"
    echo "HOME: $HOME"
    echo "DOTFILES_DIR: ${DOTFILES_DIR:-未設定}"
    echo "PATH entries: $(echo $PATH | tr ':' '\n' | wc -l | tr -d ' ')"
    
    # dotfilesの状態
    echo ""
    echo "📁 Dotfilesの状態"
    echo "----------------"
    if [[ -n "$DOTFILES_DIR" ]] && [[ -d "$DOTFILES_DIR" ]]; then
        echo "✅ DOTFILES_DIR が正しく設定されています: $DOTFILES_DIR"
        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            echo "✅ Gitリポジトリとして管理されています"
            cd "$DOTFILES_DIR" && echo "  Branch: $(git branch --show-current 2>/dev/null || echo '不明')"
            cd - > /dev/null
        else
            echo "⚠️  Gitリポジトリではありません"
        fi
    else
        echo "❌ DOTFILES_DIR が設定されていないか、ディレクトリが存在しません"
    fi
    
    # インストールされているツール
    echo ""
    echo "🛠️  インストール済みツール"
    echo "----------------------"
    
    # パッケージマネージャー
    echo ""
    echo "📦 パッケージマネージャー:"
    echo -n "  Homebrew: "
    if command -v brew &> /dev/null; then
        echo "✅ $(brew --version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    # バージョン管理
    echo ""
    echo "🔄 バージョン管理:"
    echo -n "  pyenv: "
    if command -v pyenv &> /dev/null; then
        echo "✅ $(pyenv --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  tfenv: "
    if command -v tfenv &> /dev/null; then
        echo "✅ $(tfenv --version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  rbenv: "
    if command -v rbenv &> /dev/null; then
        echo "✅ $(rbenv --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  nodenv: "
    if command -v nodenv &> /dev/null; then
        echo "✅ $(nodenv --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    # 開発ツール
    echo ""
    echo "💻 開発ツール:"
    echo -n "  Git: "
    if command -v git &> /dev/null; then
        echo "✅ $(git --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  ghq: "
    if command -v ghq &> /dev/null; then
        echo "✅ $(ghq --version 2>&1 | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  fzf: "
    if command -v fzf &> /dev/null; then
        echo "✅ $(fzf --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  tmux: "
    if command -v tmux &> /dev/null; then
        echo "✅ $(tmux -V)"
    else
        echo "❌ インストールされていません"
    fi
    
    # モダンなCLIツール
    echo ""
    echo "🚀 モダンCLIツール:"
    echo -n "  eza: "
    if command -v eza &> /dev/null; then
        echo "✅ $(eza --version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  bat: "
    if command -v bat &> /dev/null; then
        echo "✅ $(bat --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  ripgrep: "
    if command -v rg &> /dev/null; then
        echo "✅ $(rg --version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  fd: "
    if command -v fd &> /dev/null; then
        echo "✅ $(fd --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    # クラウドツール
    echo ""
    echo "☁️  クラウドツール:"
    echo -n "  AWS CLI: "
    if command -v aws &> /dev/null; then
        echo "✅ $(aws --version 2>&1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  Terraform: "
    if command -v terraform &> /dev/null; then
        echo "✅ $(terraform version -json 2>/dev/null | jq -r .terraform_version 2>/dev/null || terraform version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  kubectl: "
    if command -v kubectl &> /dev/null; then
        echo "✅ $(kubectl version --client --short 2>/dev/null || echo "インストール済み")"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  Docker: "
    if command -v docker &> /dev/null; then
        echo "✅ $(docker --version)"
    else
        echo "❌ インストールされていません"
    fi
    
    echo -n "  GitHub CLI: "
    if command -v gh &> /dev/null; then
        echo "✅ $(gh --version | head -n1)"
    else
        echo "❌ インストールされていません"
    fi
    
    # Zsh設定
    echo ""
    echo "⚙️  Zsh設定"
    echo "---------"
    echo "設定ファイル読み込み順:"
    local i=1
    for f in $DOTFILES_DIR/zsh/*.zsh(N); do
        echo "  $i. $(basename $f)"
        ((i++))
    done
    
    # パフォーマンス情報
    echo ""
    echo "⚡ パフォーマンス情報"
    echo "------------------"
    if [[ -n "$ZSH_LOAD_TIME" ]]; then
        echo "起動時間: ${ZSH_LOAD_TIME}ms"
    else
        echo "起動時間: 測定されていません"
        echo "ヒント: .zshrcの最初と最後で時間を計測してください"
    fi
    
    echo ""
    echo "✨ 診断完了"
}