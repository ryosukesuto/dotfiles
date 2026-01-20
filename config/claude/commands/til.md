---
description: Today I Learned - セッションから知識・発見を抽出してObsidianデイリーノートに記録
---

# /til - 知識の記録

現在のClaude Codeセッションから得られた知識・発見をObsidianデイリーノートに記録します。

## 記録対象

- 技術的な学び（ツール、ライブラリ、言語の挙動）
- サービス固有の仕様（WinTicket、IRISなどの構成・設定）
- ドメイン知識（環境構成、サービス間の依存関係、命名規則）
- 設定値・パラメータの意味（なぜその値か、デフォルトは何か）
- トラブルシューティングの記録（原因と解決策）
- 「こうなっている」という事実の発見

## 使い方

- `/til` - セッション全体から知識を抽出
- `/til [トピック]` - 特定のトピックに絞って抽出（例: `/til Fastlyのactivate設定`）

## 処理フロー

### 1. 知識の抽出

現在のセッションの会話を分析し、記録すべき知識を特定。以下のような構造で整理：

- 事象/背景: 何を調べたか、どんな状況だったか
- 調査/確認: どのように調べたか（省略可）
- 発見/仕様: 何がわかったか、どういう仕様か
- ポイント: 覚えておくべきこと、今後に活かせること

### 2. Obsidian最適化

以下の形式で整形：

- 見出し: `## 💡 タイトル: サブタイトル`
- タグ: `#til/カテゴリ` 形式で複数付与可能
  - 技術系: `#til/fastly`, `#til/terraform`, `#til/tmux`, `#til/aws`, `#til/gcp`
  - サービス系: `#til/winticket`, `#til/iris`, `#til/youtrust`
  - ツール系: `#til/claude-code`, `#til/codex`, `#til/obsidian`
- 内部リンク: 技術名、ツール名、サービス名を `[[リンク]]` 形式に
- 表やコードブロック: 必要に応じて使用

### 3. ファイル書き込み

保存先: `~/gh/github.com/ryosukesuto/obsidian-notes/01_Daily/YYYY-MM-DD.md`

- ファイルが存在しない場合: `# YYYY-MM-DD` ヘッダーを作成してから追記
- ファイルが存在する場合: ファイル末尾に `---` 区切りで追記

## 出力形式テンプレート

内容に応じて柔軟に構成を調整。以下は一例：

```markdown
## 💡 WinTicket: Fastlyのactivate設定
#til/winticket #til/fastly #til/terraform

### 背景
stg.winticket.bet にアクセスすると「unknown domain」エラーが発生

### 調査
1. [[Terraform]]の設定ファイルを確認
2. 動作している api-stg.winticket.bet と比較

### 仕様・発見
| サービス | activate設定 | 状態 |
|----------|-------------|------|
| api-stg.winticket.bet | `true` | 動作 |
| stg.winticket.bet | 未設定（デフォルト`false`） | 停止 |

- [[Fastly]]の `activate` 変数はデフォルト `false`
- `false` の場合、サービスはドラフト状態でトラフィックを処理しない

### ポイント
- 新規Fastlyサービス作成時は `activate = true` を明示的に設定
- 「unknown domain」エラーはDNSではなくFastly側の設定が原因の場合がある
```

## 実行指示

1. 現在のセッションを分析し、記録すべき知識・発見を特定
2. 引数でトピックが指定されていれば、そのトピックに関連する内容に絞る
3. 上記テンプレートを参考に、内容に応じた構成で整形（セクションは柔軟に調整可）
4. 今日の日付を取得（`date "+%Y-%m-%d"`）
5. デイリーノートのパスを構築
6. ファイルの存在を確認し、適切に書き込み：

```bash
DAILY_DIR="$HOME/gh/github.com/ryosukesuto/obsidian-notes/01_Daily"
DAILY_NOTE="$DAILY_DIR/$(date '+%Y-%m-%d').md"

# ディレクトリ存在確認（なければ作成）
if [ ! -d "$DAILY_DIR" ]; then
    mkdir -p "$DAILY_DIR" || {
        echo "エラー: ディレクトリを作成できません: $DAILY_DIR"
        exit 1
    }
fi

# ファイルが存在しない場合はヘッダーを作成（新規作成フラグ）
NEW_FILE=false
if [ ! -f "$DAILY_NOTE" ]; then
    echo "# $(date '+%Y-%m-%d')" > "$DAILY_NOTE"
    echo "" >> "$DAILY_NOTE"
    NEW_FILE=true
fi

# 既存ファイルの場合のみ区切り線を追加（新規作成時は不要）
if [ "$NEW_FILE" = false ]; then
    echo "" >> "$DAILY_NOTE"
    echo "---" >> "$DAILY_NOTE"
    echo "" >> "$DAILY_NOTE"
fi
```

7. 知識の内容をファイルに追記
8. 完了メッセージを表示（ファイルパスとタイトル）

### エラー時の対応

- ディレクトリ作成失敗: 「エラー: ディレクトリを作成できません: [パス]」と報告
- ファイル書き込み失敗: 「エラー: ファイルに書き込めません: [パス]」と報告

## 注意事項

- 記録すべき内容がない場合は「このセッションから記録すべき知識・発見が見つかりませんでした」と報告
- タグは `#til/カテゴリ` 形式。新しいカテゴリが必要な場合は追加可
- 内部リンク `[[]]` は技術名、ツール名、サービス名に適用
- セクション構成は内容に応じて柔軟に調整（背景/調査/発見/ポイント は必須ではない）
- 事実の記録を重視。「こうすべき」より「こうなっている」を優先
