# Zsh設定ファイル
# モジュール化された設定を読み込み

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="${HOME}/src/github.com/ryosukesuto/dotfiles"

# zsh設定ファイルを番号順に読み込み
if [ -d "${DOTFILES_DIR}/zsh" ]; then
  for config in "${DOTFILES_DIR}"/zsh/*.zsh; do
    if [ -r "$config" ]; then
      source "$config"
    fi
  done
fi

# ローカル専用設定（Gitで管理しない）
if [ -f "${HOME}/.zshrc.local" ]; then
  source "${HOME}/.zshrc.local"
fi