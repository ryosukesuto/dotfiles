# Main .zshrc file - sources all modular configuration files
# This file is the entry point for Zsh configuration

# Get the directory where dotfiles are located
# Try to get the real path if this file is symlinked
if [ -L ~/.zshrc ]; then
    DOTFILES_DIR="$(dirname "$(readlink ~/.zshrc)")"
else
    DOTFILES_DIR="${HOME}/src/github.com/ryosukesuto/dotfiles"
fi

# Source all zsh configuration files in order
if [ -d "${DOTFILES_DIR}/zsh" ]; then
    for config in "${DOTFILES_DIR}"/zsh/*.zsh; do
        [ -r "$config" ] && source "$config"
    done
fi

# Source local configuration if it exists
[ -r ~/.zshrc.local ] && source ~/.zshrc.local

# Source environment variables
[ -r ~/.env.local ] && source ~/.env.local
[ -r "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
