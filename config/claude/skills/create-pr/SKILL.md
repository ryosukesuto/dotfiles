---
name: create-pr
description: git diffを分析して包括的なPull Requestを自動作成。「PR作って」「PR作成」「PRお願い」「プルリク」等で起動。
argument-hint: "[title] [--draft]"
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(git-wt:*)
  - Bash(gh:*)
  - Bash(~/.claude/skills/codex-review/scripts/pane-manager.sh:*)
  - Bash(codex:*)
  - Read
  - Glob
  - Grep
  - mcp__linear-server__get_issue
  - mcp__linear-server__save_issue
  - AskUserQuestion
---

# /create-pr - スマートPR作成コマンド

git diffを分析して、Mermaid図やテスト結果を含む包括的なPull Requestを自動作成します。

## 実行手順

### 0. リファレンス読み込み（必要時のみ）

- `${CLAUDE_SKILL_DIR}/reference.md` — PR本文テンプレート、worktree環境での動作、注意事項

### 1. ブランチ状態の確認と worktree 作成

```bash
CURRENT_BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)

# デフォルトブランチで作業中の場合は worktree を作成
if [[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
    echo "デフォルトブランチで作業中です。worktree を作成します。"
    # ユーザーにブランチ名を確認
    # git wt <branch-name> で worktree を作成して移動
fi
```

### 2. 変更内容の分析

```bash
git status
git diff --cached
git diff
git log --oneline -10
git branch --show-current
```

### 3. Linear Issue紐づけ

ブランチ名から `PF-XXXX` パターンを抽出し、Linear Issueとの紐づけを行う。PRとIssueの関係をPR作成時に確定させることで、後から追跡する手間を省く。

```bash
BRANCH=$(git branch --show-current)
ISSUE_ID=$(echo "$BRANCH" | grep -oE 'PF-[0-9]+' | head -1)
```

- `PF-XXXX` が見つかった場合: `get_issue` でIssue詳細を取得し、タイトルと概要をPR本文に含める
- 見つからない場合: ステップ2の変更内容からIssueタイトル・説明を推定し、`save_issue` で起票する
  - 起票前にユーザーにタイトル・チーム・説明を提示して確認を取る
  - ユーザーが「不要」「スキップ」と回答した場合のみ起票しない
- Issue情報はステップ5のPR本文生成で使用する

### 4. 変更タイプの自動判定

- 変更規模: 追加/削除行数、ファイル数
- 変更タイプ: feat/fix/refactor/docs/test/chore
- 影響範囲: 変更ファイルの依存関係
- Breaking Change: API変更、設定変更、削除されたメソッド

### 5. Mermaid図の生成（必要に応じて）

アーキテクチャ変更、APIエンドポイント変更、状態管理変更が検出された場合に図を生成。

### 6-8. テスト・PR本文生成・Codexレビュー（並列実行）

以下の3つは依存関係がないため、Subagentで並列実行する。

#### 並列タスクA: テストとチェックの実行
プロジェクトタイプに応じたテストコマンドを検出して実行。結果を返す。

#### 並列タスクB: PR本文のドラフト生成
ステップ2-5の分析結果とLinear Issue情報をもとにPR本文をドラフト生成する（テスト結果の欄は後で埋める）。

`${CLAUDE_SKILL_DIR}/reference.md` のPR本文テンプレートに従う。

ドラフト生成時の原則: PR本文の読み手は「このセッションの経緯を知らない他のチームメンバー」。直前の作業プロセスで使った用語（スキル名、評価手法名、プロセスの段階表現、`[critical]` などの内部ラベル）を持ち込まない。検証内容は「何をどう確認したか」の外形的な事実のみ書く。詳しくは Gotchas を参照。

#### 並列タスクC: Codex Review（必須）

PR作成前にCodexによるレビューを実施する。tmux/cmux環境かどうかで実行方法を切り替える。

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh

# tmux/cmux環境の判定
if [ -n "$CMUX_SOCKET_PATH" ] || [ -n "$TMUX" ]; then
    # pane-manager経由でインタラクティブレビュー
    $PANE_MGR ensure
    $PANE_MGR send "git diffを確認して、以下の観点でレビューしてください:
- P0: セキュリティ脆弱性、データ損失リスク
- P1: パフォーマンス問題、エラーハンドリング不足
- P2: 設計改善、保守性向上"
    $PANE_MGR wait_response 180 && $PANE_MGR capture 200
else
    # codex exec で単発レビュー
    codex exec "git diffを確認して、以下の観点でレビューしてください:
- P0: セキュリティ脆弱性、データ損失リスク
- P1: パフォーマンス問題、エラーハンドリング不足
- P2: 設計改善、保守性向上"
fi
```

#### 並列タスク完了後の統合

1. テスト結果をPR本文に埋め込む
2. PR本文を `/proofread` で校正（文体パターン・スペース・体言止め等）
3. Codexレビュー結果をユーザーに報告:
   - P0/P1の指摘がある場合: 修正してから次のステップへ進む
   - P2以下のみ: ユーザーに報告し、対応要否を確認してから次のステップへ進む
   - 指摘なし: そのまま次のステップへ進む

### 9. デフォルトブランチの最新化とリベース

PR作成前にデフォルトブランチの最新を取り込み、コンフリクトを事前に解消する。

```bash
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
git fetch origin "$DEFAULT_BRANCH"
git rebase "origin/$DEFAULT_BRANCH"
```

- リベースでコンフリクトが発生した場合は解消してから続行する
- コンフリクトの内容をユーザーに報告し、対応方針を確認する

### 10. PRの作成

1. Terraformリポジトリの場合は `terraform fmt -recursive` を実行
2. `git add -A && git commit && git push -u origin HEAD`
3. `gh pr create --draft` でdraft PRを作成（Linear Issueリンクを含むbodyを使用）。bodyにコードブロック（` ``` `）を含む場合は `--body-file` でファイルから渡す（heredoc内の ``` はBashにエスケープされてレンダリングが壊れるため）。ユーザーが明示的に `--no-draft` や「draftなしで」と指定した場合のみ通常PRにする
4. PR作成後、Linear Issueのステータスを `In Review` に更新（`save_issue`）
5. 作業報告をデイリーノートに追記
6. worktree内の場合は削除方法を案内
7. CI通過・レビュー準備完了後に `gh pr ready` でReady for reviewにすることをユーザーに案内

詳細なコマンドは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Gotchas

- PR本文に内部プロセス用語を書かない: レビュー者（このセッションの経緯を知らない他メンバー）に通じない用語を持ち込まない。NGパターンの具体例:
  - レビュープロセス詳細: `Codex レビュー: P0/P1 対応後 OK 判定` 等
  - 実装者の作業状態: `stash 済`、`既に退避済` 等
  - 内部検討の名前: `段階2`、`案X`、`Phase 1 POC 完了済` 等
  - プロンプト評価プロセスの用語: `empirical-prompt-tuning`、`[critical] 項目全クリア`、`hold-out シナリオ`、`精度 100%` 等（スキル改善時の評価ログをそのまま貼ると起きやすい）
  - 判断の合言葉: `裁量補完`、`収束判定` 等の内部語彙
  - 代替表現: 「3パターンで意図通りの判定結果を確認」「テスト pass」のような外形的な事実だけを書く。Codex 指摘・評価プロセスの詳細はユーザーへの報告にとどめる
- PR本文で `#NNN` をそのまま書くと別の Issue/PR にリンクされてしまう。Dependabot alert 番号など GitHub 外のIDを書く場合はフル URL リンクにする
- レビューコメント（Greptile 等）に対応して push した後は、該当スレッドを resolve する。GitHub の suggestion を適用した場合は自動 resolve されるが、手動で修正した場合は GraphQL API `resolveReviewThread` で明示的に resolve する

```bash
# 未解決のレビュースレッドを取得
gh api graphql -f query='query {
  repository(owner: "WinTicket", name: "server") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 50) {
        nodes { id isResolved comments(first: 1) { nodes { body author { login } } } }
      }
    }
  }
}'

# スレッドを resolve
gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
```
