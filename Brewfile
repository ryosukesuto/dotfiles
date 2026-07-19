# Brewfile - dotfiles依存ツール
# Usage: brew bundle install --file=Brewfile

# Taps
# (homebrew/cask-fonts は廃止、homebrew-cask に統合済み)
tap "datadog-labs/pack"      # pup（Datadog CLI）用
tap "hashicorp/tap"          # terraform（BSL移行でhomebrew-coreから削除）
tap "1password/tap"          # 1password-cli

# ===== 必須 =====
brew "git"
brew "git-filter-repo"   # git履歴からの機密情報除去
brew "gitleaks"          # 機密情報（APIキー・トークン等）検出
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
brew "k1LoW/tap/git-wt"  # git worktree管理
brew "lazygit"       # Git TUI（worktreeごとのdiffレビュー用）
brew "git-delta"     # 構文ハイライト付きdiff viewer（lazygitのpagerに使用）
brew "terminal-notifier"  # macOS通知

# ===== バージョン管理 =====
brew "mise"

# ===== IaCツール =====
brew "hashicorp/tap/terraform"  # fmt/validate/補完用（apply/planはGitOps経由）
# tflint はGitHub Releases から直接installする（install.sh 参照）
# brew "tflint" は homebrew-core / 公式tap 双方で不安定なため除外
brew "trivy"         # セキュリティスキャナ
brew "kubeconform"   # K8sマニフェスト検証
brew "argocd"        # ArgoCD CLI（K8s GitOps）

# ===== Lint/Format =====
brew "biome"         # JS/TS linter & formatter

# ===== 監視・運用 =====
brew "datadog-labs/pack/pup"  # Datadog CLI（要 tap: datadog-labs/pack）

# ===== クラウドCLI =====
brew "awscli"        # AWS CLI
cask "session-manager-plugin"  # AWS SSM Session Manager用プラグイン
cask "gcloud-cli"        # gcloud CLI

# ===== メディア処理 =====
brew "imagemagick"   # 画像変換・加工
brew "poppler"       # PDF処理（pdftotext等）

# ===== 開発環境 =====
# Node.jsはmise、Codex CLIは公式standalone installerで管理（install.sh）
cask "docker-desktop" # Docker Desktop（CLI + Compose V2 + GUI、旧 cask "docker" からリネーム）
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
cask "1password/tap/1password-cli"  # 1Password CLI (op)。formulaではなくcask配布
cask "arc"                 # ブラウザ
cask "bitwarden"           # パスワード管理（OSS）
cask "chatgpt"             # ChatGPTデスクトップ
cask "figma"               # デザインツール
cask "keeper-password-manager"  # パスワード管理
cask "meetingbar"          # カレンダー連携会議通知
cask "microsoft-teams"     # コミュニケーション
cask "slack"               # コミュニケーション
cask "obsidian"            # ノートアプリ
cask "google-japanese-ime" # 日本語入力
cask "alt-tab"             # ウィンドウスイッチャー
cask "raycast"             # ランチャー・ホットキー管理
cask "claude"              # Claude Desktop
cask "cloudflare-warp"     # VPNクライアント
cask "notion"              # ドキュメント管理
cask "spotify"             # 音楽ストリーミング
