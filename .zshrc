# メイン .zshrc ファイル - すべてのモジュール設定ファイルを読み込み
# このファイルは Zsh 設定のエントリーポイント

# dotfiles/bin を即座にPATHに追加（thコマンドなどを利用可能にする）
export PATH="$HOME/src/github.com/ryosukesuto/dotfiles/bin:$PATH"

# dotfiles が配置されているディレクトリを取得
# このファイルがシンボリックリンクの場合は実際のパスを取得
if [ -L ~/.zshrc ]; then
    DOTFILES_DIR="$(dirname "$(readlink ~/.zshrc)")"
else
    DOTFILES_DIR="${HOME}/src/github.com/ryosukesuto/dotfiles"
fi

# すべての zsh 設定ファイルを順番に読み込み
if [ -d "${DOTFILES_DIR}/zsh" ]; then
    for config in "${DOTFILES_DIR}"/zsh/*.zsh; do
        [ -r "$config" ] && source "$config"
    done
fi

# ローカル設定が存在する場合は読み込み
[ -r ~/.zshrc.local ] && source ~/.zshrc.local

# 環境変数を読み込み
[ -r ~/.env.local ] && source ~/.env.local
[ -r "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
