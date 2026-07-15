---
name: github-actions-security-check
description: リポジトリのGitHub Actions Workflow、再利用可能Workflow、Composite Action、Repository設定を読み取り専用で監査し、サプライチェーン、権限、Secret、Poisoned Pipeline Execution、Runner、Artifactのリスクを根拠付きで報告する。「GitHub Actionsセキュリティチェック」「Actions監査」「Workflowを監査」「CI/CDセキュリティ」「GHA security audit」「harden GitHub Actions」等で起動。.github/workflows/*.ymlやaction.ymlのセキュリティレビューでも使用する。
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebFetch
  - Bash(pwd:*)
  - Bash(date:*)
  - Bash(command -v:*)
  - Bash(git rev-parse:*)
  - Bash(git ls-files:*)
  - Bash(git remote get-url:*)
  - Bash(rg:*)
  - Bash(actionlint:*)
  - Bash(zizmor:*)
  - Bash(gh auth status:*)
  - Bash(gh repo view:*)
  - Bash(gh api --method GET:*)
---

# /github-actions-security-check - GitHub Actionsセキュリティ監査

対象リポジトリのWorkflowとGitHub側設定を、攻撃経路まで追跡して監査する
静的ツールの警告をそのまま転記せず、ファイル行や設定値を根拠に実行可能な指摘を返す

## 安全原則

- 既定は読み取り専用。ファイル、Repository設定、Secret、Runnerを変更しない
- zizmorの --fix や、gh apiのPUT、POST、PATCH、DELETEを実行しない
- 不足ツールを勝手にインストールしない。利用できない検査はCoverageに記録する
- Secretの値を取得、表示、保存しない。値らしき文字列を見つけても伏せ字にする
- 監査レポートをファイルへ保存しない。ユーザーが保存を明示した場合だけ別途確認する
- grepや静的解析の一致は候補であり、前後のデータフローを確認してからFindingにする

## 実行手順

### 1. 対象とリポジトリ規約を確定する

引数のパスを優先し、未指定なら現在位置を対象にする

~~~bash
pwd
git rev-parse --show-toplevel
~~~

対象リポジトリのAGENTS.md、CLAUDE.mdなどの指示を先に確認する
リポジトリ外やGit管理外のパスを指定された場合は、その事実をCoverageに残してローカルファイルだけ監査する

次を棚卸しする

- .github/workflows/*.yml と .github/workflows/*.yaml
- action.yml、action.yaml、Composite Action、ローカルAction
- 再利用可能Workflowのuses参照
- .github/dependabot.yml、renovate.json、CODEOWNERS
- Workflowから呼び出されるスクリプトや設定ファイル

Workflowが存在しなければ「対象なし」と報告し、GitHub側設定を確認できる場合のみ設定監査を続ける

### 2. 監査基準を読み込む

${CLAUDE_SKILL_DIR}/references/checklist.md を最初から最後まで読む
Codexでは、このSKILL.mdを基準に同じ相対パスを解決する

GitHubの挙動が基準日以降に変わった可能性がある場合や、ユーザーが最新情報を求めた場合は、同ファイルの公式資料リンクだけを再確認する

### 3. 自動検査で候補を収集する

最初にGit管理対象を列挙し、生成物やvendorを混ぜない

~~~bash
git ls-files .github/workflows .github/actions .github/dependabot.yml renovate.json CODEOWNERS .github/CODEOWNERS
~~~

利用できるツールだけ実行する

~~~bash
actionlint
zizmor --persona auditor --min-severity low --offline .
~~~

- actionlintは構文や式の問題を探す補助であり、セキュリティ監査の代替にしない
- zizmorは --offline で実行し、自動修正を有効にしない
- ツールが失敗した場合はエラーを要約し、手動監査を継続する
- checklist.mdの探索コマンドで、Trigger、permissions、uses、Secret、Runner、Artifactの候補も収集する

### 4. Workflowごとに攻撃経路を追跡する

各WorkflowとJobについて、次の順序で確認する

1. Source: 誰がTriggerや入力値、PRコード、Artifactを制御できるか
2. Execution: その入力がrun、Action、build、test、package install、設定ローダーへ到達するか
3. Privilege: GITHUB_TOKEN、Secret、OIDC、Environment、Runnerの権限が何か
4. Persistence: Artifact、cache、release、package、Repository書き込み、Runner残留へ波及するか
5. Egress: 外部通信やCloud APIへ認証情報を持ち出せるか

SourceからExecution、Privilegeまでがつながる場合は、単なる設定不足より優先する
特にpull_request_target、workflow_run、issue_commentは、PR headやArtifactを取得する処理から後続コマンドまで追う

### 5. GitHub側設定を読み取り専用で確認する

GitHub remoteとgh認証が利用できる場合に実行する

~~~bash
gh auth status
gh repo view --json nameWithOwner,visibility,defaultBranchRef
gh api --method GET "repos/$SLUG/actions/permissions"
gh api --method GET "repos/$SLUG/actions/permissions/workflow"
gh api --method GET "repos/$SLUG/rulesets?includes_parents=true"
gh api --method GET "repos/$SLUG/environments"
gh api --method GET "repos/$SLUG/actions/runners"
~~~

allowed_actionsがselectedの場合だけ、次も確認する

~~~bash
gh api --method GET "repos/$SLUG/actions/permissions/selected-actions"
~~~

必要に応じてfork PR承認設定もGETする。403、404、機能未提供は安全とも脆弱とも判定せず「未確認」にする
OrganizationやEnterpriseから継承される設定をRepository APIだけで断定しない
Workflow Execution ProtectionsはPublic Previewのため、APIで取得できなければGitHub UIでの手動確認項目にする

### 6. Findingを検証して分類する

- 一致した行の前後を読み、Triggerから権限まで同じWorkflowまたは連携Workflow内で確認する
- ファイル根拠は path:line、Remote根拠はAPIフィールド名と値で示す
- exploitability、権限、Repository visibility、Runner到達範囲から重大度を決める
- 推測が残る場合はConfidenceを下げ、「要手動確認」へ分離する
- 同じ原因から生じる警告は一つのFindingに統合する

重大度と判定条件はchecklist.mdの「重大度」を使う

### 7. チャットへ報告する

Findingを重大度順に先に示す

~~~markdown
## GitHub Actionsセキュリティ監査

- 対象: owner/repo またはローカルパス
- 監査日: YYYY-MM-DD
- 範囲: Local / GitHub settings
- ツール: actionlint 実行済み、zizmor 未導入 など

### Findings

#### [HIGH] GHA-001 タイトル

- Evidence: .github/workflows/example.yml:42
- Attack path: attacker-controlled input → execution sink → privilege
- Impact: 想定される影響
- Recommendation: 最小の修正方針
- Confidence: High / Medium / Low

### 確認済みの防御

- 根拠を確認できた項目だけ列挙

### 要手動確認

- 権限不足や実行環境の外側にあり断定できない項目

### Coverageと制約

- 読んだWorkflow数、未実行ツール、取得できなかったRemote設定
~~~

Findingがなければ「確認範囲では重大な問題なし」と書く
「安全」「脆弱性なし」と断定せず、実行時Secret値、外部Action内部、Runnerネットワークなど未観測領域を残す

## Gotchas

- pull_request_targetの存在だけでは脆弱性ではない。PR由来コードやArtifactの取得、実行、権限を一続きで確認する
- actions/checkout v7以降にはfork PR refの保護があるが、allow-unsafe-pr-checkout、git fetch、gh pr checkout、Artifact経由は別途追跡する
- workflow_runの存在だけでは脆弱性ではない。上流Artifactを信頼して実行するか、下流にSecretやwrite権限があるかを確認する
- permissions省略時の実効値はRepositoryやOrganization設定に依存する。Remote設定を取得できない場合は断定しない
- uses: ./path と docker://image はcommit SHA固定の対象外。外部Actionと再利用可能Workflowだけを評価する
- tag固定はcommit SHA固定ではない。コメントにSHAやversionが書かれていても参照値そのものを評価する
- persist-credentialsがtrueでも単独で即Highにしない。後続の信頼できないコードとToken権限を組み合わせて判定する
- 403や404は「問題なし」ではない。認可不足、継承設定、GitHubプラン差を区別する
- zizmorやactionlintの重大度をそのまま採用せず、実際の権限と到達可能性で再評価する
- 外部Actionの推移的依存関係や公開後の改ざん耐性は、ローカルWorkflowだけでは完全に確認できない
