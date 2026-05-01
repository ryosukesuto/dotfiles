---
name: codex-review
description: tmux/cmuxで右半分にCodexを開いてコードレビューを実行。「レビューして」「Codexでレビュー」「Codexに聞いて」「セカンドオピニオン」等の発言で起動。
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# codex-review

tmux/cmuxで右半分にCodexを開いて、インタラクティブにレビューやセカンドオピニオンを取得するSkill。

## 役割分担

- Codex: 考える、調べる、評価する（調査・分析・レビュー）
- Claude Code: 実装する、修正する、実行する（コード変更・コマンド実行）

## 機能

- tmux/cmuxで右半分にCodexペインを作成・管理
- Codexにメッセージを送信し、返答をキャプチャ
- Claude Codeは左ペインで作業を継続しながらCodexと対話

## バックエンド自動検出

| 環境変数 | バックエンド | 備考 |
|----------|-------------|------|
| `$CMUX_SOCKET_PATH` | cmux | cmuxターミナル内で自動設定 |
| `$TMUX` | tmux | tmuxセッション内で自動設定 |
| どちらもなし | エラー | tmuxまたはcmux内で実行が必要 |

## pane-manager.sh コマンド

スクリプトパス: `${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh`

| コマンド | 説明 |
|----------|------|
| `ensure` | Codexペインを作成（既存なら再利用） |
| `send "msg"` | Codexにメッセージを送信（Enter自動送信） |
| `send -` | stdinからメッセージを読み取って送信 |
| `wait_response [s]` | 応答完了を待機（デフォルト120秒） |
| `capture [n]` | 出力をキャプチャ（デフォルト100行） |
| `status` | ペインの状態とバックエンドを確認 |

## 前提条件

- tmuxセッション内またはcmuxターミナル内で実行すること
- `codex`コマンドがインストールされていること（`npm install -g @openai/codex`）
- cmux使用時はソケットAPI（`nc -U`）で直接通信するため、cmux CLIは不要

## 実行手順

### ステップ1: Codexペインを作成

```bash
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh ensure
```

出力例（tmux）:
```
Created new Codex pane: %6 (title=codex-review, bg=colour233)
Auto-started Codex in pane
```

出力例（cmux）:
```
Created new Codex surface: D409399D-EF29-469D-8177-8DFB33F5735A (backend=cmux-socket)
Auto-started Codex in surface
```

### ステップ2: レビュー依頼を送信

git diffの内容をレビューしてもらう場合:

```bash
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh send "git diffを確認して、セキュリティやパフォーマンスの問題があれば教えてください。"
```

または具体的な質問:

```bash
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh send "このリポジトリのアーキテクチャについてセカンドオピニオンをください。"
```

### ステップ3: 返答を待機してキャプチャ

`wait_response`で応答完了を待機してからキャプチャ:

```bash
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh wait_response && \
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh capture 200
```

または従来のsleep方式:

```bash
sleep 30 && ${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh capture 100
```

### ステップ4: 結果の報告

キャプチャした内容からCodexの返答を抽出し、ユーザーに報告。

## 判断ガイド

### 環境検知

最初に `pane-manager.sh status` を叩くのが最も正確（バックエンドを自動判定し、tmux/cmux 外なら即エラーで返る）。`echo $TMUX` は tmux は見れるが cmux は判定できないため非推奨。

tmux/cmux 外と判明した場合:
- 代替案A: 別ターミナルで `tmux new -s review` を起動し、その中で Claude Code を再起動（環境変数 `$TMUX` はシェル起動時に継承されるため、Claude Code の再起動が必須）
- 代替案B: cmux ターミナルに切り替える
- 代替案C: skill を使わず、このセッション内で Claude 自身がセカンドオピニオンを返す

### diff の範囲

「現在ブランチのレビュー」と依頼された場合の既定:

```bash
git diff origin/main...HEAD
```

`...`（三点）を使うと merge-base からの差分になり、`origin/main` の進行に影響されない。デフォルトブランチが `main` 以外（`master` / `develop` 等）の場合は置換する。

stage 済み変更のみレビューしたい旨が明示された場合のみ `git diff --staged`。

### 送信パターン

短文・単一行 → `send "msg"`。
複数行・特殊文字・diff 等の長文 → `send -` + heredoc。

```bash
{
  cat <<'EOF'
<プロンプト本文>

diff:
EOF
  git diff origin/main...HEAD
} | ${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh send -
```

heredoc 引用符は `'EOF'` にすること（バッククォートや `$` の展開を防ぐ）。

### wait_response のタイムアウト目安

デフォルトは 120 秒。diff 規模 + 依頼の性質に応じて調整:

| 依頼の性質 | 推奨タイムアウト | キャプチャ行数 |
|---|---|---|
| diff 100 行未満、コードのみ確認 | 60 秒 | 100 |
| diff 100-500 行、コードのみ確認 | 120 秒（デフォルト） | 100-200 |
| diff 500 行超、コードのみ確認 | 300 秒 | 200-300 |
| **公式ドキュメント / 仕様調査を伴う** (Web 検索、cross-repo 探索が想定される) | **300-600 秒** | **300-500** |
| アーキテクチャレビュー (大規模) / 複数ファイル横断 | 300-600 秒 | 300-500 |

公式仕様の確認や別リポ参照を依頼に明示している場合、Codex は Web 検索を多用して 3-5 分かかることがある。最初から `wait_response 600` で叩く方が再叩きのコストを節約できる。

指定方法: `pane-manager.sh wait_response 300`。タイムアウト後に capture した結果がまだ応答中（末尾に `esc to interrupt` が残る）なら、`wait_response` を追加で叩くか、ユーザーに「続行 or 途中出力共有」を選択してもらう。

### 応答抽出

`capture` の生出力には送信メッセージと Codex の応答が混在する。切り出し規約:

- Codex の応答行: `›` プロンプト直前までが最新応答
- ユーザー送信行: `> ` で始まる行（または直前に送ったメッセージ本文）
- 「esc to interrupt」が末尾にあれば応答生成中

抽出した応答はそのまま貼らず、P0/P1 を冒頭に配置して要約する。キャプチャ行数は通常 100 行で足りるが、長文レビュー時は `capture 300` まで増やす。

### Codex 指摘の裏取り（採用前に必須）

Codex が出す P0 / P1 の技術的主張は、ユーザーへ報告する前に **Claude Code 側で verify する**。Codex skill 側でも `code-review` skill が「未確認の主張を断定しない」と禁止しているが、稀に推測ベースの主張が混じる。Claude Code 側でも二重防御する。

verify 対象の例:

- 「`X モジュールは template を ignore_changes している`」 → `Read` で当該 `.tf` を開いて確認
- 「`API Y は廃止されている`」 → 公式ドキュメントを `WebFetch` で確認、または cli の `--help` で確認
- 「`設定 Z はサポートされていない`」 → provider doc / リポジトリ内の使用例を Grep で確認
- 「`PF-NNNN との重複がある`」 → Linear MCP で当該 Issue の状態を確認

verify した内容と Codex 指摘が一致 → そのまま採用。乖離があれば「Codex は X と主張したが、ファイルでは Y だった」と注記してユーザー報告に含める。verify 不能（情報不足、検証コスト過大）なら、ユーザーへの報告で「未検証」フラグを付け、優先度は最大 P1 まで下げて出す。

裏取りに使う追加ツールが必要なら、本 skill の `allowed-tools` ではなく親セッションの権限で使う（`Read` / `Grep` / `WebFetch` / `mcp__linear-server__get_issue` 等）。本 skill は Codex pane 操作だけ持てば十分。

## 出力形式

```
Codexにメッセージを送信しました。右側のペインでCodexが応答しているのが見えるはずです。

少し待ってから、Codexの返答をキャプチャしましょう。

---
Codexの返答:
[キャプチャした内容]
---
```

## レビュー用プロンプト例

Codex 側に `~/.agents/skills/code-review` skill が配置されている。出力形式・優先度ラベル・打消し禁止・探索ログ非表示などのフォーマット規則は skill 側に集約済みなので、Claude Code から送るプロンプトでは「依頼内容」と「文脈」だけ渡せば良い。skill が description マッチで自動発火する。

うまく発火しない場合（特殊な依頼で description が引っかからない時）はプロンプト末尾に `code-review skill の出力形式に従ってください。` の 1 文を足す。

### コードレビュー
```
git diff を確認してレビューしてください。

文脈:
- 対象リポ: <repo 名>
- 何をする変更か: <1-2 文>
- 特に見てほしい点: <あれば>

diff:
<diff 本体>
```

### アーキテクチャレビュー
```
このリポジトリの構造を確認して、設計上の懸念点をレビューしてください。

文脈:
- リポの目的: <1-2 文>
- 気になっている観点: <あれば>
```

### セカンドオピニオン
```
[具体的な質問や相談内容] についてレビューしてください。
- 自分の現案: <概要>
- 不安な点: <列挙>
```

### 観点を絞ったレビュー
```
git diff のうち、認可と入力検証の観点だけに絞ってレビューしてください。
（diff 続く）
```

> Codex skill が発火しなかった旧運用のプロンプト（観点列挙、フォーマット指示込み）は冗長になるので使わない。skill の description が一致しない依頼形式に気付いたら、skill 側 (`~/.agents/skills/code-review/SKILL.md`) の description を拡張する方を選ぶ。

## 注意事項

- tmuxセッション外かつcmux外では動作しません
- Codexの応答には数秒〜数十秒かかる場合があります
- `wait_response`は「esc to interrupt」の消失と「›」プロンプトの出現で完了を検知します
- Codexペインは開いたまま維持されます

## Gotchas

(運用しながら追記)
