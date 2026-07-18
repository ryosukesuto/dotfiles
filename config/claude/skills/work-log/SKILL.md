---
name: work-log
description: 作業完了をデイリーノート＋Time Blockチェック＋Linear Issueに反映。mediphone/mediment関連はConfluence稼働ログにも記録。「作業ログ」「work log」「作業報告」「ワークログ」等で起動。
user-invocable: true
allowed-tools:
  - Bash(echo:*)
  - Bash(date:*)
  - Bash(git branch:*)
  - Bash(git config:*)
  - Bash(git rev-parse:*)
  - Bash(printf:*)
  - Bash(test:*)
  - Read
  - Edit
  - AskUserQuestion
  - mcp__linear-server__get_issue
  - mcp__linear-server__save_issue
  - mcp__linear-server__save_comment
  - mcp__atlassian-mediphone__getConfluencePage
  - mcp__atlassian-mediphone__updateConfluencePage
  - mcp__notion__notion-query-data-sources
  - mcp__notion__notion-fetch
  - mcp__notion__notion-update-page
---

# /work-log - 作業完了の記録

作業が一区切りついたタイミングで、更新先を同時に反映する。`til` が「学び」、`post-merge` が「PRマージ後」を担うのに対し、このスキルは「マージ前・調査のみ含む日々の作業」をカバーする。

## 更新先

1. Obsidianデイリーノート末尾（1行の作業ログ）
2. デイリーノートのTime Blockチェックボックス（完了した枠に `[x]`）
3. Linear Issue（コメント追加、必要ならステータス更新、本文のTODO・進捗記述の更新）
4. mediphone/mediment関連作業のみ:
   - Confluence稼働ログ（1行追記＋累計時間更新）
   - Notion `mediment管理` ページ配下のタスクデータベースを更新（該当タスクのステータス変更・進捗追記・正本リンク設定）

## 使い方

- `/work-log` - 会話全体から完了作業を抽出
- `/work-log [作業内容]` - 明示的に作業内容を指定

## 処理フロー

### Phase 1: 作業内容の抽出

現在のセッションから「完了した作業」を1-2文で要約する。事実ベース（何をしたか）で書き、所感や未完了の作業は含めない。ユーザーが引数で内容を指定した場合はそれを優先する。

なぜ事実ベースか: デイリーノートは後から検索される資産で、所感や未完了を混ぜると検索ノイズになる。所感は `til` 側で扱う。

### Phase 2: デイリーノートへの追記

グローバルCLAUDE.mdの既存規約に従って1行追記する。

```bash
VAULT_DIR="$HOME/gh/github.com/ryosukesuto/obsidian-notes"
DAILY_NOTE="$VAULT_DIR/$(date '+%Y-%m-%d')_daily.md"
echo "- $(date '+%Y/%m/%d %H:%M:%S'): ${SUMMARY}" >> "$DAILY_NOTE"
```

デイリーノートが存在しない場合は `til` と同じfrontmatter付きで新規作成する。

### Phase 3: Time Blockチェックボックス更新

デイリーノートの `## Time Block` セクションから完了したブロックを特定し、`[ ]` を `[x]` に書き換える。

なぜ自動化するか: Time Blockは実行のSSoT（Single Source of Truth）だが、作業ログと二重管理するとチェック漏れが発生する。作業完了の報告タイミングでまとめて反映することで、ノートの実態と表示のズレを防ぐ。

1. Readでデイリーノート全体を読む
2. Time Blockセクション内の未チェック項目（`- [ ]` で始まる行）を列挙
3. 各項目について、会話履歴と突き合わせて「完了している」と判断できるか評価
   - 時刻範囲が現在時刻より前に終わっている、かつ作業内容と一致する → 完了候補
   - 時刻範囲に入っている最中で、作業が明確に終わっている → 完了候補
   - 判断が曖昧（複数候補、部分完了、作業内容と一致しない） → AskUserQuestionで確認
4. 完了確定した行を Edit で `- [x]` に更新
5. 更新件数を報告

### Phase 4: Linear Issue更新

なぜTodo→In Progress昇格を自動化するか: ステータスの放置は週次レビュー（linear-triage）で差分として検出されるが、検出された時点で数日遅れている。着手タイミングで更新すれば差分が発生しない。

1. ブランチ名から Issue ID を抽出:
   ```bash
   BRANCH=$(git branch --show-current 2>/dev/null)
   ISSUE_ID=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
   ```
2. ブランチ名にIDがない場合、デイリーノートの `Linear References` セクションから「In Progress」のIssueを候補として提示し、AskUserQuestionで選択させる（スキップ可）
3. Issue IDが特定できたら `get_issue` で現状を取得
4. ステータス判定と更新:
   - 現ステータスが `Todo`/`Backlog` → `In Progress` に昇格
   - 現ステータスが `In Progress` のまま、かつ作業内容から完了が明確（PR作成済み、マージ済み、タスク完了の言明あり） → ユーザー確認の上で `Done`
   - それ以外 → ステータスは触らない
5. Issue本文（description）のTODO・進捗記述を更新:
   - `description` 内のチェックボックス行（`- [ ]` / `- [x]`）を列挙し、Phase 3と同じ基準で完了判定する
     - 会話履歴と明確に一致 → `- [x]` に反映
     - 複数候補・部分完了・内容不一致など判断が曖昧 → AskUserQuestionで確認（スキップ可）
   - チェックボックス以外でも、残タスクの記述やステータス欄など、会話から完了・進捗が明確に読み取れる箇所があれば同様に書き換える。記述の意図が読み取れない箇所は推測で変更しない
   - 見出し構成や受け入れ条件そのものの意味を変える書き換えはしない。あくまで「完了した項目にチェックが付く／進捗が反映される」範囲に留める
   - 変更がある場合のみ `save_issue(id: ISSUE_ID, description: 更新後の本文)` を実行。変更なしならスキップ
6. `save_comment(issueId: ISSUE_ID, body: SUMMARY)` でコメント追加
7. コメント本文は Phase 1 の要約をそのまま使う。Markdown可

### Phase 5: mediphone/mediment関連作業の記録先

なぜ別立てか: mediphoneは稼働ログ管理のためConfluenceに作業時間を記録しており、Linear/Jiraのようなチケット単位の管理をしていない（EM業はチケット化しない運用）。あわせて Notion `mediment管理` ページ配下のタスクにも進捗を残す運用がある。作業ログの記録タイミングに相乗りするのが最も漏れが少ない。

対象判定（いずれかに該当したら実行、非該当ならこのPhase全体をスキップ）:
- 会話で編集・参照したファイルパスに「メディフォン」「mediment」「mediphone」を含む
- 作成/編集したObsidianノートのfrontmatterに `tags: sideline/mediphone` がある
- ユーザーが会話中に「mediment」「mediphone」関連と明言した

#### 5-1. Confluence 稼働ログ記録

1. `${CLAUDE_SKILL_DIR}/SKILL.local.md` から Cloud ID・Page ID を読む
2. 所要時間の自動算出:
   - 現在時刻: `date '+%Y-%m-%d %H:%M:%S'`
   - デイリーノート内、直近の作業ログタイムスタンプ行（`- YYYY/MM/DD HH:MM:SS:`、til/work-log/post-mergeいずれの記録でもよい）を基点に、現在時刻との差分（分）を計算
   - 15分単位に丸め、60分未満は「約X分」、60分以上は「約Xh」（0.5刻み、例: 約1.5時間）の表記に変換
   - 差分が240分超、または5分未満など明らかに異常な値の場合は自動算出せず、AskUserQuestionで所要時間を確認する（他タスクとの並行・中断が混入している可能性が高いため）
3. `mcp__atlassian-mediphone__getConfluencePage(cloudId, pageId, contentFormat: "markdown")` で現在の本文を取得
4. テーブル末尾（`累計:` 行の直前）に新規行を追加: `| YYYY-MM-DD(曜日) | 約Xh | <Phase 1の要約> |`
5. 累計時間: 既存の「累計: 約XX時間」の数値に今回の所要時間を加算するだけ（テーブル全体の再集計はしない。曖昧な時間表記のパースミスで既存値がズレるのを避けるため）
6. `mcp__atlassian-mediphone__updateConfluencePage(cloudId, pageId, body: 更新後の全文, contentFormat: "markdown")` で書き戻す

#### 5-2. Notion mediment 管理タスクの更新

`mediment管理` ページ配下のタスクデータベースを対象に、今回の作業に対応するタスクを検索して更新する。ページID・データソースIDは `${CLAUDE_SKILL_DIR}/SKILL.local.md` から読む。

なぜタスクDBに閉じるか: ページ本文は運用方針の記述のみで、Confluence 稼働ログと重複した日次ログを書く場所ではない。「今何をすべきか」の集約ビューという運用方針に沿って、タスクの粒度で反映する。

タスク詳細ページの構造（`## TODO` `## 進捗` `## 参照` 節の使い分け）と新規作成テンプレートは `~/.claude/rules/mediment-notion-tasks.local.md` で定義する。この skill はそれを前提に更新処理だけを行う。

##### 手順

1. **対象タスクの候補抽出**:
   - ブランチ名から Backlog チケットID (`MDMT_DV-\d+` / `MDMT_CS-\d+`) と Jira チケットID (`MED-\d+` / `YOUR3-\d+`) を抽出
   - PR body があれば同じパターンで抽出（`Closes MDMT_DV-539` などの `Closes` / `Fixes` 系記述を含む）
   - Phase 1 要約から主要キーワードを抽出（例: `ALLOWED_HOSTS`, `SECRET_KEY`, `Secret Manager`, `IaC`, `Terraform`, `Backlog`, `Figma`, `GCP` 等）。名詞と略語を優先し、動詞や助詞は落とす
   - `notion-query-data-sources` (SQL mode) で以下を実行（`<data source id>` は `SKILL.local.md` の値を差し込む）:
     ```sql
     SELECT url, "タスク名", "ステータス", "優先度", "カテゴリ", "正本リンク"
     FROM "<data source id>"
     WHERE ("タスク名" LIKE ? OR "正本リンク" LIKE ?)
       AND "ステータス" NOT IN ('完了', 'アーカイブ済み')
     ```
     チケットID・各キーワードを `%キーワード%` の形でパラメータ化し、重複を url でユニーク化してマージ

2. **候補件数ごとの分岐**:
   - **1件**: `AskUserQuestion` で更新方針を確認（下記 3 の選択肢）
   - **複数**: `AskUserQuestion` で対象タスクを選択（`該当なし` の選択肢も含める）
   - **0件**: 「該当タスクなし」を完了報告に含めてスキップ。**新規タスクは自動作成しない**（既存タスク範囲外の作業もあるため、ゴミタスクを増やさない方針）

3. **更新方針の選択肢** (`AskUserQuestion` で提示):
   | 選択肢 | 動作 |
   |---|---|
   | 完了扱い（推奨条件付き） | ステータスを `完了` に変更、`正本リンク` に PR URL を設定、body 末尾に完了行を追記 |
   | 進捗追記のみ | ステータスが `未着手` なら `進行中` に、`進行中` はそのまま。body 末尾に進捗ブロックを追記 |
   | スキップ | 何もしない |

   `完了扱い` の推奨条件（post-merge Phase 1 の判定ヒント A と同じ）: PR がマージ済み、かつ Notion タスクの受け入れ条件（本文の記述・タスク名の全項目）を今回のPRで全て満たす。3項目まとめタスクの1項目だけ完了などの部分完了は `進捗追記のみ` を推奨。

4. **body 更新内容の準備**:

   まず `notion-fetch` で対象タスクの現在 body を取得する。取得結果を元に 4-1・4-2 の両方を並行して組み立ててから、5 でまとめて更新を実行する。

   4-1. **`## 進捗` セクション追記**:
   - フォーマット:
     ```markdown
     ## 進捗

     - YYYY-MM-DD: <Phase 1 要約> ([PR #XXXX](url), Backlog `MDMT_DV-YYY`)
     ```
   - PR がまだ無い作業段階の場合は `(PR #XXXX...)` 部分を省略
   - 既に `## 進捗` セクションが body 末尾に存在する場合は `update_content` で同セクション内の末尾に1行追記する（重複セクションを作らない）
   - `## 進捗` が無ければ `insert_content(position: end)` でセクションごと追記
   - **残タスク**節（`## 残タスク`）は自動生成しない。判断が要る内容なので、必要ならユーザーが後で書く

   4-2. **`## TODO` チェックボックス更新**:

   なぜやるか: `mediment管理` の運用方針で「タスク詳細は `## TODO` セクションに `- [ ]` で受け入れ条件を分解する」と決まっている。Linear Issue の Phase 4 と対称に、work-log 実行時に完了項目を `- [x]` へ反映することで、週次レビュー時のチェック漏れを防ぐ。

   - fetch した body から `## TODO` セクション内の未チェック行（`- [ ] ...`）を列挙
   - Phase 3（Time Block）・Phase 4（Linear Issue）と同じ基準で完了判定:
     - 会話履歴・Phase 1 要約・PR の変更内容と明確に一致 → 完了候補
     - 部分完了 / 内容不一致 / 複数候補で曖昧 → `AskUserQuestion` で確認（スキップ可）
   - 完了確定した行を `update_content` で `- [x]` に書き換え
   - `## TODO` セクションが存在しない場合はスキップ（自動生成しない、判断が要るため）
   - 全 TODO にチェックが入る結果になった場合、かつ 3 で「進捗追記のみ」が選ばれていた場合は、`AskUserQuestion` で「タスク自体を完了に上げるか」を再提案する

5. **更新実行**:
   - ステータス変更: `notion-update-page(page_id, command: "update_properties", properties: {"ステータス": "進行中"})` 等
   - 正本リンク設定: 完了扱いのときのみ `properties: {"正本リンク": "<PR URL>"}` を同時に更新
   - body 更新: 4-1（`## 進捗`）と 4-2（`## TODO` チェック）を1回の `update_content` にまとめて渡すのが理想（差分を最小化）。実装上難しければ `update_content` を2回に分けても可
   - 呼び出し順序は「プロパティ更新 → body 更新」で固定。逆にすると `update_content` の old_str と現在 body がズレる可能性がある（プロパティ更新は body に影響しないので実害は薄いが、順序を固定する原則として）

##### Gotchas

- タスク名検索は日本語を含むため LIKE の大文字小文字は影響しないが、全角/半角の差は影響する。キーワードは PR やコードで使われている表記（半角英数記号）に揃える
- `正本リンク` プロパティは URL 型なので、PR URL をそのまま渡す。空文字列を渡すとクリアされるので、更新しない場合はプロパティを渡さない
- 3項目まとめタスク（例: `セキュリティ3点の修正...`）は完了扱いにしない。粒度過大シグナルとして残るが、この skill で分割はせず、進行中を維持して body で個別進捗を明示する

## 完了報告フォーマット

通常の作業:

```
作業ログを記録しました。

- デイリーノート: 1行追記
- Time Block: 2ブロックをチェック（13:00-14:30, 14:40-15:40）
- Linear: PF-1062 にコメント追加、Todo → In Progress、本文TODO 2件を更新
```

mediphone/mediment関連作業の場合は末尾に以下を追加:

```
- Confluence稼働ログ: 2026-07-19(日) 約2.5時間 を追記、累計 約21.25時間
- Notion mediment 管理タスク: `セキュリティ3点の修正...` を進行中に更新、body に進捗追記、TODO 1件をチェック、正本リンクに PR URL を設定
```

該当タスクなし・スキップの場合はその旨（例: `Notion mediment 管理タスク: 該当タスクなし（スキップ）`）で置き換える。

## 注意事項

- Time Blockの書式が `- [ ] HH:MM - HH:MM` から崩れている場合は自動更新せず報告のみ
- 完了が曖昧なTime Blockを推測で勝手にチェックしない。必ずAskUserQuestion経由
- Linear Doneへの昇格は必ずユーザー承認を経てから実行（post-merge と同じ原則）
- Issue本文の書き換えは「会話から完了・進捗が明確に読み取れる箇所」に限定する。見出し構成や受け入れ条件の意味自体を変える推測編集はしない。曖昧なら書き換えずコメントのみで報告する
- `til` との使い分け: 学び・発見の記録は `til`、作業の進捗記録は `work-log`
- Confluence稼働ログは対外的な記録として使われるため、所要時間が異常値（Phase 5参照）のまま自動記録しない

## Gotchas

- 前倒し完了のバックフィル: スケジュール時刻より前に終わったTime Blockは、現在時刻がブロック時刻に達していなくても完了実態があればチェック対象。作業ログや会話に「完了」の証跡があれば候補に含め、AskUserQuestionで確認する。時刻だけで足切りしない
- 過去セッションの作業ログ行から完了を検知するケースがある。Phase 3では「直近の会話」だけでなく、Read済みのデイリーノート末尾の作業ログ行も照合材料として使う
- Confluence稼働ログの所要時間算出は「直近の作業ログタイムスタンプ行」を基点にするため、そのタイムスタンプが今回作業と無関係な別セッション・別作業の記録だと差分が実態からズレる。異常値ガードだけに頼らず、算出結果は完了報告で必ず提示し須藤が確認できるようにする
