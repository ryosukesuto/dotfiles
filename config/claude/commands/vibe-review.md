---
description: バイブコーディングCodexレビュー - design/plans/PRの観点別レビュー
---

# /vibe-review - Codexレビュー依頼

design.md、plans.md、またはPRをCodexにレビュー依頼します。

## レビュー対象の自動判定

以下の優先順位で対象を判定：

1. PRが存在する場合 → PRレビュー
2. plans.md が存在する場合 → plans.mdレビュー
3. design.md が存在する場合 → design.mdレビュー

手動で指定する場合は引数を使用：
- `/vibe-review design` - design.mdをレビュー
- `/vibe-review plan` - plans.mdをレビュー
- `/vibe-review pr` - PRをレビュー

## レビュールール

### 共通ルール
- レビュー往復は基本1回まで
- Major issueがある場合のみ最大2回まで許容
- 完璧化ではなくリスク洗い出しに集中

### Major / Minor の判定基準

| 分類 | 内容 | 対応 |
|------|------|------|
| Major | 目的未達成、セキュリティリスク、設計矛盾、大規模手戻り | 修正必須 |
| Minor | 曖昧な表現、命名改善、説明不足、粒度調整 | 修正任意 |

## 実行手順

### design.md レビュー

```bash
codex exec "design.mdをレビューしてください。

## レビュー対象
$(cat design.md)

## コンテキスト
[ここにProject Contextを挿入]

## レビュー観点
1. 目的整合性 - ゴールと提案が一致しているか
2. 技術的妥当性 - 実現可能か、適切なアプローチか
3. 非機能要件 - 性能・信頼性・セキュリティ・運用性
4. 影響範囲とリスク - 見落としがないか
5. 設計の一貫性とシンプルさ

## 出力形式
各観点ごとに:
- Good: 良い点
- Concern: 懸念点（Major / Minor を明記）
- Suggestion: 改善提案

最後に:
- Major: n件
- Minor: n件
- Status: 'OK to proceed with minor fixes' または 'Not ready (Major issues present)'
"
```

### plans.md レビュー

```bash
codex exec "plans.mdをレビューしてください。

## レビュー対象
$(cat plans.md)

## 対応するdesign.md
$(cat design.md)

## レビュー観点
1. 設計（design.md）との整合性
2. 変更範囲の妥当性
3. タスク分解に抜け漏れがないか
4. マイグレーション / ロールバック手順が現実的か
5. リスクと対策が実装レベルで十分か

## 出力形式
各観点ごとに:
- Good: 良い点
- Concern: 懸念点（Major / Minor を明記）
- Suggestion: 改善提案

最後に:
- Major: n件
- Minor: n件
- Status: 'OK to proceed with minor fixes' または 'Not ready (Major issues present)'
"
```

### PRレビュー

PRレビューは `/review-pr` コマンドを使用してください。
既存のCodex連携ワークフローが最適化されています。

## レビュー結果の処理

### OK to proceed with minor fixes の場合

1. Minor指摘は任意で対応
2. 次のフェーズへ進む
   - design.md → `/vibe-plan` で plans.md 作成
   - plans.md → 実装開始

### Not ready (Major issues present) の場合

1. Major指摘を修正
2. 再度 `/vibe-review` を実行（最大2回まで）
3. 2回目もMajorがある場合は人間に相談

## 出力物

Codexからのレビュー結果を整理して提示：

```markdown
## レビュー結果サマリ

### ステータス
- Major: X件
- Minor: Y件
- 判定: [OK to proceed / Not ready]

### Major Issues（修正必須）
1. [観点] 問題の内容
   - 修正案: ...

### Minor Issues（修正任意）
1. [観点] 改善提案
   - 提案: ...

### Good Points
- ...
```

## 次のステップ

| 対象 | OKの場合 | NGの場合 |
|------|----------|----------|
| design.md | `/vibe-plan` で plans.md 作成 | Major修正後に再レビュー |
| plans.md | 実装開始 | Major修正後に再レビュー |
| PR | マージ | 修正してCI確認 |
