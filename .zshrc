# メイン .zshrc - モジュール設定を読み込み

# dotfilesディレクトリを取得（シンボリックリンクを解決）
if [[ -L ~/.zshrc ]]; then
    DOTFILES_DIR="$(dirname "$(readlink ~/.zshrc)")"
else
    DOTFILES_DIR="$HOME/gh/ryosukesuto/dotfiles"
fi

# すべての zsh 設定ファイルを順番に読み込み
if [ -d "${DOTFILES_DIR}/zsh" ]; then
    for config in "${DOTFILES_DIR}"/zsh/*.zsh; do
        [ -r "$config" ] && source "$config"
    done
fi

# ローカル設定
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

# bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

# gws personal account
# OAuthクライアント: ~/.config/gws-personal/client_secret.json（自前作成、デスクトップアプリ型）
# 社内のCLIENT_ID/SECRET環境変数をunsetして、client_secret.jsonから読ませる
function gws-personal() {
  env -u GOOGLE_WORKSPACE_CLI_CLIENT_ID \
      -u GOOGLE_WORKSPACE_CLI_CLIENT_SECRET \
      GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-personal" \
      gws "$@"
}
