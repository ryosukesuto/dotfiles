#!/usr/bin/env zsh
# シェル関数定義

# ghq + fzf によるリポジトリナビゲーション
if (( $+commands[ghq] )) && (( $+commands[fzf] )); then
    fzf-src() {
        local dir=$(ghq list -p | fzf --height 40% --reverse)
        [[ -n "$dir" ]] && { BUFFER="cd ${(q)dir}"; zle accept-line }
        zle clear-screen
    }
    zle -N fzf-src
    bindkey '^]' fzf-src
    bindkey '\e[91;5u' fzf-src  # CSI u: Ctrl+]
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

# bw unlock ラッパー（cmuxでプロンプトが表示されない問題の回避）
bw-unlock() {
    if [[ -n "${CMUX_SOCKET_PATH:-}" ]]; then
        local pw
        read -rs "pw?Master password: "
        echo
        command bw unlock --raw "$pw"
    else
        command bw unlock --raw "$@"
    fi
}
