# 🚀 Claude Code 開発環境構築完全ガイド

このガイドでは、Claude Codeを使用した効率的な開発環境の構築方法と、AIアシスト開発のベストプラクティスを解説します。

## 📋 目次

1. [はじめに](#はじめに)
2. [初期セットアップ](#初期セットアップ)
3. [CLAUDE.mdの設計](#claudemdの設計)
4. [プロジェクト構造の最適化](#プロジェクト構造の最適化)
5. [カスタムワークフローの定義](#カスタムワークフローの定義)
6. [効率的な開発フロー](#効率的な開発フロー)
7. [コンテキスト管理のベストプラクティス](#コンテキスト管理のベストプラクティス)
8. [MCP（Model Context Protocol）の活用](#mcpmodel-context-protocolの活用)
9. [チーム開発での活用](#チーム開発での活用)
10. [パフォーマンス最適化](#パフォーマンス最適化)
11. [トラブルシューティング](#トラブルシューティング)

---

## はじめに

Claude Codeは、AIアシスタントと協調して開発を行うための強力なツールです。適切にセットアップすることで、開発効率を大幅に向上させることができます。

### 🎯 このガイドの対象者
- Claude Codeを初めて使用する開発者
- AIアシスト開発の効率を最大化したいチーム
- 既存プロジェクトにClaude Codeを導入したい方

---

## 初期セットアップ

### 1. Claude Codeのインストール

```bash
# NPMを使用したグローバルインストール
npm install -g @anthropic-ai/claude-code

# または、Homebrewを使用（macOS）
brew install claude-code

# インストール確認
claude --version
```

### 2. 認証設定

```bash
# Claude Codeにログイン
claude login

# APIキーを使用する場合
export CLAUDE_API_KEY="your-api-key"
```

### 3. エディタ統合（推奨）

```bash
# VS Code拡張機能のインストール
code --install-extension anthropic.claude-code

# Vim/Neovimプラグイン
# ~/.vimrc または init.vim に追加
Plug 'anthropic/claude-code.nvim'
```

---

## CLAUDE.mdの設計

CLAUDE.mdは、プロジェクト固有の情報をClaude Codeに伝えるための重要なファイルです。

### 基本構造テンプレート

```markdown
# CLAUDE.md

## Project Overview
[プロジェクトの概要と目的を記載]

## Architecture
[システムアーキテクチャの説明]

## Key Technologies
- Language: [使用言語とバージョン]
- Framework: [フレームワークとバージョン]
- Database: [データベース情報]
- External Services: [外部サービス一覧]

## Development Guidelines
### Code Style
[コーディング規約とスタイルガイド]

### Testing Strategy
[テスト方針と実行方法]

### Security Considerations
[セキュリティ上の注意点]

## Custom Commands
[プロジェクト固有のコマンド定義]

## Common Tasks
[よく行うタスクとその手順]

## Troubleshooting
[既知の問題と解決方法]
```

### 実践的なCLAUDE.md例

```markdown
# CLAUDE.md - E-Commerce Platform

## Project Overview
This is a modern e-commerce platform built with Next.js and TypeScript.
The system handles product management, user authentication, and payment processing.

## Architecture
```
src/
├── app/           # Next.js 14 App Router
├── components/    # Reusable React components
├── lib/          # Utility functions and API clients
├── services/     # Business logic layer
└── types/        # TypeScript type definitions
```

## Key Technologies
- Language: TypeScript 5.3
- Framework: Next.js 14 (App Router)
- Database: PostgreSQL with Prisma ORM
- Authentication: NextAuth.js
- Payment: Stripe API
- Testing: Jest + React Testing Library

## Development Guidelines

### Code Style
- Use functional components with hooks
- Prefer named exports over default exports
- Follow Airbnb ESLint configuration
- Use absolute imports from '@/' prefix

### Testing Strategy
- Unit tests for all utility functions
- Integration tests for API routes
- E2E tests for critical user flows
- Minimum 80% code coverage

### Security Considerations
- Never commit .env files
- Use environment variables for all secrets
- Validate all user inputs
- Implement CSRF protection

## Custom Commands

### `/setup-dev`
Initialize development environment:
1. Install dependencies: `npm install`
2. Set up database: `npm run db:setup`
3. Seed test data: `npm run db:seed`
4. Start dev server: `npm run dev`

### `/add-feature [name]`
Create new feature with boilerplate:
1. Generate component structure
2. Create corresponding tests
3. Update routing configuration
4. Add to feature documentation

### `/deploy-preview`
Deploy to preview environment:
1. Run tests: `npm test`
2. Build application: `npm run build`
3. Deploy to Vercel preview
4. Run E2E tests on preview URL

## Common Tasks

### Adding a New Product Feature
1. Create product model in `prisma/schema.prisma`
2. Run migration: `npm run db:migrate`
3. Generate types: `npm run generate:types`
4. Implement API route in `app/api/products/`
5. Create UI components in `components/products/`

### Debugging Payment Issues
1. Check Stripe webhook logs
2. Verify environment variables
3. Test with Stripe CLI: `stripe listen --forward-to localhost:3000/api/webhooks/stripe`
4. Check payment service logs

## API Patterns

### Data Fetching
```typescript
// Always use server components for initial data
async function ProductList() {
  const products = await fetchProducts()
  return <ProductGrid products={products} />
}

// Use SWR for client-side updates
const { data, error } = useSWR('/api/products', fetcher)
```

### Error Handling
```typescript
// Consistent error response format
return NextResponse.json(
  { error: 'Product not found', code: 'PRODUCT_NOT_FOUND' },
  { status: 404 }
)
```

## Performance Considerations
- Use Next.js Image component for all images
- Implement lazy loading for product lists
- Cache API responses with proper headers
- Use database indexes for frequent queries

## Deployment Checklist
- [ ] All tests passing
- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] Static assets optimized
- [ ] Security headers configured
- [ ] Monitoring alerts set up
```

---

## プロジェクト構造の最適化

### 推奨ディレクトリ構造

```
project-root/
├── .claude/              # Claude Code設定
│   ├── commands/         # カスタムコマンド定義
│   ├── templates/        # コード生成テンプレート
│   └── workflows/        # ワークフロー定義
├── .workplace/           # タスク管理
│   ├── current/          # 現在のタスク
│   ├── completed/        # 完了タスク
│   └── retrospectives/   # 振り返り記録
├── docs/                 # プロジェクトドキュメント
│   ├── architecture/     # アーキテクチャ設計書
│   ├── api/              # API仕様書
│   └── guides/           # 開発ガイド
├── sandbox/              # 実験・検証用
└── CLAUDE.md            # プロジェクト設定
```

### .claude/commands/example.yml

```yaml
name: create-component
description: Create a new React component with tests
parameters:
  - name: componentName
    required: true
    description: Name of the component to create
  - name: type
    required: false
    default: functional
    options: [functional, class]
steps:
  - create_file: "src/components/{{componentName}}/index.tsx"
    template: component.tsx.hbs
  - create_file: "src/components/{{componentName}}/{{componentName}}.test.tsx"
    template: component.test.tsx.hbs
  - create_file: "src/components/{{componentName}}/{{componentName}}.module.css"
    template: component.module.css.hbs
  - append_to_file: "src/components/index.ts"
    content: "export * from './{{componentName}}'"
```

---

## カスタムワークフローの定義

### 開発ワークフローテンプレート

```yaml
# .claude/workflows/feature-development.yml
name: Feature Development Workflow
description: Standard workflow for developing new features
phases:
  - name: Initialize
    steps:
      - Create feature branch
      - Set up task tracking
      - Review requirements
    
  - name: Design
    steps:
      - Create technical design
      - Review with team
      - Update CLAUDE.md if needed
    
  - name: Implement
    steps:
      - Write unit tests first (TDD)
      - Implement feature code
      - Ensure code coverage > 80%
    
  - name: Test
    steps:
      - Run unit tests
      - Run integration tests
      - Manual testing
    
  - name: Review
    steps:
      - Self code review
      - Create pull request
      - Address feedback
    
  - name: Deploy
    steps:
      - Merge to main
      - Deploy to staging
      - Verify in staging
      - Deploy to production
    
  - name: Retrospect
    steps:
      - Document learnings
      - Update best practices
      - Share with team
```

### タスク管理テンプレート

```markdown
# .workplace/current/TASK-001.md

## Task: Implement User Authentication

### Context
Users need to be able to create accounts and log in securely.

### Requirements
- [ ] Email/password authentication
- [ ] OAuth integration (Google, GitHub)
- [ ] Password reset functionality
- [ ] Session management
- [ ] Remember me option

### Technical Approach
1. Use NextAuth.js for authentication
2. PostgreSQL for user storage
3. JWT for session tokens
4. SendGrid for email delivery

### Progress Log
- 2024-01-15: Set up NextAuth configuration
- 2024-01-16: Implemented email/password provider
- 2024-01-17: Added Google OAuth

### Blockers
- Need SendGrid API key from DevOps team

### Notes
- Consider adding 2FA in future iteration
- Review OWASP authentication guidelines
```

---

## 効率的な開発フロー

### 1. 朝のセットアップルーチン

```bash
# 開発環境の起動スクリプト
#!/bin/bash
# .claude/scripts/start-day.sh

echo "🌅 Starting development day..."

# 最新の変更を取得
git pull origin main

# 依存関係の更新
npm install

# データベースのマイグレーション
npm run db:migrate

# 開発サーバーの起動
npm run dev &

# テストの監視モード
npm run test:watch &

# Claude Codeセッション開始
claude chat --context ./CLAUDE.md

echo "✅ Development environment ready!"
```

### 2. 機能開発フロー

```markdown
## Feature Development Checklist

### Planning Phase
- [ ] Review requirements in issue/ticket
- [ ] Break down into subtasks
- [ ] Estimate time needed
- [ ] Identify dependencies

### Implementation Phase
- [ ] Create feature branch: `git checkout -b feature/[name]`
- [ ] Write tests first (TDD approach)
- [ ] Implement minimum viable solution
- [ ] Refactor for quality
- [ ] Update documentation

### Testing Phase
- [ ] Run unit tests: `npm test`
- [ ] Run integration tests: `npm run test:integration`
- [ ] Manual testing in development
- [ ] Cross-browser testing if UI changes

### Review Phase
- [ ] Self-review with checklist
- [ ] Run linter: `npm run lint`
- [ ] Check test coverage: `npm run coverage`
- [ ] Create detailed PR description
- [ ] Request code review

### Deployment Phase
- [ ] Merge PR after approval
- [ ] Monitor CI/CD pipeline
- [ ] Verify in staging environment
- [ ] Create release notes
- [ ] Deploy to production
```

### 3. Claude Codeとの効果的な対話

```markdown
## Effective Claude Code Prompts

### 良い例 ✅

"I need to implement a shopping cart feature. The requirements are:
- Add/remove items
- Update quantities
- Calculate totals with tax
- Persist cart in localStorage
Please follow our existing patterns in src/components/cart/"

### 悪い例 ❌

"Make a shopping cart"

### コンテキストを含むプロンプト例

"Based on our authentication system in src/lib/auth/, 
I need to add role-based access control. 
Admin users should access /admin routes, 
regular users only /dashboard. 
Follow our existing middleware pattern."
```

---

## コンテキスト管理のベストプラクティス

### 1. コンテキストの階層化

```
グローバルコンテキスト (CLAUDE.md)
    ↓
プロジェクトコンテキスト (.claude/project.md)
    ↓
機能コンテキスト (feature/README.md)
    ↓
タスクコンテキスト (.workplace/current/task.md)
```

### 2. コンテキストファイルの例

```markdown
# .claude/contexts/api-development.md

## API Development Context

### Base URL Structure
- Development: http://localhost:3000/api
- Staging: https://staging.example.com/api
- Production: https://api.example.com

### Authentication Headers
```
Authorization: Bearer [JWT_TOKEN]
X-API-Version: 2.0
Content-Type: application/json
```

### Common Response Formats

#### Success Response
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "2.0"
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [ ... ]
  }
}
```

### Rate Limiting
- 100 requests per minute for authenticated users
- 20 requests per minute for anonymous users
- Headers: X-RateLimit-Limit, X-RateLimit-Remaining
```

### 3. 動的コンテキストの管理

```typescript
// .claude/scripts/update-context.ts

import { readFileSync, writeFileSync } from 'fs';
import { execSync } from 'child_process';

function updateContext() {
  const context = {
    lastUpdated: new Date().toISOString(),
    gitBranch: execSync('git branch --show-current').toString().trim(),
    uncommittedChanges: execSync('git status --short').toString().split('\n').length - 1,
    testStatus: getTestStatus(),
    coverage: getCoveragePercentage(),
    dependencies: getOutdatedDependencies(),
  };

  writeFileSync('.claude/dynamic-context.json', JSON.stringify(context, null, 2));
}

function getTestStatus() {
  try {
    execSync('npm test -- --passWithNoTests');
    return 'passing';
  } catch {
    return 'failing';
  }
}

// 定期的にコンテキストを更新
setInterval(updateContext, 5 * 60 * 1000); // 5分ごと
```

---

## MCP（Model Context Protocol）の活用

### 1. MCP Serverのセットアップ

```typescript
// mcp-server/index.ts
import { MCPServer } from '@anthropic/mcp';

const server = new MCPServer({
  name: 'project-knowledge-base',
  version: '1.0.0',
  description: 'Project-specific knowledge and tools',
});

// カスタムツールの登録
server.registerTool({
  name: 'search_codebase',
  description: 'Search for code patterns in the project',
  parameters: {
    pattern: { type: 'string', required: true },
    fileTypes: { type: 'array', items: { type: 'string' } },
  },
  handler: async ({ pattern, fileTypes }) => {
    // 実装
  },
});

// ナレッジベースの登録
server.registerKnowledge({
  name: 'architecture_decisions',
  description: 'Architectural Decision Records (ADRs)',
  loader: async () => {
    // ADRsを読み込んで返す
  },
});

server.start();
```

### 2. MCP設定ファイル

```json
// .claude/mcp-config.json
{
  "servers": [
    {
      "name": "project-knowledge-base",
      "url": "http://localhost:8080",
      "tools": ["search_codebase", "run_tests", "check_coverage"],
      "knowledge": ["architecture_decisions", "api_documentation"]
    },
    {
      "name": "external-services",
      "url": "http://localhost:8081",
      "tools": ["check_service_status", "view_logs"],
      "credentials": {
        "type": "env",
        "key": "MCP_EXTERNAL_TOKEN"
      }
    }
  ]
}
```

---

## チーム開発での活用

### 1. チーム用CLAUDE.md

```markdown
# Team Development Guidelines

## Communication Protocols
- Daily standup notes in `.workplace/standups/`
- Architecture decisions in `docs/adr/`
- Code review checklist in `.github/pull_request_template.md`

## Knowledge Sharing
- Weekly tech talks recorded in `docs/tech-talks/`
- Pair programming sessions logged in `.workplace/pairing/`
- Learnings documented in `.workplace/retrospectives/`

## AI Assistant Guidelines
- Always provide context when asking Claude Code for help
- Share successful prompts in `docs/prompt-library/`
- Document AI-assisted solutions with `AI-Assisted: ` prefix in commits

## Code Review with AI
1. Run AI pre-review: `claude review --pr [number]`
2. Address AI suggestions
3. Request human review
4. Document any overridden AI suggestions
```

### 2. AIアシスタント管理者（AAM）の役割

```markdown
# AI Assistant Manager (AAM) Responsibilities

## Daily Tasks
- [ ] Review AI-generated code quality metrics
- [ ] Update CLAUDE.md with new patterns
- [ ] Curate prompt library
- [ ] Monitor AI usage statistics

## Weekly Tasks
- [ ] Analyze AI assistance effectiveness
- [ ] Share best practices with team
- [ ] Update AI guidelines based on learnings
- [ ] Review and optimize MCP configurations

## Metrics to Track
- Time saved per issue
- AI suggestion acceptance rate
- Code quality improvements
- Bug reduction percentage

## Tools
- Dashboard: `/admin/ai-metrics`
- Reports: `.workplace/reports/ai-weekly/`
- Feedback: `.workplace/feedback/ai-assistance/`
```

---

## パフォーマンス最適化

### 1. Claude Codeセッションの最適化

```bash
# .claude/optimize-session.sh

#!/bin/bash

# 不要なファイルを除外
cat > .claudeignore << EOF
node_modules/
.next/
dist/
coverage/
*.log
*.tmp
.git/objects/
EOF

# コンテキストサイズの確認
echo "Checking context size..."
find . -type f -name "*.ts" -o -name "*.tsx" | 
  grep -v node_modules | 
  xargs wc -l | 
  tail -1

# 大きなファイルの特定
echo "Large files that might affect performance:"
find . -type f -size +100k -not -path "./node_modules/*" -not -path "./.git/*"

# 推奨: コンテキストの分割
echo "Consider splitting context into:"
echo "- Core functionality: Include always"
echo "- Feature-specific: Include when needed"
echo "- Historical: Exclude unless debugging"
```

### 2. レスポンス時間の改善

```typescript
// .claude/performance-config.ts

export const performanceConfig = {
  // キャッシュ設定
  cache: {
    enabled: true,
    ttl: 3600, // 1時間
    maxSize: '100MB',
  },
  
  // コンテキストウィンドウ管理
  contextWindow: {
    maxTokens: 100000,
    priorityFiles: [
      'CLAUDE.md',
      'src/index.ts',
      'package.json',
    ],
    excludePatterns: [
      '*.test.ts',
      '*.spec.ts',
      '*.md',
    ],
  },
  
  // 応答の最適化
  response: {
    streamingEnabled: true,
    maxResponseLength: 4000,
    codeBlockLanguage: 'typescript',
  },
};
```

### 3. メモリ使用量の管理

```typescript
// .claude/scripts/memory-monitor.ts

import { performance } from 'perf_hooks';

class MemoryMonitor {
  private baseline: number;
  
  constructor() {
    this.baseline = process.memoryUsage().heapUsed;
  }
  
  checkMemory(operation: string) {
    const current = process.memoryUsage().heapUsed;
    const diff = current - this.baseline;
    
    console.log(`Memory after ${operation}: ${Math.round(current / 1024 / 1024)}MB`);
    console.log(`Difference: ${diff > 0 ? '+' : ''}${Math.round(diff / 1024 / 1024)}MB`);
    
    if (diff > 500 * 1024 * 1024) { // 500MB increase
      console.warn('⚠️ High memory usage detected. Consider restarting Claude Code session.');
    }
  }
  
  reset() {
    if (global.gc) {
      global.gc();
      this.baseline = process.memoryUsage().heapUsed;
    }
  }
}

export const memoryMonitor = new MemoryMonitor();
```

---

## トラブルシューティング

### よくある問題と解決方法

#### 1. Claude Codeが応答しない

```bash
# セッションのリセット
claude reset

# キャッシュのクリア
rm -rf ~/.claude/cache/

# 詳細ログの確認
claude chat --verbose --log-level debug
```

#### 2. コンテキストが大きすぎるエラー

```bash
# コンテキストサイズの確認
claude context --analyze

# 特定のディレクトリのみを含める
claude chat --include "src/" --exclude "tests/"

# .claudeignore の活用
echo "*.test.ts" >> .claudeignore
echo "docs/" >> .claudeignore
```

#### 3. 不正確な提案が多い

```markdown
## Improving Claude Code Accuracy

1. **Update CLAUDE.md regularly**
   - Keep technology versions current
   - Document recent architectural changes
   - Add examples of preferred patterns

2. **Provide specific context**
   ```
   Bad: "Fix the bug in authentication"
   Good: "Fix the JWT token expiration bug in src/lib/auth.ts line 45"
   ```

3. **Use consistent patterns**
   - Maintain consistent code style
   - Use clear naming conventions
   - Document exceptions clearly
```

### デバッグモード

```bash
# デバッグモードで実行
claude chat --debug

# 特定の機能のデバッグ
CLAUDE_DEBUG=mcp,context claude chat

# パフォーマンスプロファイリング
claude chat --profile > performance.log
```

---

## まとめ

Claude Codeを効果的に活用するためのキーポイント：

1. **適切な初期設定**: CLAUDE.mdを充実させ、プロジェクト構造を整理
2. **コンテキスト管理**: 階層的にコンテキストを管理し、必要な情報を適切に提供
3. **ワークフローの確立**: チームで共有できる標準的な開発フローを定義
4. **継続的な改善**: レトロスペクティブを通じて、AI活用方法を改善
5. **パフォーマンス監視**: メモリ使用量とレスポンス時間を定期的にチェック

これらのベストプラクティスを実践することで、Claude Codeを使った開発効率を最大化できます。

---

## 関連リソース

- [Claude Code公式ドキュメント](https://docs.anthropic.com/claude-code)
- [MCP仕様](https://github.com/anthropics/mcp)
- [コミュニティフォーラム](https://community.anthropic.com)
- [サンプルプロジェクト](https://github.com/anthropics/claude-code-examples)

## 更新履歴

- 2024-01-20: 初版作成
- 2024-01-21: MCP設定セクション追加
- 2024-01-22: トラブルシューティング拡充

---

*このドキュメントは定期的に更新されます。最新版は[こちら](https://github.com/yourusername/claude-code-guide)でご確認ください。*