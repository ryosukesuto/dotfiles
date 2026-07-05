---
name: vibe-implement
description: バイブコーディング実装フェーズ - Codexに実装させ、Claudeがレビューする
argument-hint: "[sprint-N]"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /vibe-implement - Codex実装 + Claudeレビュー

`plans.md` の Sprint Contract を Codex に渡して実装させ、結果を Claude がレビューします。

## 役割分担

- Codex: 実装（plans.md の指示に従ってコードを書く）
- Claude Code: レビュー（diff を読み、Sprint Contract の完了条件を満たすか検証）

レビュアーの独立性を確保するため、Claude は実装に手を出さない。差し戻しは Codex に再指示する。

## 前提条件

- `plans.md` が存在し、`/vibe-review plan` で OK 済み
- Sprint Contract に検証可能な完了条件が記述されている
- tmux セッション内または cmux ターミナル内で実行

## ワークフロー位置

```
vibe-start → vibe-review design → vibe-plan → vibe-review plan
  → [vibe-implement] ← ここ
  → vibe-review pr → マージ
```

## 引数

- `/vibe-implement` - plans.md の最初の未完了 Sprint を対象
- `/vibe-implement sprint-2` - 指定の Sprint を対象

## 実行手順

### ステップ1: 対象 Sprint の特定

1. `docs/` 配下から最新の `plans.md` を Glob で検索
2. Sprint Contract の `- [ ]` (未完了) を持つ最初の Sprint を抽出。引数指定があればそれを優先
3. 対象 Sprint の完了条件・関連タスクをユーザーに提示し、進行確認

### ステップ2: Codex ペインを確保

```bash
TMUX_MGR=~/.claude/skills/codex-review/scripts/pane-manager.sh
$TMUX_MGR ensure
```

tmux/cmux 外なら `codex-review` skill の「環境検知」節を参照して中断。

### ステップ3: Codex に実装指示を送る

`send -` で複数行プロンプトを投入。テンプレート:

```
${CLAUDE_SKILL_DIR}/scripts/pane-manager.sh send - <<'EOF'
plans.md の Sprint <N> を実装してください。

完了条件 (Sprint Contract):
<該当 Sprint の [ ] を列挙>

参照:
- 計画: <plans.md 絶対パス>
- 設計: <design.md 絶対パス>
- コーディング規約: <docs/coding-guidelines.md があれば>

制約:
- 計画外のファイルは触らない
- 既存テストを壊さない
- コミットはしない (差分のみ作成)

完了したら「実装完了」と一行返してください。
EOF
```

### ステップ4: Codex の実装を待機

ユーザーに通知:
```
Codex ペインで実装中です。完了したら「終わった」と入力してください。
その間、別タスクを進めても問題ありません。
```

Claude はユーザー入力まで待機。ポーリングは行わない（同期版）。

### ステップ5: diff レビュー

ユーザー復帰後、Claude が以下を実行:

1. `git diff` で変更内容を確認
2. `git diff --stat` でスコープ確認 (計画外ファイルがないか)
3. Sprint Contract の各完了条件を diff と突き合わせて検証
4. 必要なら関連ファイルを Read で精読

レビュー観点 (`vibe-review` の基準に揃える):

| 分類 | 内容 | 対応 |
|------|------|------|
| Major | 完了条件未達、計画外の変更、セキュリティ問題、既存機能の破壊 | 修正必須 |
| Minor | 命名改善、コメント不足、リファクタ余地 | 修正任意 |

加えて以下も Major 扱い:
- Sprint Contract の `[ ]` が diff で確認できない
- 計画 (`plans.md` の「2. 変更範囲」) 外のファイル編集
- Codex の hallucination (存在しない API、虚偽のテスト)

### ステップ6: 判定と差し戻し

#### Major あり

差し戻し指示を Codex に再送:

```
$TMUX_MGR send - <<'EOF'
レビューで以下の問題が見つかりました。修正してください。

Major:
- <指摘 1>
- <指摘 2>

修正後、再度「実装完了」と返してください。
EOF
```

ステップ5 に戻る。差し戻しは最大 2 回まで。3 回目に Major が残るなら人間に判断を仰ぐ。

#### Major なし

verify フェーズへ:

1. lint / typecheck (プロジェクトのコマンドに従う)
2. 既存テストの実行
3. Sprint Contract で「テスト追加」がある場合、新規テストの追加と pass 確認
4. すべて通れば Sprint 完了。`plans.md` の `[ ]` を `[x]` に更新するかユーザーに確認

#### Minor のみ

ユーザーに採否を確認。採用なら Codex に再指示、却下なら次フェーズへ。

### ステップ7: 出力サマリ

ユーザーに以下を報告:

```
Sprint <N> 実装結果:

完了条件:
- [x] <条件 1> (verify: <コマンド出力>)
- [x] <条件 2> (verify: <コマンド出力>)

変更ファイル:
- <ファイル一覧>

verify 結果:
- lint: <pass/fail>
- typecheck: <pass/fail>
- tests: <pass/fail>

次のアクション:
- 次の Sprint へ進む / PR 作成 (`/vibe-review pr`)
```

## レビュー時の遵守事項

- 自分が実装したコードではないので fresh eye で読む
- 「動きそうに見える」で OK を出さない。Sprint Contract の各項目を diff で逐次確認する
- Codex の主張 (コメントや返答) を鵜呑みにしない。コード本体で検証する
- 不明点は Read / Grep で裏取り。`codex-review` skill の「Codex 指摘の裏取り」節と同じ姿勢

## 差し戻しループの設計

- 1 ラウンド = Codex 実装 → Claude レビュー → (Major なら) 差し戻し指示
- 最大 2 ラウンド。3 ラウンド目に入る前にユーザーに「Codex で続行 / Claude が引き取り / 計画修正」を確認
- ラウンド間で plans.md は触らない。計画修正が必要なら `/vibe-plan` に戻る

## 失敗パターンと対処

| 症状 | 対処 |
|---|---|
| Codex が pane で固まる (15 分超) | `$TMUX_MGR capture` で状態確認。auth 切れ・rate limit なら手動復旧 |
| 計画外ファイルを大量編集 | Major 扱い。差し戻し時に「Sprint <N> のスコープのみ」を強調 |
| diff が空 (Codex が何もしていない) | プロンプト不足。Sprint Contract を再提示して再依頼 |
| Codex が「完了」と言うが完了条件未達 | Major 扱い。具体的にどの `[ ]` が満たされていないか指摘して差し戻し |

## 出力物

1. Codex によるコード変更 (uncommitted diff)
2. Claude によるレビューサマリ (Major/Minor + verify 結果)

コミットは Claude も Codex もしない。ユーザーが内容確認の上で commit を実行する。

## 次のステップ

- Sprint がまだ残る → 同 skill で次 Sprint
- 全 Sprint 完了 → PR 作成 → `/vibe-review pr`

## Gotchas

(運用しながら追記)
