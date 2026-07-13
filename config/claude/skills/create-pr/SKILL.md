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

ブランチ名から Linear Issue ID（`PF` / `ASICS` / `SRV` などのチーム prefix + 番号）を抽出し、Linear Issueとの紐づけを行う。PRとIssueの関係をPR作成時に確定させることで、後から追跡する手間を省く。

```bash
BRANCH=$(git branch --show-current)
# Linear team prefix は既知のものを正規表現で網羅。新チームが増えたら追記する。
ISSUE_ID=$(echo "$BRANCH" | grep -oiE '(PF|ASICS|SRV)-[0-9]+' | tail -1 | tr 'a-z' 'A-Z')
```

- ブランチは `suto-ryosuke/asics-15229` のように `<assignee>/<issue-id-lowercase>` 形式のため、末尾の `<prefix>-<番号>` を Issue ID として扱う（`tail -1` + 大文字化）
- Issue ID が見つかった場合: `get_issue` でIssue詳細を取得し、タイトルと概要をPR本文に含める
- 見つからない場合: ステップ2の変更内容からIssueタイトル・説明を推定し、`save_issue` で起票する
  - 起票前にユーザーにタイトル・チーム・説明を提示して確認を取る
  - ユーザーが「不要」「スキップ」と回答した場合のみ起票しない
- Issue取得後、Acceptance Criteria（またはdescription内のTODOリスト）を確認し、このPRで全項目を満たすかで `Closes` / `Refs` を判定する（詳細は `reference.md` の「Closes / Refs の判定」）。判断系Issue（成果物がPRでない）の場合はマジックワードを使わない
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

ドラフト生成時の原則:

- 読み手は「このセッションの経緯を知らない他のチームメンバー」。直前の作業プロセスで使った用語（スキル名、評価手法名、プロセスの段階表現、`[critical]` などの内部ラベル）を持ち込まない。検証内容は「何をどう確認したか」の外形的な事実のみ書く
- PRの本質に絞る: 「何を変えたか」と「なぜそうしたか（最終的な設計判断）」だけ書く。それ以外は書かない
- 書かないものリスト:
  - 探索・思考の経緯: 「最初◯◯と仮説を立てたが実は△△だった」「調査の結果分かったのは…」「当初は別アプローチを試した」のような試行錯誤の物語。最終的な事実だけ書けば十分
  - 差分から自明な情報: 変更ファイル名の列挙、追加/削除行数、リネーム/移動の機械的な説明。`git diff` を見れば分かることは書かない
  - CIで自動検証される宣言: `lint pass` / `typecheck pass` / `format済` 等。CIに任せる（テスト「結果」は Test plan の文脈なので別扱い）
  - 冗長な見出し展開: 軽微な変更で「変更の可視化」「影響範囲」セクションを空欄や `N/A` で残さない。該当しないセクションは削る
- 目安としてPR本文は 30-50 行程度に収める。これを超えるときは「経緯」や「自明な情報」が混入していないか見直す

詳しくは Gotchas を参照。

#### 並列タスクC: Codex Review（必須）

PR作成前にCodexによるレビューを実施する。tmux/cmux環境かどうかで実行方法を切り替える。

```bash
PANE_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh
REVIEW_PROMPT="git diffを確認して、以下の観点でレビューしてください:
- P0: セキュリティ脆弱性、データ損失リスク
- P1: パフォーマンス問題、エラーハンドリング不足
- P2: 設計改善、保守性向上"

# tmux/cmux環境かつ pane-manager が起動できる場合はインタラクティブレビュー、
# それ以外（環境外 / pane-manager の lock 取得失敗）は codex exec へフォールバック
if { [ -n "$CMUX_SOCKET_PATH" ] || [ -n "$TMUX" ]; } && $PANE_MGR ensure 2>/dev/null; then
    $PANE_MGR send "$REVIEW_PROMPT"
    $PANE_MGR wait_response 180 && $PANE_MGR capture 200
else
    # pane-manager が使えない場合（lock 取得失敗、既存 surface なし等）も含めて codex exec
    codex exec "$REVIEW_PROMPT"
fi
```

pane-manager がロック取得失敗（`Could not acquire lock` / `既存surfaceも見つからない`）になるケースがある。その場合も Codex review 自体は省略せず、`codex exec` でフォールバックして実施する。

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

1. WinTicket org配下のリポジトリの場合、`gh auth status` でアクティブアカウントが `ryosukesuto`（mediphone作業用の `ryosukesuto-mp` ではない）か確認する
2. Terraformリポジトリの場合は `terraform fmt -recursive` を実行
3. `git add -A && git commit && git push -u origin HEAD`
4. `gh pr create --draft` でdraft PRを作成。bodyの末尾Linearセクションには `Closes` / `Refs` の判定結果を含める（ステップ3参照）。bodyにコードブロック（` ``` `）を含む場合は `--body-file` でファイルから渡す（heredoc内の ``` はBashにエスケープされてレンダリングが壊れるため）。ユーザーが明示的に `--no-draft` や「draftなしで」と指定した場合のみ通常PRにする
5. PR作成後、Linear Issueのステータスを更新（`save_issue`）。GitHub-Linear連携が有効な場合は自動遷移するため任意（draftなら`In Progress`のまま、`In Review`にはしない）
6. 作業報告をデイリーノートに追記
7. worktree内の場合は削除方法を案内
8. CI通過・レビュー準備完了後に `gh pr ready` でReady for reviewにすることをユーザーに案内

詳細なコマンドは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Gotchas

- `git-wt` での worktree 作成が `Operation not permitted` で失敗するリポジトリがある: ops のように `terraform/**/terraform.tfstate` に macOS の特殊権限（読み取り専用 / immutable 等）がついていると、`git reset HEAD` の段階で書き込み失敗してロールバックされる。エラー例: `error: could not write config file .git/config: Operation not permitted` / `unable to stat just-written file terraform/.../terraform.tfstate: Operation not permitted` / `fatal: Could not reset index file to revision 'HEAD'`。この場合は worktree を諦め、現在の作業ツリーで `git checkout -b <branch> origin/main` してメイン作業ツリー上で進める。`git status` で tfstate に対する誤った `D`（削除）が出ても私の変更ではないので、`git add` で対象ファイルだけを明示 stage して取り込む（`git add -A` は絶対に使わない）。push 後は `git checkout main` で戻る。
- PR本文に探索・思考の経緯を書かない: 作業中に「最初の仮説が覆った」「途中で方針転換した」「調査して実は別原因だった」のような遷移があっても、PR本文には最終的な結論だけ書く。レビュー者は最終的な変更を理解したいのであって、書き手の試行錯誤を追体験したいわけではない。経緯はコミット履歴・Linear Issue・Slack スレッドに残せばよく、PR本文に持ち込むと本質的な変更点が薄まる。NGパターンの具体例:
  - 仮説の遷移: 「当初は X が原因と推測したが、調査の結果 Y だった」「最初 A で実装したが B のほうが適切と判明」
  - 試行錯誤: 「N 案を検討し最終的に M 案を採用」「最初のアプローチでは ◯◯ が動かず、◯◯ に変更」
  - 反省・後付け: 「振り返ると最初から ◯◯ すべきだった」「想定より影響範囲が広かった」
  - 代替表現: 経緯は省き、最終的な変更内容と「なぜそうしたか（採用した設計判断の理由）」だけを書く。設計判断の理由が複数選択肢の比較を必要とするときのみ「代替案 X は ◯◯ のため採用せず」のような形で1行触れる
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
