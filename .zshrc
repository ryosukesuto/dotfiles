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
    [[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
fi

# bun completions
[ -s "/Users/s32943/.bun/_bun" ] && source "/Users/s32943/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias claude-mem='/Users/s32943/.bun/bin/bun "/Users/s32943/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
