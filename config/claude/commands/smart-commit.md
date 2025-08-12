# /smart-commit - インテリジェントなコミット作成

## 目的
変更内容を分析して、Conventional Commitsに準拠した適切なコミットメッセージを自動生成し、コミットします。

## 動作
1. **変更分析**:
   - `git diff --staged`と`git diff`で変更内容を詳細分析
   - 変更の種類を自動判定（機能追加、バグ修正、リファクタリング等）
   
2. **コミット分割提案**:
   - 複数の論理的変更が含まれる場合、分割を提案
   - 各変更を個別にステージング可能
   
3. **メッセージ生成**:
   - Conventional Commits形式で自動生成
   - スコープを自動検出（例: `feat(auth):`, `fix(api):`）
   - Breaking Changeの検出と記載
   - 関連Issue番号の自動リンク
   
4. **品質チェック**:
   - コミット前にlint/typecheck実行
   - テストが存在する場合は実行
   - pre-commitフックとの互換性確保
   
5. **コミット履歴整理**:
   - 必要に応じて`--amend`や`--fixup`を提案
   - きれいなコミット履歴の維持

## メッセージ形式例
```
feat(config): Claude Codeカスタムコマンド管理機能を追加

- /user:undo コマンドでGit操作の取り消しが可能に
- /user:smart-commit で高度なコミット作成をサポート
- コマンドファイルは config/claude/commands/ で管理

Closes #123
```

## 使用例
```
/smart-commit
```

## 高度な機能
- 絵文字プレフィックスのオプション対応（gitmoji）
- Co-authored-byの自動追加
- Signed-off-byの設定対応
- チームのコミット規約の学習と適用