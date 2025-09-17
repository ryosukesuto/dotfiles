# /create-pr-pro（Codex CLI用スマートPRアシスタント）

## 目的
- ローカルリポジトリの差分、テスト状況、影響範囲を整理し、即時に提出できるPR本文とレビュー観点メモを生成する。
- Claude版`/create-pr`と`/review-pr`の指針をCodex向けに統合し、ワンコマンドでPR下書きとセルフレビューをこなす。

## 前提・姿勢
- 応答は日本語。コードコメントやコマンドは必要に応じて英語可。
- 追加情報が無いと判断した場合は即出力せず、まず不足情報を箇条書きで質問する。
- 出力はMarkdown。セクション見出しや表はテンプレートに合わせて整形する。

## 実行フロー

### 0. リポジトリ状況の把握
必要に応じて以下のコマンドを実行または実行を促す：
```bash
git status
git branch --show-current
git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "No upstream"
git diff --stat
git diff --cached
git diff
```
コミット履歴が必要な場合は`git log --oneline -10`を参照。

### 1. 差分分析
- 追加/削除行数、変更ファイル数、主要ディレクトリを要約。
- 変更タイプを分類（feat / fix / refactor / chore / docs / test など）。
- 影響範囲を推定：依存モジュール、API、設定、インフラ等。
- 潜在的なBreaking Changeや移行手順が無いか確認。

### 2. テストと自動チェック
以下をプロジェクト構成に合わせて案内・実行：
```bash
if [ -f package.json ]; then
  npm test 2>&1 || yarn test 2>&1 || pnpm test 2>&1
  npm run lint 2>&1 || yarn lint 2>&1 || true
  npm run typecheck 2>&1 || npx tsc --noEmit || true
elif [ -f Cargo.toml ]; then
  cargo test
elif [ -f go.mod ]; then
  go test ./...
elif [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  pytest || python -m pytest
fi
```
テストログはサマリと失敗時の抜粋を残す。Terraform等のフォーマッタが必要な場合は適宜追加。

### 3. PR本文の構築
- 目的を一言で要約し、背景/課題/解決策を整理。
- 主要な変更点を箇条書き（技術的詳細、追加/削除機能、重要な依存関係）。
- 変更の可視化（必要ならMermaidや表）を提案。
- テスト結果・確認項目を✅チェックリスト形式で整える。
- リスク、フォローアップ、運用手順があれば明示。

### 4. セルフレビュー視点（Claude `/review-pr` の要約）
- レビューの3目的を意識：🐛短期品質、🏗️中長期品質、📢周知。
- 指摘は以下のSeverity分類を使う：
  - 🔴 `critical.must` – セキュリティ/致命的不具合/データ損失懸念
  - 🟡 `high.imo` – パフォーマンス・設計上の重大懸念
  - 🟢 `medium.imo` – 可読性・保守性など改善提案
  - 🟢 `low.nits` – 軽微な表記ゆれ・好み（原則任意）
  - 🔵 `info.q` – 質問・前提確認
- 指摘ごとに根拠、影響範囲、推奨対応を一行で添える。

## 出力テンプレート
```markdown
## 🎯 概要
- 目的: 
- 背景:

## 📝 変更内容
- 

## 📊 影響範囲
- システム/サービス:
- 利用者/ステークホルダー:
- 移行・運用:

## ✅ チェックリスト
- [ ] テストが全て成功
- [ ] Lintパス
- [ ] 型チェックパス
- [ ] ドキュメント更新済み
- [ ] Breaking Changeの説明（該当時 ✓）

## 🧪 テスト結果
<実行したコマンドと要約。失敗時は抜粋を記載>

## ⚠️ リスクとフォロー
- 

## 🧭 レビュー観点メモ
| 分類 | 内容 | 推奨対応 |
| --- | --- | --- |
| critical.must | (該当なしの場合は `該当なし`) | |
| high.imo | | |
| medium.imo | | |
| low.nits | | |
| info.q | | |
```
必要に応じてMermaidや表を追加し、ダブルチェックポイントがあれば列挙する。

## 追加の返答方針
- 進行中に不確定要素を見つけたら、仮説と検証アイデアを併記。
- 大規模変更の際は影響が大きい順に箇条書きで優先度を示す。
- ユーザーが次に実行すべきコマンド（例: `git commit`, `gh pr create`）が明確なら最後に提案する。

---
このプロンプトは`~/.codex/prompts/create-pr-pro.md`に配置する想定。Codex CLIで`/create-pr-pro`と入力すると本手順でPRドラフトとセルフレビューを生成する。
