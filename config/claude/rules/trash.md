# ファイル削除はtrashコマンドを使う

## ルール
- ファイルやディレクトリを削除する際は `rm` ではなく `trash` コマンドを使う
- `trash` はmacOS標準の `/usr/bin/trash` で、Finderのゴミ箱に移動する
- ゴミ箱からの復元が可能なため、安全に削除操作を行える

## 使い方
```bash
trash file.txt              # 単一ファイル
trash dir/                  # ディレクトリ
trash file1.txt file2.txt   # 複数ファイル
trash -v file.txt           # verbose（移動先を表示）
```

## 例外
- `.git/` 内の一時ファイルなど、ゴミ箱に残す必要がないものは `rm` でもよい
- CI/CD環境やLinuxなど `trash` が利用できない環境では `rm` を使用
