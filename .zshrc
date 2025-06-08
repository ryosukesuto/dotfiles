# Zsh設定ファイル
# モジュール化された設定を読み込み

# dotfilesディレクトリのパスを取得
DOTFILES_DIR="${HOME}/src/github.com/ryosukesuto/dotfiles"

# zsh設定ファイルを番号順に読み込み（安全版）
if [ -d "${DOTFILES_DIR}/zsh" ]; then
  for config in "${DOTFILES_DIR}"/zsh/*.zsh; do
    if [ -r "$config" ]; then
      # 問題のあるファイルはスキップまたは安全に読み込み
      case "$(basename $config)" in
        "30-functions.zsh")
          # fzf設定を除外して読み込み
          source <(head -n 79 "$config")
          ;;
        "40-tools.zsh")
          # 簡略化されたツール設定のみ読み込み
          if command -v pyenv &> /dev/null; then
            eval "$(pyenv init --path)" 2>/dev/null
            eval "$(pyenv init -)" 2>/dev/null
          fi
          ;;
        "50-prompt.zsh")
          # Starshipのみ有効化
          if command -v starship &> /dev/null; then
            eval "$(starship init zsh)"
          else
            PROMPT='%F{blue}%~%f %F{magenta}❯%f '
            RPROMPT='%F{grey}%T%f'
          fi
          ;;
        *)
          # その他のファイルは通常通り読み込み
          source "$config"
          ;;
      esac
    fi
  done
fi

# ローカル専用設定（Gitで管理しない）
if [ -f "${HOME}/.zshrc.local" ]; then
  source "${HOME}/.zshrc.local"
fi