# Brewfile - dotfiles依存ツール
# Usage: brew bundle install --file=Brewfile

# Taps
# (homebrew/cask-fonts は廃止、homebrew-cask に統合済み)

# ===== 必須 =====
brew "git"
brew "zsh"
brew "tmux"
brew "gh"
brew "fzf"
brew "direnv"

# ===== 推奨（CLI強化） =====
brew "eza"           # ls代替
brew "bat"           # cat代替
brew "ripgrep"       # grep代替
brew "fd"            # find代替
brew "jq"            # JSON処理
brew "ghq"           # リポジトリ管理
brew "terminal-notifier"  # macOS通知

# ===== バージョン管理 =====
brew "mise"

# ===== IaCツール =====
brew "tflint"        # Terraform linter
brew "trivy"         # セキュリティスキャナ
brew "kubeconform"   # K8sマニフェスト検証

# ===== クラウドCLI =====
brew "awscli"        # AWS CLI
cask "gcloud-cli"        # gcloud CLI

# ===== 開発環境 =====
# Node.js / Codex CLIはmiseで管理（config/mise/config.toml）
brew "docker"        # Docker CLI（Apple Container互換）
brew "docker-compose" # Docker Compose
cask "devpod"        # Dev Container管理
brew "go-task"       # タスクランナー
# Note: Container runtimeはmacOS 26のApple Containerを使用

# ===== フォント =====
cask "font-udev-gothic-nf"

# ===== ターミナル =====
cask "ghostty"

# ===== アプリケーション =====
cask "1password"           # パスワード管理
cask "arc"                 # ブラウザ
cask "bitwarden"           # パスワード管理（OSS）
cask "chatgpt"             # ChatGPTデスクトップ
cask "figma"               # デザインツール
cask "keeper-password-manager"  # パスワード管理
cask "meetingbar"          # カレンダー連携会議通知
cask "microsoft-teams"     # コミュニケーション
cask "obsidian"            # ノートアプリ
cask "google-japanese-ime" # 日本語入力
cask "alt-tab"             # ウィンドウスイッチャー
cask "cloudflare-warp"     # VPNクライアント
