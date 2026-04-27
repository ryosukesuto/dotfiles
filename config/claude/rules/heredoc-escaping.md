# クォート付き heredoc ではバッククォート / $ をエスケープしない

`gh pr create --body "$(cat <<'EOF' ... EOF)"` や `git commit -m "$(cat <<"EOF" ... EOF)"` のように delimiter をクォートしたヒアドキュメント (`<<'EOF'` / `<<"EOF"`) では、シェル変数展開もコマンド置換も走らない。バッククォートや `$` を `\` でエスケープすると、バックスラッシュが literal として残り、PR body / commit message の markdown が壊れる。

## 失敗例

```sh
gh pr create --body "$(cat <<'EOF'
\`\`\`
192 markdown
\`\`\`
EOF
)"
```

→ 投稿された PR body には `\`\`\`` が literal として残り、コードブロックが描画されない。

## 正しい書き方

```sh
gh pr create --body "$(cat <<'EOF'
```
192 markdown
```
EOF
)"
```

## 判断基準

| delimiter | シェル展開 | バッククォート / `$` |
|-----------|------------|---------------------|
| `<<EOF`   | 走る       | エスケープが必要     |
| `<<'EOF'` | 走らない   | そのまま literal で書く（エスケープ禁止） |
| `<<"EOF"` | 走らない   | 同上                |

## 適用範囲

- `gh pr create` / `gh pr edit` / `gh issue create` の `--body` を heredoc 経由で渡すとき
- `git commit -m` で複数行メッセージを heredoc で組み立てるとき
- 一般的に「heredoc → 単一文字列 → コマンド引数」の経路を取るすべての箇所
