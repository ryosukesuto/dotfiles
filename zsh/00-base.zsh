c# 基本設定
export CLICOLOR=1

# Emacsキーバインド
bindkey -e

# ビープ音を無効化
setopt no_beep

# Homebrewの補完パスを先に設定
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# システムの補完ディレクトリも追加
if [[ -d /usr/local/share/zsh/site-functions ]]; then
  fpath=(/usr/local/share/zsh/site-functions $fpath)
fi

# 重複パスを削除
typeset -U fpath

# 補完設定（最適化版）
autoload -Uz compinit
# 24時間以内にcompdumpが更新されていない場合のみフルチェック
for dump in ~/.zcompdump(N.mh+24); do
  compinit
  break
done
[[ $#dump -eq 0 ]] && compinit -C

# 補完スタイル設定
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# ファイル名・ディレクトリ名補完を有効化
zstyle ':completion:*' completer _complete _ignored _files
zstyle ':completion:*:*:*:*:*' menu yes select
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# エイリアスの補完設定
# setopt COMPLETE_ALIASES  # エイリアス自体を補完するため通常は無効

# より便利なzshオプション
setopt auto_cd              # ディレクトリ名だけでcd
setopt auto_pushd           # cdで自動的にpushd
setopt pushd_ignore_dups    # pushdで重複を無視
setopt correct              # コマンドのスペルチェック
setopt interactive_comments # コマンドラインでもコメント可能
setopt extended_glob        # 拡張グロブ機能
setopt list_packed          # 補完候補をコンパクトに表示
setopt auto_menu            # TAB で順に補完候補を切り替える
setopt auto_param_slash     # ディレクトリ名の補完で末尾の / を自動的に付加
setopt mark_dirs            # ファイル名の展開でディレクトリにマッチした場合末尾に / を付加
setopt list_types           # 補完候補一覧でファイルの種別を識別マーク表示
setopt always_to_end        # 補完後、カーソルを末尾へ移動
setopt complete_in_word     # 語の途中でもカーソル位置で補完
setopt glob_complete        # globを展開しないで候補の一覧から補完