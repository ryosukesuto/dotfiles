# 履歴設定
export HISTFILE="${HOME}/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=50000

# 履歴ファイルのパーミッション設定
if [[ ! -f "$HISTFILE" ]]; then
  touch "$HISTFILE"
  chmod 600 "$HISTFILE"
fi

# 履歴の重複と空行を除外
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

# 履歴をセッション間で共有
setopt share_history

# より詳細な履歴オプション
setopt extended_history      # 実行時間も記録
setopt hist_expire_dups_first # 履歴が満杯になったら重複を先に削除
setopt hist_find_no_dups     # 履歴検索で重複を表示しない
setopt hist_verify          # 履歴展開後に実行前確認