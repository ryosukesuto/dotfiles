# ディレクトリ作成と移動を同時に行う
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# ファイル/ディレクトリのサイズを表示
sizeof() {
  if command -v dust &> /dev/null; then
    dust "$@"
  else
    du -sh "$@"
  fi
}

# 圧縮ファイルの展開
extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# ghqとfzf/pecoを使った高速ディレクトリ移動
if command -v fzf &> /dev/null && command -v ghq &> /dev/null; then
  # fzfを使ったバージョン
  function fzf-src() {
    local selected_dir=$(ghq list -p | fzf --query "$LBUFFER" --height 40% --reverse)
    if [[ -n "$selected_dir" ]]; then
      BUFFER="cd ${selected_dir}"
      zle accept-line
    fi
    zle clear-screen
  }
  zle -N fzf-src
  bindkey '^]' fzf-src
elif command -v peco &> /dev/null && command -v ghq &> /dev/null; then
  # pecoを使ったバージョン（元の実装）
  function peco-src() {
    local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
    if [[ -n "$selected_dir" ]]; then
      BUFFER="cd ${selected_dir}"
      zle accept-line
    fi
    zle clear-screen
  }
  zle -N peco-src
  bindkey '^]' peco-src
fi

# Git操作の便利関数
gacp() {
  git add . && git commit -m "$1" && git push
}

# ポート番号で実行中のプロセスを表示
port() {
  lsof -i :"$1"
}

# クリップボードにコピー（macOS）
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias copy='pbcopy'
  alias paste='pbpaste'
fi

# fzfの設定と関数
if command -v fzf &> /dev/null; then
  # fzfのデフォルト設定
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
  
  # ripgrepがあればfzfのデフォルトコマンドに設定
  if command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  fi
  
  # Ctrl+R で履歴検索
  if ! zle -l fzf-history-widget &> /dev/null; then
    source <(fzf --zsh)
  fi
fi