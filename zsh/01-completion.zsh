#!/usr/bin/env zsh
# ============================================================================
# 01-completion.zsh - Zsh補完システムの統合設定
# ============================================================================
# このファイルは補完システムの初期化と設定を一元管理します。
# パフォーマンスを考慮し、必要最小限の設定を起動時に行い、
# 詳細な設定は実際に補完を使用する際に遅延読み込みされます。

# ============================================================================
# 補完パスの設定
# ============================================================================
# Homebrewの補完パス
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
    fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# システムの補完パス
if [[ -d /usr/local/share/zsh/site-functions ]]; then
    fpath=(/usr/local/share/zsh/site-functions $fpath)
fi

# カスタム補完関数のパス
if [[ -d "${HOME}/.zsh/completions" ]]; then
    fpath=("${HOME}/.zsh/completions" $fpath)
fi

# 重複パスを削除
typeset -U fpath

# ============================================================================
# キャッシュディレクトリの設定
# ============================================================================
# 補完キャッシュディレクトリの作成
ZSH_CACHE_DIR="${HOME}/.cache/zsh"
[[ ! -d "$ZSH_CACHE_DIR" ]] && mkdir -p "$ZSH_CACHE_DIR"

# zcompdumpパスを固定（パフォーマンス向上）
export ZSH_COMPDUMP="${ZSH_CACHE_DIR}/zcompdump-${ZSH_VERSION}"

# ============================================================================
# 補完システムの初期化（最適化版）
# ============================================================================
autoload -Uz compinit

# compdumpファイルの更新チェック
_zsh_compdump_modified() {
    local compdump_path="$1"
    local compdump_zwc="${compdump_path}.zwc"
    
    # .zwcファイルが.zcompdumpより新しければ再コンパイル不要
    [[ -f "$compdump_zwc" && "$compdump_zwc" -nt "$compdump_path" ]] && return 1
    
    # 24時間以内の更新チェック
    if [[ -f "$compdump_path" ]]; then
        local compdump_age=$(( $(date +%s) - $(stat -f %m "$compdump_path" 2>/dev/null || stat -c %Y "$compdump_path" 2>/dev/null) ))
        [[ $compdump_age -lt 86400 ]] && return 1
    fi
    
    return 0
}

# 高速な補完初期化
if ! _zsh_compdump_modified "$ZSH_COMPDUMP"; then
    # キャッシュが有効な場合は高速起動
    compinit -C -d "$ZSH_COMPDUMP"
else
    # キャッシュが無効な場合は再生成
    compinit -d "$ZSH_COMPDUMP"
    # バイトコンパイルして次回起動を高速化
    [[ -f "$ZSH_COMPDUMP" ]] && zcompile "$ZSH_COMPDUMP"
fi

# 関数をアンロード
unfunction _zsh_compdump_modified

# ============================================================================
# 基本的な補完スタイル（起動時に必要な最小限の設定）
# ============================================================================
# メニュー選択を有効化
zstyle ':completion:*' menu select

# 大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 補完キャッシュを使用
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${ZSH_CACHE_DIR}"

# ============================================================================
# 詳細な補完スタイル（遅延読み込み）
# ============================================================================
# 詳細な補完スタイル設定関数
_init_detailed_completion_styles() {
    # 色設定
    if [[ -n "$LS_COLORS" ]]; then
        zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    fi
    
    # 補完方法の設定
    zstyle ':completion:*' completer _complete _match _approximate _ignored
    zstyle ':completion:*:match:*' original only
    zstyle ':completion:*:approximate:*' max-errors 1 numeric
    
    # グループ化
    zstyle ':completion:*:matches' group 'yes'
    zstyle ':completion:*' group-name ''
    
    # 説明の表示
    zstyle ':completion:*:options' description 'yes'
    zstyle ':completion:*:options' auto-description '%d'
    zstyle ':completion:*' verbose yes
    
    # フォーマット設定
    zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
    zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
    zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
    zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
    zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
    
    # その他の詳細設定
    zstyle ':completion:*' list-prompt '%S%M matches%s'
    zstyle ':completion:*' select-prompt '%S%p%s'
    
    # ディレクトリ補完の改善
    zstyle ':completion:*' special-dirs true
    zstyle ':completion:*' list-dirs-first true
    
    # プロセス補完の改善
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
    zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
    
    # SSH/SCP補完の改善
    zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
    zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
    zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
    zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
    
    # 無視パターン
    zstyle ':completion:*:functions' ignored-patterns '_*'
    zstyle ':completion:*:*:cd:*' ignored-patterns '(*/)#lost+found'
    
    # sudoの補完改善
    zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin
    
    # 履歴補完
    zstyle ':completion:*:history-words' stop yes
    zstyle ':completion:*:history-words' remove-all-dups yes
    zstyle ':completion:*:history-words' list false
    zstyle ':completion:*:history-words' menu yes
}

# 初回補完時に詳細設定を読み込むフック
_zsh_completion_initialized=0
_lazy_init_completion() {
    if [[ $_zsh_completion_initialized -eq 0 ]]; then
        _init_detailed_completion_styles
        _zsh_completion_initialized=1
    fi
    # オリジナルの補完関数を呼び出す
    return 0
}

# compinitの後に補完ウィジェットをラップ
zle -C _original_complete complete-word _main_complete
zle -C complete-word complete-word _lazy_init_completion_wrapper

_lazy_init_completion_wrapper() {
    _lazy_init_completion
    # 詳細設定を読み込んだら、元の補完関数を復元
    if [[ $_zsh_completion_initialized -eq 1 ]]; then
        zle -C complete-word complete-word _main_complete
    fi
    # 元の補完を実行
    _main_complete
}

# ============================================================================
# 補完オプション
# ============================================================================
setopt auto_list            # 補完候補を一覧表示
setopt auto_menu            # TABで順に補完候補を切り替える
setopt auto_param_slash     # ディレクトリ名の補完で末尾の/を自動的に付加
setopt mark_dirs            # ファイル名の展開でディレクトリにマッチした場合末尾に/を付加
setopt list_types           # 補完候補一覧でファイルの種別を識別マーク表示
setopt always_to_end        # 補完後、カーソルを末尾へ移動
setopt complete_in_word     # 語の途中でもカーソル位置で補完
setopt glob_complete        # globを展開しないで候補の一覧から補完
setopt hist_expand          # 補完時にヒストリを自動的に展開
setopt list_packed          # 補完候補をコンパクトに表示
setopt list_rows_first      # 補完候補を水平方向に並べる

# ============================================================================
# カスタム補完関数の読み込み
# ============================================================================
# カスタム補完関数がある場合は読み込む
if [[ -d "${HOME}/.zsh/completions" ]]; then
    for comp in "${HOME}/.zsh/completions"/_*; do
        [[ -r "$comp" ]] && source "$comp"
    done
fi