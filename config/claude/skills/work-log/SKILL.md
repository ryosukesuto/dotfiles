---
name: work-log
description: 作業完了をデイリーノート＋Time Blockチェック＋Linear Issueに反映。「作業ログ」「work log」「作業報告」「ワークログ」等で起動。
user-invocable: true
allowed-tools:
  - Bash(echo:*)
  - Bash(date:*)
  - Bash(git branch:*)
  - Bash(printf:*)
  - Bash(test:*)
  - Read
  - Edit
  - AskUserQuestion
  - mcp__linear-server__get_issue
  - mcp__linear-server__save_issue
  - mcp__linear-server__save_comment
---

# /work-log - 作業完了の記録

作業が一区切りついたタイミングで、3か所を同時に更新する。`til` が「学び」、`post-merge` が「PRマージ後」を担うのに対し、このスキルは「マージ前・調査のみ含む日々の作業」をカバーする。

## 更新先

1. Obsidianデイリーノート末尾（1行の作業ログ）
2. デイリーノートのTime Blockチェックボックス（完了した枠に `[x]`）
3. Linear Issue（コメント追加、必要ならステータス更新）

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
5. `save_comment(issueId: ISSUE_ID, body: SUMMARY)` でコメント追加
6. コメント本文は Phase 1 の要約をそのまま使う。Markdown可

## 完了報告フォーマット

```
作業ログを記録しました。

- デイリーノート: 1行追記
- Time Block: 2ブロックをチェック（13:00-14:30, 14:40-15:40）
- Linear: PF-1062 にコメント追加、Todo → In Progress
```

## 注意事項

- Time Blockの書式が `- [ ] HH:MM - HH:MM` から崩れている場合は自動更新せず報告のみ
- 完了が曖昧なTime Blockを推測で勝手にチェックしない。必ずAskUserQuestion経由
- Linear Doneへの昇格は必ずユーザー承認を経てから実行（post-merge と同じ原則）
- `til` との使い分け: 学び・発見の記録は `til`、作業の進捗記録は `work-log`

## Gotchas

- 前倒し完了のバックフィル: スケジュール時刻より前に終わったTime Blockは、現在時刻がブロック時刻に達していなくても完了実態があればチェック対象。作業ログや会話に「完了」の証跡があれば候補に含め、AskUserQuestionで確認する。時刻だけで足切りしない
- 過去セッションの作業ログ行から完了を検知するケースがある。Phase 3では「直近の会話」だけでなく、Read済みのデイリーノート末尾の作業ログ行も照合材料として使う
