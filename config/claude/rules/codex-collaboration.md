# Codexとの協業

Codexは専門的な調査・分析・検証タスクで活用し、Claude Codeは実装・修正を担当する。

## Codexを使う場面
- 調査・分析: コードベース分析、依存関係調査、アーキテクチャ理解
- ベストプラクティス確認: セキュリティガイドライン、推奨手法
- 技術検証: ツール・ライブラリ評価、実装方法の比較検討
- デバッグ支援: エラー原因の深掘り、ログ解析
- 設計レビュー: アーキテクチャ妥当性確認、代替案の検討

## 前提条件
- `codex`コマンドがインストールされていること（`npm install -g @openai/codex`）
- tmux-codex-review使用時はtmuxセッション内で実行すること

## 基本的な使い方

環境に応じて自動的に切り替え:
- tmux内: tmux-codex-review（右ペインでインタラクティブに対話）
- tmux外: codex exec（単発実行）

### tmux内: tmux-codex-review

```bash
TMUX_MGR=~/.claude/skills/tmux-codex-review/scripts/tmux-manager.sh

$TMUX_MGR ensure                           # Codexペインを作成
$TMUX_MGR send "git diffをレビューして"     # メッセージ送信
$TMUX_MGR wait_response 180 && $TMUX_MGR capture 200  # 応答待機とキャプチャ
```

### tmux外: codex exec

```bash
codex exec "このリポジトリのテスト戦略を分析してください"
```

## 協業ワークフロー: 3つのレビューフェーズ

| フェーズ | タイミング | 必須度 | 対象 |
|---------|-----------|--------|------|
| 実装前 | 実装開始前 | △ | 計画・TODO・設計 |
| コミット前 | テスト通過後 | △ | git diff（ローカル変更） |
| PR作成前 | PR作成後 | ○ | gh pr diff（PR差分） |

必須とするケース: セキュリティ関連、インフラ変更、本番影響が大きい変更

## 役割分担の原則
- Codex: "考える"、"調べる"、"評価する"
- Claude Code: "実装する"、"修正する"、"実行する"

---

# バイブコーディング

設計から実装・PRまでを一貫して高品質に進めるためのワークフロー。

## 役割分担
- Claude Code: 設計・実装・PR作成（実行者）
- Codex: レビュー・リスク洗い出し（検証者）

## ドキュメント構成
```
docs/
├── coding-guidelines.md   # コーディング規約
├── design.md              # 設計書
├── plans.md               # 実装計画
└── archive/               # 完了したドキュメント
```

## ワークフロー
```
/vibe-start → design.md → /vibe-review → Codexレビュー
    → /vibe-plan → plans.md → /vibe-review
    → 実装 → 自己レビュー → PR作成 → /review-pr
```

## レビュールール
- 往復は基本1回、Major時のみ最大2回
- Major: 目的未達成、セキュリティリスク、設計矛盾 → 修正必須
- Minor: 曖昧な表現、命名改善、説明不足 → 修正任意

## 人間が握るポイント
- CodexのOKは「リスク棚卸完了」であり出荷基準ではない
- 最終判断は必ず人間、意思決定はAIに委ねない
