# メイン .zshrc ファイル - すべてのモジュール設定ファイルを読み込み
# このファイルは Zsh 設定のエントリーポイント

# dotfiles/bin を即座にPATHに追加（thコマンドなどを利用可能にする）
# セキュリティチェック付き
_dotfiles_bin="$HOME/src/github.com/ryosukesuto/dotfiles/bin"
if [[ -d "$_dotfiles_bin" ]]; then
    # ディレクトリの所有者チェック（自分が所有している場合のみ）
    if [[ -O "$_dotfiles_bin" ]]; then
        # 他者による書き込み権限がないことを確認
        local perms
        perms=$(stat -f "%Mp%Lp" "$_dotfiles_bin" 2>/dev/null || stat -c "%a" "$_dotfiles_bin" 2>/dev/null)
        if [[ "$perms" != *"2"* && "$perms" != *"6"* ]]; then
            export PATH="$_dotfiles_bin:$PATH"
        else
            echo "Warning: Skipping $_dotfiles_bin - insecure permissions (group/other writable)" >&2
        fi
    else
        echo "Warning: Skipping $_dotfiles_bin - not owned by current user" >&2
    fi
fi
unset _dotfiles_bin

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
