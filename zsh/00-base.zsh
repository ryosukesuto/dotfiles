# 基本設定
export CLICOLOR=1

# Emacsキーバインド
bindkey -e

# ビープ音を無効化
setopt no_beep

# 補完設定
autoload -Uz compinit
compinit -u

# Homebrewの補完
if [ -e /opt/homebrew/bin/zsh/zsh-completions ]; then
  fpath=(/opt/homebrew/bin/zsh/zsh-completions $fpath)
fi

# 補完リストの表示設定
setopt list_packed
autoload colors
zstyle ':completion:*' list-colors ''