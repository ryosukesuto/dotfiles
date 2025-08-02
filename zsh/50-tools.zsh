#!/usr/bin/env zsh
# ============================================================================
# 50-tools.zsh - 開発ツールの初期化
# ============================================================================
# このファイルはmiseなどの開発ツールを初期化します。

# mise初期化
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi


# Terraform補完（シンプルな設定）
if command -v terraform &> /dev/null; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C $(which terraform) terraform
fi

# GitHub CLI補完（シンプルな設定）
if command -v gh &> /dev/null; then
  eval "$(gh completion -s zsh 2>/dev/null)"
fi

# Docker補完（即座に読み込み - ファイルベースなので高速）
if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion
fi

if [[ -f /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion ]]; then
  source /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion
fi