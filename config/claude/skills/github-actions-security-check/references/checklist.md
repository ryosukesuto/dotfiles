# GitHub Actionsセキュリティ監査チェックリスト

最終確認: 2026-07-15

WizのGitHub Actions hardening guideを起点に、GitHub公式のSecure UseとActions Permissions APIを優先して判定する
この文書は検出候補をFindingへ昇格させるための判断基準であり、項目数によるスコアリングには使わない

## 目次

1. Evidenceモデル
2. ローカル探索
3. サプライチェーン
4. Tokenと権限
5. SecretとOIDC
6. Untrusted InputとPoisoned Pipeline Execution
7. Runner
8. Artifact、cache、credential
9. RepositoryとOrganization設定
10. 重大度とConfidence
11. 公式資料

## 1. Evidenceモデル

Findingは、次の要素を可能な限り一つの経路として示す

| 要素 | 確認すること |
|---|---|
| Source | 攻撃者が制御できるTrigger、context、PRコード、Artifact、Action更新 |
| Execution | run、shell、Action、build、test、設定ローダーなどの実行地点 |
| Privilege | GITHUB_TOKEN、Secret、OIDC、Environment、Runner、Cloud権限 |
| Persistence | Repository、release、package、Artifact、cache、Runnerへの残留 |
| Egress | 外部通信、package registry、Cloud API、データ持ち出し経路 |

Source → Execution → Privilegeが確認できれば、攻撃可能性の高いFindingとして扱う
設定上の弱点だけの場合は、利用場面とblast radiusに応じてMedium以下を基本とする

静的解析結果、単一のキーワード一致、設定の不在だけで攻撃経路を断定しない

## 2. ローカル探索

### 2.1 対象ファイル

~~~bash
git ls-files '.github/workflows/*.yml' '.github/workflows/*.yaml' '**/action.yml' '**/action.yaml' '.github/dependabot.yml' 'renovate.json' 'renovate.json5' 'CODEOWNERS' '.github/CODEOWNERS'
~~~

git ls-filesのpathspecで取りこぼす場合はGlobで補完し、vendor、node_modules、.git、生成物を除外する

### 2.2 候補収集

~~~bash
# External actions and reusable workflows
rg -n --hidden --glob '!**/.git/**' --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' --glob '**/action.yml' --glob '**/action.yaml' '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[^#[:space:]]+' .

# Triggers and effective privilege declarations
rg -n --hidden --glob '!**/.git/**' --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' 'pull_request_target|pull_request:|workflow_run|issue_comment|workflow_dispatch|permissions:|write-all|id-token:' .

# Secret propagation and credentials
rg -n --hidden --glob '!**/.git/**' --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' --glob '**/action.yml' --glob '**/action.yaml' 'secrets[.]|secrets: inherit|toJson[(]secrets[)]|toJSON[(]secrets[)]|persist-credentials|AWS_ACCESS_KEY_ID|GOOGLE_APPLICATION_CREDENTIALS' .

# Untrusted contexts and execution-adjacent channels
rg -n --hidden --glob '!**/.git/**' --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' --glob '**/action.yml' --glob '**/action.yaml' 'github[.]event|github[.]head_ref|github[.]ref_name|GITHUB_ENV|GITHUB_PATH|bash -c|sh -c|eval ' .

# Runner, artifact, and cache boundaries
rg -n --hidden --glob '!**/.git/**' --glob '.github/workflows/*.yml' --glob '.github/workflows/*.yaml' --glob '**/action.yml' --glob '**/action.yaml' 'self-hosted|upload-artifact|download-artifact|actions/cache|restore-keys|docker[.]sock' .
~~~

コマンドは候補収集だけに使い、必ずWorkflow全体を読む
再利用可能Workflowは呼び出し元と呼び出し先のpermissions、secrets、inputsを結合して評価する

### 2.3 補助ツール

~~~bash
actionlint
zizmor --persona auditor --min-severity low --offline .
~~~

- actionlintはYAML、式、shell連携の検査に使う
- zizmorはWorkflow、Composite Action、Dependabot設定のセキュリティ候補収集に使う
- zizmorの --fix は使わない
- どちらもWorkflowから呼ばれる任意スクリプトの完全なtaint analysisはできない

## 3. サプライチェーン

### 3.1 Actionと再利用可能Workflow

| ID | 確認項目 | 望ましい状態 |
|---|---|---|
| SC-01 | 外部Actionの参照 | 完全長commit SHAで固定 |
| SC-02 | 外部の再利用可能Workflow | 完全長commit SHAで固定 |
| SC-03 | Action許可ポリシー | GitHub-owned、審査済みAction、明示allowlistへ限定 |
| SC-04 | SHA固定の強制 | RepositoryまたはOrganizationでsha_pinning_required=true |
| SC-05 | Actionの出所 | 正規Repositoryのcommitであり、fork由来でない |
| SC-06 | 更新管理 | DependabotまたはRenovateでレビュー可能なPR更新 |
| SC-07 | 更新cooldown | 高価値Workflowでは新規release採用を7〜14日遅延 |
| SC-08 | Workflow変更保護 | .github/workflowsとAction定義にCODEOWNERS |

完全長SHAは、参照値が現在GitHubで使われる40桁のhex commit IDか確認する
末尾コメントのversion表記は可読性の補助であり、固定の証拠にはしない

次はSHA固定対象外として分ける

- uses: ./local-path
- uses: docker://image
- 同一Repository内のローカルComposite Action

ただしdocker imageはdigest固定、ローカルActionは呼び出す外部依存を別途確認する

### 3.2 重大度の補正

- 外部Actionがtag固定で、releaseやdeploy JobのSecretまたはwrite権限へ到達する: High候補
- tag固定だがTokenがread-onlyでSecretなし: Medium候補
- SHA固定済みでも推移的依存、Action内部のdownload、install scriptがある: 要手動確認
- GitHub Immutable Releaseを確認できても、OrganizationがSHA固定を要求するならSHA固定を優先

人気、star数、Verified badgeだけで安全と判定しない
Action publisher自身の場合はImmutable Releasesの利用も確認する

## 4. Tokenと権限

| ID | 確認項目 | 望ましい状態 |
|---|---|---|
| PR-01 | Workflow既定権限 | permissions: {} またはcontents: readから開始 |
| PR-02 | Job権限 | 必要なJobだけに必要なscopeを付与 |
| PR-03 | write-all | 使用しない |
| PR-04 | contents: write | release、commit、tag操作など必要なJobだけ |
| PR-05 | pull-requests/issues: write | bot操作が必要なJobだけ |
| PR-06 | actions: write | Workflow操作が必要なJobだけ |
| PR-07 | id-token: write | OIDCを使うJobだけ |
| PR-08 | 既定Workflow権限 | Remote設定がread |
| PR-09 | PR承認 | can_approve_pull_request_reviews=false |

permissions省略は、Localだけでは実効権限を確定できない
Remote設定を取得できない場合は「既定値依存」としてMedium以下または要手動確認にする

第三者Actionは明示的に渡されていなくても、Jobのgithub.token contextと同じJob内のデータへ到達できる前提でblast radiusを評価する

権限分離が必要な例

- test Jobはread-onlyかつSecretなし
- release Jobはprotected branch、Environment承認、限定write権限
- PR由来Artifactを扱うJobとpublish Jobを同じ信頼境界に置かない

## 5. SecretとOIDC

| ID | 確認項目 | リスク |
|---|---|---|
| SE-01 | toJson(secrets) / toJSON(secrets) | 全SecretをRunnerへ展開 |
| SE-02 | secrets: inherit | 再利用可能Workflowへ過剰に委譲 |
| SE-03 | WorkflowやJob全体のenv | 不要なStepや外部Actionへ露出 |
| SE-04 | 長期Cloud credential | 漏えい後も利用可能 |
| SE-05 | SecretをCLI引数へ埋め込み | process listやerror logへ露出 |
| SE-06 | SecretをArtifactやcacheへ含める | Job境界やWorkflow境界を越えて漏えい |
| SE-07 | Environment保護なし | deploy Secretへ承認なしで到達 |
| SE-08 | Secret変換後の値 | redaction対象外になる可能性 |

望ましい状態

- 必要なSecretを名前で列挙し、必要なStepのenvだけへ渡す
- 再利用可能Workflowのsecretsを明示する
- Cloud認証はOIDCによる短命かつscope限定のtokenを優先する
- deployはEnvironment、required reviewers、branch/tag制限で保護する
- Secret名や利用箇所は確認してよいが、値の取得や表示は行わない

OIDCのid-token: write自体は脆弱性ではない
Cloud側trust policyのsubject、audience、Repository、branch、Environment条件が監査範囲外なら、そこを要手動確認に残す

## 6. Untrusted InputとPoisoned Pipeline Execution

### 6.1 Triggerの信頼境界

| Trigger | 基本的な扱い |
|---|---|
| pull_request | fork PRではread-only tokenかつSecretなしが基本だが、PRコードは攻撃者制御 |
| pull_request_target | base側の権限とSecretを持つ。PR由来コードを取得して実行すると危険 |
| workflow_run | 下流が高権限になり得る。上流Artifactを信頼せず追跡 |
| issue_comment | コメント投稿者と対象PRを検証し、PRコード取得の有無を追跡 |
| workflow_dispatch | actor制限、入力値、ref選択、Environment保護を確認 |
| push / schedule | Workflow定義は通常信頼側だが、外部依存や侵害済みbranchを考慮 |

pull_request_targetでref未指定のactions/checkoutはbase default branchを取得するため、それだけで脆弱とはしない
actions/checkout v7以降はfork PR refの危険なcheckoutを既定で保護する
次は保護を迂回または対象外にするため、必ず追跡する

- allow-unsafe-pr-checkout: true
- ref: ${{ github.event.pull_request.head.sha }}
- repository: ${{ github.event.pull_request.head.repo.full_name }}
- refs/pull/.../merge
- git fetch、gh pr checkout、curlやAPIでのPRコード取得
- fork側Workflowが作ったArtifactのdownloadと実行

checkout自体はコード実行ではない
後続のbuild、test、package install、make、Docker build、linter、generator、設定読込まで到達したときにPwn Requestが成立する

### 6.2 攻撃者が制御し得る値

- PR、Issue、Review、Commentのtitle、body、label
- branch名、tag名、head_ref、ref_name
- commit message、author情報
- workflow_dispatchやrepository_dispatchのinputs
- PRで変更可能なRepositoryファイル、package script、Makefile、test fixture
- forkや低信頼Workflowから生成されたArtifact、cache key、output

Repository visibilityと権限モデルを確認し、単にgithub contextだから安全とは扱わない

### 6.3 実行sink

- run内への ${{ }} 直接展開
- eval、bash -c、sh -c、PowerShell Invoke-Expression
- 引用されていないshell変数や動的command
- npm/pnpm install script、make、test runner、build tool
- 設定ファイルを読み込んでcode executionできるlinterやgenerator
- Dockerfile、Composite Action、ローカルscript
- GITHUB_ENV、GITHUB_PATHへ低信頼値を書き、後続Stepへ影響

runへcontext値を直接展開せず、Actionのwith入力または中間envへ渡し、shell側で引用して扱う
中間envにしただけで、evalや未引用展開を行えば安全にはならない

### 6.4 判定例

- pull_request_target → PR head checkout → package install → Repository Secretあり: CriticalまたはHigh
- issue_comment → bodyをrunへ直接展開 → contents: write: High
- workflow_run → fork由来Artifactをdownload → 実行 → package registry tokenあり: CriticalまたはHigh
- pull_request → untrusted codeをtest → GitHub-hosted Runner、read-only、Secretなし: 通常のCI。Runnerやcacheの追加経路を確認

## 7. Runner

| ID | 確認項目 | 望ましい状態 |
|---|---|---|
| RU-01 | Public Repositoryのself-hosted | 原則使用しない |
| RU-02 | Runner再利用 | Jobごとにcleanかつephemeral |
| RU-03 | Runner group | Repositoryと信頼レベルで分離 |
| RU-04 | Network egress | deny-by-defaultまたは必要先へ限定 |
| RU-05 | 内部到達性 | metadata service、社内DB、管理APIへ不要な到達なし |
| RU-06 | Host資産 | SSH key、Cloud credential、Docker socketを残さない |
| RU-07 | 監視 | process、network、runner lifecycleを記録 |

Public Repositoryで外部PRがself-hosted Runnerへ到達できる場合はCritical候補
Private Repositoryでもread権限者がfork PRを作れるため、self-hostedだから信頼済みとはしない

container JobはHostからの完全なセキュリティ境界ではない
JIT Runnerでも基盤を再利用する場合はclean environmentを別途確認する

## 8. Artifact、cache、credential

| ID | 確認項目 | リスク |
|---|---|---|
| AR-01 | actions/checkoutのpersist-credentials | 後続StepがGit credentialを利用可能 |
| AR-02 | upload-artifactの広いpath | Secret、設定、credentialを誤収集 |
| AR-03 | hidden fileやworkspace全体 | 意図しないファイルを公開 |
| AR-04 | workflow_runのArtifact | 低信頼Workflowから高信頼Workflowへ持ち込み |
| AR-05 | Artifact名やpath traversal | 動的pathの検証不足 |
| AR-06 | cache keyとrestore-keys | trust boundaryを越えたcache poisoning |
| AR-07 | Artifact attestation | release成果物のprovenance不足 |

checkout後に認証付きgit操作が不要ならpersist-credentials: falseを推奨する
ただしcheckout v6以降の保存場所変更を考慮し、「.git/configへ必ず保存される」と断定しない

Artifactは保存対象pathを具体的に確認する
workspace全体、home、tmp、build contextにはcredentialや設定ファイルが混ざる前提で評価する

## 9. RepositoryとOrganization設定

### 9.1 読み取り専用API

~~~bash
gh repo view --json nameWithOwner,visibility,defaultBranchRef
gh api --method GET "repos/$SLUG/actions/permissions"
gh api --method GET "repos/$SLUG/actions/permissions/workflow"
gh api --method GET "repos/$SLUG/actions/permissions/selected-actions"
gh api --method GET "repos/$SLUG/actions/permissions/fork-pr-contributor-approval"
gh api --method GET "repos/$SLUG/rulesets?includes_parents=true"
gh api --method GET "repos/$SLUG/environments"
gh api --method GET "repos/$SLUG/actions/runners"
~~~

selected-actions endpointはallowed_actions=selectedのときだけ呼ぶ
private fork設定など、Repository種別により存在する追加GET endpointはGitHub公式REST docsで確認して使う

### 9.2 判定項目

| 設定 | 望ましい状態 |
|---|---|
| allowed_actions | selectedまたはlocal_only。allなら利用Actionを個別確認 |
| sha_pinning_required | true |
| default_workflow_permissions | read |
| can_approve_pull_request_reviews | false |
| fork PR approval | 外部Contributorへ適切な承認を要求 |
| rulesets / branch protection | review必須、新commitで古い承認を無効化、last pusher以外の承認 |
| environments | deploy reviewer、branch/tag制限 |
| self-hosted runners | 対象Repositoryと信頼レベルへ限定 |
| Workflow Execution Protections | actor/event allowlist。Public Previewとして手動確認も許容 |

Repository APIで取得できる値と、OrganizationやEnterpriseから継承される実効ポリシーを混同しない
権限不足、404、プラン差、Public Preview未提供は「未確認」とする

## 10. 重大度とConfidence

### 10.1 重大度

| 重大度 | 判定基準 |
|---|---|
| Critical | 外部または低信頼Actorが、Secret、write token、publish権限、内部到達性を持つ環境で任意コードを実行できる経路が確認済み |
| High | 直接的なscript injectionやPwn Request、または高価値Jobで改ざん可能な第三者依存があり、credential theftやRepository takeoverへ現実的に到達 |
| Medium | SHA未固定、過剰権限、Secret過剰委譲、credential残留など、追加条件がそろうと悪用可能な弱点 |
| Low | CODEOWNERS、cooldown、Artifact attestationなどdefense-in-depthの不足 |
| Info | 現状の防御、観測できない範囲、運用上の改善候補 |

重大度は最悪影響だけでなく、攻撃者がSourceを制御できるか、Executionへ到達するか、必要権限が実在するかで決める

### 10.2 Confidence

| Confidence | 条件 |
|---|---|
| High | ファイル行と実効Remote設定が確認でき、攻撃経路に推測がほぼない |
| Medium | Local根拠はあるが、継承設定、Secret scope、外部Action内部など一部が未確認 |
| Low | keyword一致や権限不足による推測が中心。Findingではなく要手動確認を優先 |

### 10.3 False positiveを避ける

- Trigger名だけでFindingにしない
- Secret名だけで漏えいと判定しない
- permissions: writeだけで過剰と断定せず、Jobの目的を確認する
- persist-credentials単独でcredential theftと断定しない
- actionlintやzizmorのseverityをそのまま転記しない
- 取得できなかったRemote設定を安全側の値と仮定しない

## 11. 公式資料

判定が変わり得る機能は、次の一次資料を優先する

- GitHub Secure use reference: https://docs.github.com/en/actions/reference/security/secure-use
- Securely using pull_request_target: https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target
- Script injections: https://docs.github.com/en/actions/concepts/security/script-injections
- GitHub Actions permissions REST API: https://docs.github.com/en/rest/actions/permissions
- OIDC in cloud providers: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers
- Workflow Execution Protections: https://docs.github.com/en/organizations/managing-organization-settings/actions-policies/workflow-execution-protections
- actions/checkout README: https://github.com/actions/checkout/blob/main/README.md
- GitHub SHA pinning policy announcement: https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/
- zizmor documentation: https://docs.zizmor.sh/

背景と実例

- Wiz, How to Harden GitHub Actions: https://www.wiz.io/blog/github-actions-security-guide

Wizの記事は脅威モデルと実例の補助に使い、GitHubの現在仕様と設定APIはGitHub公式資料で上書きする
