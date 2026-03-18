## Skill タイプ分類

Skillを作る前に、どのタイプに近いかを把握すると設計がブレにくい。1つのタイプにきれいに収まるSkillほど使いやすい。

### 1. Library & API Reference
社内ライブラリやCLIの正しい使い方を教えるSkill。リファレンスコードやGotchasを含む。
例: 内部課金ライブラリ、社内CLI、デザインシステム

### 2. Product Verification
コードが正しく動くかを検証するSkill。playwright、tmux等の外部ツールと組み合わせる。
例: サインアップフロー検証、チェックアウト検証、CLIインタラクティブテスト

### 3. Data Fetching & Analysis
データ・監視スタックに接続するSkill。クレデンシャル、ダッシュボードID、クエリパターンを含む。
例: ファネル分析、コホート比較、Grafanaダッシュボード参照

### 4. Business Process & Team Automation
繰り返しのワークフローを1コマンドにまとめるSkill。他のSkillやMCPと連携することが多い。
例: standup投稿、チケット作成、週次レポート

### 5. Code Scaffolding & Templates
フレームワークのボイラープレートを生成するSkill。コードだけでは表現できない自然言語の要件がある場合に有効。
例: 新規サービス/ワークフロー/ハンドラの雛形、マイグレーションファイル

### 6. Code Quality & Review
コード品質を強制・レビューするSkill。決定論的なスクリプトやツールと組み合わせると堅牢。hooksやGitHub Actionとの自動連携も可能。
例: adversarial review、コードスタイル強制、テスト方針

### 7. CI/CD & Deployment
コードのフェッチ・プッシュ・デプロイを支援するSkill。
例: PR監視・自動マージ、デプロイ＋スモークテスト、cherry-pick

### 8. Runbooks
症状（アラート、エラー、Slackスレッド）を起点に調査し、構造化レポートを出すSkill。
例: サービスデバッグ、オンコール対応、ログ相関分析

### 9. Infrastructure Operations
定常保守・運用手順のSkill。破壊的操作を含む場合のガードレールも設計に含める。
例: 孤立リソース削除、依存関係管理、コスト調査
