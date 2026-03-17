#!/usr/bin/env zsh
# ============================================================================
# 10-completion.zsh - Zsh補完システムの最小設定
# ============================================================================
# このファイルは信頼性の高いタブ補完を実現するための最小限の設定を提供します。
# 主な機能:
# - 基本的なファイル/ディレクトリ補完
# - 大文字小文字を区別しない補完
# - メニュー形式での補完候補選択

# ============================================================================
# 補完パスの設定
# ============================================================================
# Zsh標準の補完関数パス（最重要）
if [[ -d /usr/share/zsh/${ZSH_VERSION}/functions ]]; then
    fpath=(/usr/share/zsh/${ZSH_VERSION}/functions $fpath)
fi

# Homebrewの補完パス
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
    fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# システムの補完パス
if [[ -d /usr/local/share/zsh/site-functions ]]; then
    fpath=(/usr/local/share/zsh/site-functions $fpath)
fi

# ============================================================================
# 補完システムの初期化（キャッシュ付き）
# ============================================================================
autoload -Uz compinit

# キャッシュを~/.zsh/cache/に集約
[[ -d ~/.zsh/cache ]] || mkdir -p ~/.zsh/cache
local _zcompdump=~/.zsh/cache/zcompdump

# 1日1回だけ完全チェック（compaudit含む）、それ以外はキャッシュから高速読み込み
if [[ -n ${_zcompdump}(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi

# zcompdumpをコンパイルして読み込みを高速化（バックグラウンド実行）
{
  if [[ -s "$_zcompdump" && (! -s "${_zcompdump}.zwc" || "$_zcompdump" -nt "${_zcompdump}.zwc") ]]; then
    zcompile "$_zcompdump"
  fi
} &!

# ============================================================================
# 最小限の補完設定
# ============================================================================
# 基本的な補完動作のみ有効化
setopt auto_list            # 補完候補を一覧表示
setopt auto_menu            # TABで順に補完候補を切り替える
setopt list_packed          # 補完候補をコンパクトに表示
setopt complete_aliases     # エイリアスも補完
setopt list_types          # ファイルタイプを表示

# 補完時の動作設定
setopt always_to_end       # 補完後カーソルを最後に移動
setopt auto_param_slash    # ディレクトリ名の補完で末尾に/を付加

# メニュー補完を使用
zstyle ':completion:*' menu select

# 大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 補完方法の設定
zstyle ':completion:*' completer _complete _match _approximate

# 補完候補をグループ化
zstyle ':completion:*' group-name ''

# 補完時に詳細を表示
zstyle ':completion:*' verbose yes

# ファイルの種類で色分け（lsコマンドの色設定を使用）
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}