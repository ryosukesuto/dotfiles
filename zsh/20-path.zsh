#!/usr/bin/env zsh
# PATH環境変数管理

# 重複パスを自動削除
typeset -U path PATH

# ローカルバイナリ（優先）
[[ -d "$HOME/.local/share/mise/shims" ]] && path=("$HOME/.local/share/mise/shims" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
[[ -n "$DOTFILES_DIR" && -d "$DOTFILES_DIR/bin" ]] && path=("$DOTFILES_DIR/bin" $path)

# Homebrew
if [[ -d "/opt/homebrew" ]]; then
    path+=("/opt/homebrew/bin" "/opt/homebrew/sbin")
    export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -d "/usr/local/Homebrew" ]]; then
    path+=("/usr/local/bin" "/usr/local/sbin")
    export HOMEBREW_PREFIX="/usr/local"
fi

# Google Cloud SDK
[[ -d "$HOME/google-cloud-sdk/bin" ]] && path+=("$HOME/google-cloud-sdk/bin")
