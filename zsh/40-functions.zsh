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
        bindkey '\e[91;5u' fzf-src  # CSI u: Ctrl+]
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

# git-wt + fzf によるworktree選択
if (( $+commands[git-wt] )) && (( $+commands[fzf] )); then
    fzf-wt() {
        # worktreeディレクトリにいるか確認
        local wt_list=$(git worktree list 2>/dev/null)
        if [[ -z "$wt_list" ]]; then
            zle -M "Not in a git repository or no worktrees"
            return 1
        fi
        local dir=$(echo "$wt_list" | fzf --height 40% --reverse | awk '{print $1}')
        [[ -n "$dir" ]] && { BUFFER="cd ${(q)dir}"; zle accept-line }
        zle clear-screen
    }
    zle -N fzf-wt
    bindkey '^\' fzf-wt  # Ctrl+\ でworktree選択
fi
