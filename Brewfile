# Brewfile - dotfiles依存ツール
# Usage: brew bundle install --file=Brewfile

# Taps
# (homebrew/cask-fonts は廃止、homebrew-cask に統合済み)

# ===== 必須 =====
brew "git"
brew "git-filter-repo"   # git履歴からの機密情報除去
brew "zsh"
brew "tmux"
brew "vim"            # gitconfigのeditor、vimrcでプラグイン使用
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
brew "peco"          # fzfフォールバック（ghq連携）
brew "k1LoW/tap/git-wt"  # git worktree管理
brew "terminal-notifier"  # macOS通知

# ===== バージョン管理 =====
brew "mise"

# ===== IaCツール =====
brew "terraform"     # fmt/validate/補完用（apply/planはGitOps経由）
brew "tflint"        # Terraform linter
brew "trivy"         # セキュリティスキャナ
brew "kubeconform"   # K8sマニフェスト検証

# ===== クラウドCLI =====
brew "awscli"        # AWS CLI
cask "gcloud-cli"        # gcloud CLI

# ===== メディア処理 =====
brew "imagemagick"   # 画像変換・加工
brew "poppler"       # PDF処理（pdftotext等）

# ===== 開発環境 =====
# Node.js / Codex CLIはmiseで管理（config/mise/config.toml）
cask "docker"        # Docker Desktop（CLI + Compose V2 + GUI）
cask "devpod"        # Dev Container管理
brew "go-task"       # タスクランナー
brew "protobuf"      # Protocol Buffers
brew "clang-format"  # C/C++フォーマッタ

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
cask "claude"              # Claude Desktop
cask "cloudflare-warp"     # VPNクライアント
cask "notion"              # ドキュメント管理
cask "spotify"             # 音楽ストリーミング
