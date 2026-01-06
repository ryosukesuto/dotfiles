#!/usr/bin/env zsh
# シェル関数定義

# ghq + fzf/peco によるリポジトリナビゲーション
if (( $+commands[ghq] )); then
    if (( $+commands[fzf] )); then
        fzf-src() {
            local dir=$(ghq list -p | fzf --height 40% --reverse)
            [[ -n "$dir" ]] && { BUFFER="cd ${(q)dir}"; zle accept-line }
            zle clear-screen
        }
        zle -N fzf-src
        bindkey '^]' fzf-src
    elif (( $+commands[peco] )); then
        peco-src() {
            local dir=$(ghq list -p | peco)
            [[ -n "$dir" ]] && { BUFFER="cd ${(q)dir}"; zle accept-line }
            zle clear-screen
        }
        zle -N peco-src
        bindkey '^g' peco-src
    fi
fi
