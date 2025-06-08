export PATH=$PATH:/Users/ryosukesuto/.tfenv/bin:$GOPATH/bin
export GOPATH=$HOME

export CLICOLOR=1

bindkey -e

HISTSIZE=50000
SAVEHIST=50000

setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt share_history

autoload -Uz compinit
compinit -u
if [ -e /opt/homebrew/bin/zsh/zsh-completions ]; then
  fpath=(/opt/homebrew/bin/zsh/zsh-completions $fpath)
fi

setopt list_packed
autoload colors
zstyle ':completion:*' list-colors ''

setopt no_beep

function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/Cellar/tfenv/3.0.0/versions/1.10.5/terraform terraform

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# dbt開発環境設定
export DBT_PROJECT_ID=youtrust-sandbox-dwh
export DBT_AWS_ENV=staging
export DBT_DATA_POLICY_TAG_ID=dummy
