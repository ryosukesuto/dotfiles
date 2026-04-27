---
name: linear-triage
description: 週次レビュー。PR-Issue紐づけ、プロジェクトUpdate更新、優先度整理、Cycle修正、月初は CI レビュー未適用リポの起票。「トリアージ」「Linear Update」「週次レビュー」「weekly review」「月次レビュー」等で起動。
user-invocable: true
allowed-tools:
  - Bash(gh:*)
  - Bash(~/gh/github.com/ryosukesuto/dotfiles/bin/claude-review-coverage*)
  - Bash(claude-review-coverage*)
  - Bash(jq:*)
  - mcp__linear-server__list_issues
  - mcp__linear-server__list_cycles
  - mcp__linear-server__list_projects
  - mcp__linear-server__get_issue
  - mcp__linear-server__get_status_updates
  - mcp__linear-server__save_issue
  - mcp__linear-server__save_comment
  - mcp__linear-server__save_status_update
  - AskUserQuestion
---

# /linear-triage - Weekly Review

## 目的

直近1週間の作業を棚卸しし、Linearの状態を最新化する。PR-Issue紐づけ → プロジェクトUpdate → 優先度整理 → Cycle修正の順で実行。

## フロー概要

```
Phase 1: PR-Issue紐づけチェック
Phase 2: プロジェクト横断タスク取得
Phase 3: プロジェクトUpdates更新
Phase 4: プロジェクト外Issueの整理
Phase 5: Current Cycle修正 + 進捗なしプロジェクトの起動Issue投入
Phase 6: デイリーノート更新（任意）
Phase 7: 月次タスク（月次レビュー時のみ）
```

### 起動時の月次判定

skill 起動直後、AskUserQuestion で「今回は月次レビューですか？」を必ず確認する。yes なら Phase 7 まで実行、no なら Phase 6 で終了。

判定の目安: 当月初の linear-triage 実行であれば yes、それ以外は no。ユーザー発話に「月次」「monthly」「月初」が含まれていれば自動的に yes 扱い。

## Phase 1: PR-Issue紐づけチェック

PRとIssueの乖離を放置すると、進捗が見えなくなり週次報告の精度が下がる。早期に紐づけを揃える。

### 前提

Linear の GitHub 連携が org で有効化されている前提。ブランチ名・PR タイトルに `PF-XXXX` を含めれば自動でリンクされ、`Closes PF-XXXX` 等の magic word でマージ時自動 Done になる。詳細は `~/.claude/rules/linear-branch-naming.md`。

このskillは「自動リンクが効かなかった PR」だけを補修する役割。手動追記は最後の手段。

### 手順

1. 直近1週間の自分のPRを `gh search prs --author=@me --created=">=YYYY-MM-DD"` で取得（複数リポ横断、`--state=all` は不可、`headRefName` field 不可）
2. 各PRから `PF-XXXX` パターンを抽出（タイトル、body）。ブランチ名は別途 `gh pr view <num> -R <repo> --json headRefName` で1件ずつ取得可能
3. 候補となる Issue ID については `mcp__linear-server__get_issue(id, attachments)` で attachments を取得し、対象 PR が既に Linear に紐づいているか確認
4. 分類:
   - **自動リンク済み**: タイトル/ブランチ/body に ID あり、かつ Linear の attachments に PR が含まれる → 何もしない
   - **要追記**: ID は推定できるが Linear の attachments に PR がない → PR description 追記候補
   - **未紐づけ**: ID 推定不可 → ユーザー確認（新規Issue起票 / 既存Issue指定 / スキップ）
5. マージ済みPRでIssueがDone/Cancelledでないものを報告（`Closes` magic word が抜けていた可能性）
6. 「要追記」分のみ PR description に Linear リンク+ magic word を追記

### PR description 追記の対象判断（デフォルト）

「全PRに追記」と指示された場合でも、以下のデフォルトを採用してユーザーに確認する：

- 個人org（例: `ryosukesuto/*`）のリポは Linear と紐づかないため除外
- WinTicket org の PR でも、対応 Issue がタイトル/ブランチ名で一意にマッチするものだけを追記対象とする
- ハーネス整備系のサブタスク（PF-1830 系等）は親 Issue のタイトルとPRタイトルが対応していることが多い、そこから推定する
- 推定が曖昧なものはスキップしてユーザー確認に回す
- 追記する場合は単なるリンクではなく `Closes PF-XXXX` 形式の magic word も入れる（`reference.md` のフォーマット参照）

詳細な手順・出力フォーマット・PR description追記フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 2: プロジェクト横断タスク取得

全プロジェクトの状況を一覧化することで、Phase 3以降の判断材料を揃える。

### 手順

1. `mcp__linear-server__list_projects(member: "me", state: "started")` で参加プロジェクトを取得
2. 各プロジェクトのIssueを `mcp__linear-server__list_issues(assignee: "me", project: <projectId>)` で取得
3. `mcp__linear-server__list_issues(assignee: "me", limit: 100)` でプロジェクト外Issueも取得（プロジェクト付きIssueのIDを除外）
4. MCP応答から必要フィールドだけ抽出し、プロジェクト別・ステータス別のサマリを表示（生JSONをそのまま出力しない）

出力フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 3: プロジェクトUpdates更新

Updateが古いとステークホルダーに誤った状況認識を与える。最新のタスク状況との差分を埋める。

### 手順

1. 各プロジェクトの直近Updateを `get_status_updates(type: "project", project: <id>, limit: 1)` で取得
2. Phase 2のタスク状況と比較し、差分を分析
3. Update案（変化点・health判定・下書き）をユーザーに提示
4. 承認後、`save_status_update` で保存

Updateフォーマット / healthの判断基準 / 優先度の絵文字マッピング / Issueリンクのルールは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 4: プロジェクト外Issueの整理

プロジェクトに属さないIssueは棚卸しから漏れやすい。放置を防ぐために1件ずつ確認する。

Phase 2で抽出した「プロジェクト外Issue」を1件ずつ提示し、ユーザーに対応を確認する。
対応: 優先度変更 / コメント追加 / プロジェクトに追加 / 現状維持。
変更は `save_issue` / `save_comment` で即座に反映。作成から30日以上ステータス未変更のIssueは特に注意を促す。

提示フォーマットは `${CLAUDE_SKILL_DIR}/reference.md` を参照。

## Phase 5: Current Cycle修正 + 進捗なしプロジェクトの起動

優先度の変動を反映しないとCycleが実態と乖離する。ここまでの判断をCycleに落とし込み、さらに進捗が止まっているプロジェクトの起動Issueも次Cycleに投入する。

### 5-1. Current Cycle の整理

1. `mcp__linear-server__list_cycles(teamId: TEAM_ID, type: "current")` でCycle取得
2. `mcp__linear-server__list_issues(team: TEAM_ID, cycle: <cycleId>, limit: 100)` でCycle内タスクを取得し、自分のタスクだけ抽出
3. MCP応答から必要フィールドだけ抽出して修正案を提示（生JSONをそのまま出力しない）:
   - Urgent/HighだがCycleに未追加 → 追加候補
   - Low/NoneでCycleに存在 → 除外候補
   - 完了済みだがCycleに残存 → ステータス確認
   - ポイント合計超過 → 調整提案
   - 30日以上status未変更のTodoがCycleに残存 → 次Cycleへ移動 or 棚卸し
4. 承認後、`save_issue` でCycle割り当てを変更

### 5-2. 進捗なしプロジェクトの起動Issue投入

Phase 3 で Update を保存しなかった = 今週進捗がなかった active プロジェクトを対象に、次Cycle (`type: "next"` で取得) に投入する起動Issueを提案する。

1. `list_cycles(teamId: TEAM_ID, type: "next")` で次Cycleを取得
2. 進捗なしプロジェクト配下で自分assigned・Cycle未割当・statusType in (`backlog`,`unstarted`) のIssueを抽出
3. 軽量Issue（estimate ≤ 3pt または 設計・調整・調査タスク）を起動候補として優先提示
4. プロジェクト単位で「次Cycleに入れる/見送る」をユーザーに確認（選択肢が4を超える場合は質問を分割）
5. 承認分を `save_issue(id, cycle: <nextCycleId>)` で投入
6. 投入後の合計ポイントを表示し、過剰なら絞り込みを再提案

### 注意

- 過剰投入を避けるため、繰越In Progress + Cycle投入分の合計が「直近Cycleで完了したポイント」を大きく超えないように調整
- 重いPoC・実装系（5pt 以上）は単独で1サイクルを占める想定で扱う
- ユーザーから「進捗ないプロジェクトをCycleに入れたい」「次Cycleで何やるか決めたい」等の発話があった場合、5-2 を必ず実施

## Phase 6: デイリーノート更新（任意）

Obsidianのデイリーノートが存在する場合、レビュー結果を反映する。ノートがない場合はスキップ。

## Phase 7: 月次タスク（月次レビュー時のみ）

月次レビュー判定が yes の場合のみ実行。CI レビュー自動化（setup-ci-review）が未適用のリポを Linear に Issue として積み、適用漏れを防ぐ。

### 手順

1. `claude-review-coverage --format json --only-missing` を実行して未適用リポ一覧を取得
   ```bash
   ~/gh/github.com/ryosukesuto/dotfiles/bin/claude-review-coverage --format json --only-missing > /tmp/coverage-missing.json
   ```
2. 結果を `jq` で整形して、リポごとに以下を抽出:
   - `repo`: `host/owner/name`
   - `status`: `未適用` / `部分適用`
   - 既存ファイル状況（workflow/skill/greptile/checkov の有無）
3. 既に Linear に同名 Issue が存在しないかチェック
   ```
   mcp__linear-server__list_issues(query: "setup-ci-review {repo}", limit: 5)
   ```
4. 未起票のリポをユーザーに提示し、どれを起票するか確認（`AskUserQuestion` でまとめて選択）
5. 承認されたリポについて `mcp__linear-server__save_issue` で Issue 作成
   - タイトル: `{repo} に setup-ci-review を導入`
   - body: 下記テンプレート参照
   - priority: 部分適用は `2 (High)`、未適用は `3 (Normal)`
   - team: 設定の TEAM_ID
   - labels: `["devx", "automation"]`（既存ラベルがあれば追加）

### Issue body テンプレート

```markdown
## 背景

`bin/claude-review-coverage` で {YYYY-MM-DD} 時点で未適用と検出されたリポ。
PR レビュー自動化（Claude Code Action / Greptile）を導入して、AI レビュー
が走る状態にする。

## 現状

- リポ: {host/owner/name}
- workflow (`.github/workflows/claude-review.yml`): {✅ / ❌}
- skill (`.claude/skills/claude-code-review/SKILL.md`): {✅ / ❌}
- greptile (`.greptile/config.json`): {✅ / ❌}
- checkov (`.github/workflows/checkov.yml`): {✅ / ❌}

## やること

1. `setup-ci-review` skill を流す（個人ツール、対話で構成決定）
2. `ANTHROPIC_API_KEY` を Settings > Secrets に登録
3. `https://github.com/apps/claude` から GitHub App を対象リポにインストール
4. branch protection の Required approvals を 2 以上に設定
5. 初回 PR で動作確認（マージ後の次の PR で実レビューが走る）

詳細手順: `~/gh/github.com/ryosukesuto/dotfiles/config/claude/rules/new-repo-checklist.md`

## 完了条件

- `claude-review-coverage` で `完全適用` と表示される
- 直近 1 件の PR で Claude Code Action が動作している
```

### 注意

- 一度に大量起票しない。月 5 件を目安に、優先度の高いリポから順次（重要度: ops > server-config > 業務リポ > その他）
- 既に Issue がある場合は新規起票せず、既存 Issue にコメントで「{YYYY-MM-DD} 時点で未適用継続」と追記する選択肢を提示
- 個人 / experimental リポは「適用しない判断」として手動でカバレッジから除外する候補をユーザーに確認

## 設定

- TEAM_ID: `~/.claude/rules/service-environments.local.md` を参照
- 上記ファイルが存在しない場合のfallback: `mcp__linear-server__list_teams(query: "Platform")` で取得（PFチーム所属の前提）

## Gotchas

- `gh pr list` は現在のリポジトリのPRのみ返す。複数リポジトリを横断する場合は `gh search prs --author=@me --created=">=YYYY-MM-DD"` を使う
  - `gh search prs` の `--state` は `open|closed` のみ。`all` は不可
  - `--json` で `headRefName` は指定不可。タイトル/bodyからPF-XXXXを抽出する
- Phase 1のPR description更新はマージ済みPRでも `gh pr edit` で可能
- `list_projects(member: "me")` はViewerだけのプロジェクトも含む可能性がある。active状態のみを対象にする
- Cycleへの追加は `save_issue(id: "PF-XXXX", cycle: <cycleId>)` で行う。Cycleから外す場合はcycleにnullを指定できないため、ユーザーに手動対応を案内する
- `mcp__linear-server__list_issues` で `assignee=me, limit=50+` だと応答が大きくなりファイル経由で返ることがある。jqで必要フィールド (id, title, status, project, cycleId, priority, estimate) のみ抽出する
- `AskUserQuestion` は1問あたりオプション最大4個。プロジェクト/Issueが5個以上ある場合は質問を分割する
