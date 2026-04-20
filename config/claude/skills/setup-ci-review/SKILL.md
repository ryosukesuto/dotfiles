---
name: setup-ci-review
description: GitHubリポジトリにPRレビュー自動化を対話的に導入する。Claude Code workflow / Greptile / Checkov gating を bootstrap。生成時に既存ファイルは無断上書きしない（既存インストールの更新は update-existing.sh で対応）。「PRレビュー導入」「setup-ci-review」「コードレビューCI bootstrap」「CIレビュー setup」等で起動。
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(ls:*)
  - Bash(mkdir:*)
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - AskUserQuestion
  - Bash(~/.claude/skills/setup-ci-review/scripts/*)
---

## 実行手順

### 1. リポジトリ確認

```bash
gh repo view --json nameWithOwner,defaultBranchRef
```

失敗した場合は `git remote get-url origin` でフォールバック。
`REPO_NAME` を取得しておく。

### 2. ユーザーへの質問（1回でまとめて聞く）

`AskUserQuestion` で以下を一度に収集する。往復を最小化するため、1回でまとめて聞く。

- preset: `generic` / `iac`
- コンポーネント選択（multiSelect）:
  - `generic`: Claude Code workflow / Greptile
  - `iac`: Claude Code workflow / Greptile / Checkov（IaCのみ候補追加）
- analyze: コードベースを分析して設定を最適化するか（yes/no）
- model: レビューに使うClaudeモデル（`default` = action既定 / `opus-4-5` / その他、デフォルト `default`）

### 3. コードベース分析（analyze=yes の場合のみ）

スタックや規約を検出し、生成ファイルをリポジトリに合わせる。

探索対象（存在するもののみ読む）:
- `CLAUDE.md` / `README.md`（コーディング規約・プロジェクト概要）
- 言語マニフェスト: `go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml`（存在確認）
- `.github/workflows/`（`Bash(ls:*)` で一覧取得）
- トップレベルディレクトリ一覧（`Bash(ls:*)` で確認）

分析結果から以下をセットする:
- `REVIEWER_ROLE`: 検出スタックを反映（例: 「Go/Terraformに精通したシニアエンジニア」）
- `REVIEW_CRITERIA`: スタック固有の観点を追記（IaC presetの場合はIaC観点カタログと統合）
- Greptile `rules.md` の `<!-- ここにリポジトリ固有の観点を追記 -->` 部分: CLAUDE.mdから抽出したコーディング規約で置換
- Greptile `files.json` の `files[]`: 重要ファイル・ディレクトリを `{path, description, scope?}` オブジェクトとして追加（scope 省略時は全レビュー対象）

### 4. 競合検出

既存ファイルへの無断上書きを防ぐため、生成予定ファイルのパスを引数として `${CLAUDE_SKILL_DIR}/scripts/detect-conflicts.sh` を実行する。

出力を読んでユーザーに提示し、既存ファイルがある場合はマージ判断を仰ぐ。
Skillは自動マージも自動上書きもしない（既存設定の意図を判断できないため）。

衝突検出後の動作は `.new` 退避＋他ファイル継続 が既定フロー。
- 衝突したファイルへは書かない。`detect-conflicts.sh` が生成した `<file>.new` プレースホルダに新内容を書き込み、ユーザーに `mv <file>.new <file>` での適用を委ねる
- その他の非衝突ファイルは通常通り生成して続行する（全停止はしない）
- 注意: `<file>.new` は `detect-conflicts.sh` が `touch` で空ファイルとして先に作成している。`Write` ツールは未 Read のファイルへの書き込みを拒否するため、`.new` への書き込み前に一度 `Read` を挟む

`.greptile/` 配下は3ファイル（config.json / rules.md / files.json）を個別に引数に含める。
ディレクトリの存在だけで「スキップ」と判定してはいけない。
`.claude/skills/claude-code-review/SKILL.md` も個別に競合判定する（他のスキル管理と混在するため、ディレクトリ存在だけで判定してはいけない）。

### 5. テンプレートの読み込みと変数置換、ファイル生成

`${CLAUDE_SKILL_DIR}/templates/` 配下のテンプレートを `Read` し、以下を置換して `Write` する。

| 変数 | 置換先 |
|------|--------|
| `{{REVIEWER_ROLE}}` | generic=「シニアエンジニア」 / iac=「Terraformシニアレビュアー」（analyze=yesの場合はスタック反映） |
| `{{REVIEW_CRITERIA}}` | generic=空文字 / iac=IaC観点カタログ（analyze=yesの場合はスタック固有観点を追加） |

`--model` フラグはテンプレートで `claude-opus-4-5` をデフォルト指定している。v1.0.72 は旧 `thinking.type.enabled` API を使うため、新しい `claude-opus-4-7` / `claude-sonnet-4-6` を指定すると 400 エラーになる。`--model` を外すと action のデフォルト（Sonnet）になるため、深いレビューが欲しい場合は旧 API 対応の Opus を明示する。軽量運用なら `--model` 行を削除して Sonnet に任せる。

生成先（選択されたコンポーネントのみ）:
- Claude Code workflow: `.github/workflows/claude-review.yml`
- Claude Code review skill: `.claude/skills/claude-code-review/SKILL.md`
  - `claude-code-review-skill.md` テンプレートを Read し、`{{REVIEWER_ROLE}}` / `{{REVIEW_CRITERIA}}` を置換して `.claude/skills/claude-code-review/SKILL.md` として Write
  - workflow からは `claude-code-review` スキル名で呼び出されるため、パスは固定（変更禁止）
- Greptile: `.greptile/config.json` / `.greptile/rules.md` / `.greptile/files.json`
  - IaC preset → `config-iac.json` を `config.json`、`rules-iac.md` を `rules.md` として生成
  - generic preset → `config.json` / `rules.md` をそのまま生成
  - analyze=yesの場合 → rules.md のプレースホルダーを分析結果で置換、files.json の `files[]` に実際の重要ファイルを `{path, description}` で追記（公式スキーマ準拠）
  - 構造化ルール: IaC preset の `config.json` には `rules[]` に `id` / `severity` / `scope` 付きのIaC観点が含まれる。サブディレクトリで一部ルールを無効化したい場合は、そのディレクトリに `.greptile/config.json` を置いて `disabledRules: ["<id>"]` を指定する（cascading で親ルールを継承）
- Checkov: `.github/workflows/checkov.yml`（IaC preset かつ選択時のみ）

### 6. SHA-pin 検証

サプライチェーン攻撃対策として、生成した `.yml` ファイルのパスを引数として `${CLAUDE_SKILL_DIR}/scripts/verify-sha-pin.sh` を実行する。

exit 1 の場合は失敗として報告し、修正を促す。
local action（`uses: ./...`）と reusable workflow は検証対象外（スクリプト内で除外済み）。

### 7. 完了ガイド表示

以下をユーザーに伝える。

- 必要な Secret: `ANTHROPIC_API_KEY`（リポジトリ Settings > Secrets > Actions）
- Branch Protection は維持したまま、Claude / Greptile の check を Required Check にしない
- Greptile `statusCheck: true` は状態表示用。Required Check にすると block 相当になるため注意
- 生成ファイルの確認を促し、コミット・PR作成はユーザーに委ねる
- 再レビューのトリガー方法を伝える:
  - 自動: 新しいコミットをpushすると `synchronize` で再レビューが走る（force-push も検出してフルレビューに切り替わる）
  - 手動: PRに `@claude re-review` 等 `@claude` を含むコメントを MEMBER/OWNER/COLLABORATOR が投稿すると再レビューが走る
- 初回 workflow 追加 PR ではレビューがスキップされる（"Action skipped due to workflow validation error"）。動作確認はマージ後の次の PR で行うこと
- 増分レビューは `<!-- claude-code-review -->` マーカー付きコメントに追記される仕組み。初回は新規コメント、2回目以降は既存コメントに履歴が蓄積される

## 既存インストールの更新

テンプレート（`claude-review.yml` / `claude-code-review/SKILL.md`）を変更した場合、既にこの
skill で導入済みのリポジトリには自動では反映されない。`scripts/update-existing.sh` を使って差分を当てる。

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-existing.sh /path/to/target-repo
# 差分を目視確認 → y で適用 → ユーザー側で commit & push

# 確認プロンプトをスキップしたい場合
bash ${CLAUDE_SKILL_DIR}/scripts/update-existing.sh /path/to/target-repo --yes
```

挙動:
- `claude-review.yml` は最新テンプレートで完全上書き
- `SKILL.md` は最新テンプレートで完全上書き。ただし `REVIEWER_ROLE` / `REVIEW_CRITERIA` は既存ファイルから抽出して保持する（`setup-ci-review` が analyze=yes で埋めた値は消えない）
- 各ファイルごとに差分を表示して y/N 確認（`--yes` で省略可）
- コミット・push は行わない

注意:
- 既存 SKILL.md に `REVIEWER_ROLE` / `REVIEW_CRITERIA` 以外の手動カスタマイズがある場合、全置換で失われる。差分を必ず目視確認すること
- 抽出ロジックは「あなたは ... です。このPRをレビューします。」パターンと「3. 既存コードとの一貫性チェック ... 」から「## 優先度ラベル」の間で REVIEW_CRITERIA を識別する。SKILL.md の骨格を手動で大きく変えている場合は抽出失敗して WARN を出す（この場合は skip される）
- PR ブランチが古い main 上にいると、そのブランチの `SKILL.md` は更新前のまま。`git rebase origin/main` してから再レビューを走らせる必要がある。テンプレート冒頭に rebase ガイドが入っているので Claude 自身も古い PR で rebase を促す

## Gotchas

- **action バージョンは v1.0.72（`cd77b50d2b0808657f8e6774085c8bf54484351c`）に固定**: v1.0.101 以降では `mcp__github_inline_comment__create_inline_comment` が削除されており、インラインコメント投稿ができない。更新提案が来ても鵜呑みにしないこと
- **v1.0.72 は旧 thinking API のみ対応**: `--model claude-opus-4-7` や `claude-sonnet-4-6` を指定すると `"thinking.type.enabled" is not supported for this model` で 400 エラー。新モデルは `thinking.type.adaptive` を要求するため、v1.0.72 では互換性がない。`--model` フラグを外して action 既定に委ねるか、`claude-opus-4-5` 等の旧 API 対応モデルを使うこと
- `--allowedTools` には `mcp__github_inline_comment__create_inline_comment` を必ず含める。これが無いと Claude が分析だけして何も投稿せず終わるケースがある（`display_report: true` はworkflow summaryに出すだけでPRコメントには投稿しない）
- `--allowedTools` の Bash パターンに空白と複数 `*` を混ぜると Claude CLI の引数解釈が壊れて `Could not resolve authentication credentials` で fail する。`Bash(gh api --method PATCH repos/*/issues/comments/*:*)` は動作確認済みだが、新規パターンを増やすときは単体で動作確認する
- `anthropics/claude-code-action` は `id-token: write` permission が必須。ANTHROPIC_API_KEY 直接認証の構成でも内部で OIDC token を要求するため、未使用に見えても削除してはいけない（削除すると `Could not fetch an OIDC token` で fail する）。Codex/AI レビュアが「未使用だから削除」と誤指摘することがあるので却下すること
- PR レビューの最終判定は `--approve` または `--request-changes` を必須で出す設計。`--comment` はレビュー状態が「commented」扱いで CI/Branch Protection 連携がしにくいため使わない。P0/P1 なし → `--approve`、あり → `--request-changes`。AI による approve を避けたい場合は `--comment` に差し替えるが、レビュー完了を機械的に判別できなくなる点を受容すること
- Claude Code workflow を追加する初回 PR 自身では Claude のレビューはスキップされる（"Action skipped due to workflow validation error" / セキュリティ対策）。CI status は pass 扱いだがレビューコメントは付かない。動作確認は**マージ後の次の PR**で行うよう案内すること
- `.greptile/` は3ファイルを個別に競合判定。ディレクトリ存在だけでスキップ禁止
- Checkov は IaC preset 選択時のみ候補に出す（Terraform専用）
- `verify-sha-pin.sh` は生成ファイルのみ対象
- analyze=yesでCLAUDE.mdが存在しない場合はREADME.mdとディレクトリ構造から推定する
- private repo で fork は org メンバーに限定されるため、`issue_comment` トリガーの prompt injection リスクは `author_association == MEMBER/OWNER/COLLABORATOR` のチェックで許容範囲とみなしてよい（public repo の場合はより慎重な判断が必要）
- `allowed_bots: "dependabot[bot],renovate[bot]"` を指定すると bot PR でも Claude がレビューを走らせる。依存更新の破壊的変更チェック用途で有効
- 増分レビュー（履歴蓄積）は server リポジトリで実運用されている方式。`<!-- claude-code-review -->` マーカー検索 → 存在すれば `gh api --method PATCH` で追記、無ければ新規作成。force-push は `git merge-base --is-ancestor` で検出してフルレビューに切り替える
- レビュー指示は `.claude/skills/claude-code-review/SKILL.md` に分離している。**Skill invocation は使えない**: Claude Code Action v1.0.72 の SDK は組み込み skill（debug / simplify / batch / loop / claude-api）しかロードしないため、`Skill` tool による `claude-code-review` 呼び出しは `is_error: true` で失敗する。回避策として workflow の prompt に「`.claude/skills/claude-code-review/SKILL.md` を Read で読み込んで指示に従ってください」と書き、ただのマークダウンファイルとして読ませる。レビュー観点・投稿ルールを変更する場合は SKILL.md 側を編集する（workflow の再デプロイ不要）
- **concurrency の自己キャンセルループ**: `cancel-in-progress: true` のままだと Claude bot 自身が投稿する PR コメントが `issue_comment` イベントを発火させて実行中のレビューを打ち切る。`cancel-in-progress: ${{ github.event_name != 'issue_comment' }}` で issue_comment だけキャンセル無効化するのが正解。`pull_request` では新コミット push で古いレビューを止める挙動を維持できる
- **SKILL.md の投稿フロー最終ステップを省略する現象**: 過去の実測で Claude がサマリコメント投稿後に `gh pr review --approve/--request-changes` を忘れてタスク完了と判断するケースがあった。GitHub 上のレビュー状態が残らないため、SKILL.md の「PR レビュー判定」セクションは「省略禁止」「必ず最後に実行」と明示的に強調すること（テンプレート済み）
- **workflow ファイル変更を含む PR は Claude にレビューさせられない**: `claude-code-action` は PR ブランチの workflow ファイルが main と一致しているか検証する（セキュリティ機構）。差異があると `Workflow validation failed` で即 fail する。`claude-review.yml` 自体の修正 PR は人間レビューで進めること
- **ユーザーのローカル環境で `_gh_ensure_token` エラーが出る**: `gh:1: command not found: _gh_ensure_token` は zsh の gh 認証 wrapper の副作用で、コマンド自体は動く。Skill の挙動には影響しない

詳細は `${CLAUDE_SKILL_DIR}/reference.md` を参照（必要時のみ読み込む）。
