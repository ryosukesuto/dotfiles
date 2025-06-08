# 基本設定
export CLICOLOR=1

# Emacsキーバインド
bindkey -e

# ビープ音を無効化
setopt no_beep

# 補完設定（最適化版）
autoload -Uz compinit
# 24時間以内にcompdumpが更新されていない場合のみフルチェック
for dump in ~/.zcompdump(N.mh+24); do
  compinit
  break
done
[[ $#dump -eq 0 ]] && compinit -C

# Homebrewの補完
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# 補完スタイル設定
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# より便利なzshオプション
setopt auto_cd              # ディレクトリ名だけでcd
setopt auto_pushd           # cdで自動的にpushd
setopt pushd_ignore_dups    # pushdで重複を無視
setopt correct              # コマンドのスペルチェック
setopt interactive_comments # コマンドラインでもコメント可能
setopt extended_glob        # 拡張グロブ機能
setopt list_packed