# 🏗️ Claude Code プロジェクトテンプレート集（日本語版）

実際のプロジェクトで使えるCLAUDE.mdとワークフローのテンプレート集です。各プロジェクトタイプに最適化された設定を提供します。

## 📋 目次

1. [Webアプリケーション開発](#webアプリケーション開発)
2. [APIサーバー開発](#apiサーバー開発)
3. [データパイプライン](#データパイプライン)
4. [機械学習プロジェクト](#機械学習プロジェクト)
5. [モバイルアプリ開発](#モバイルアプリ開発)
6. [インフラストラクチャ](#インフラストラクチャ)

---

## Webアプリケーション開発

### Next.js + TypeScript プロジェクト

```markdown
# CLAUDE.md - [プロジェクト名] Webアプリケーション

## プロジェクト概要
Next.js 14、TypeScript、Tailwind CSSを使用したモダンなWebアプリケーションです。
[具体的な目的]のために[対象ユーザー]向けに開発されています。

## クイックスタート
```bash
# 依存関係のインストール
npm install

# 環境設定
cp .env.example .env.local

# 開発サーバーの起動
npm run dev

# テストの実行
npm test
```

## アーキテクチャ

### ディレクトリ構造
```
src/
├── app/                 # Next.js App Router
│   ├── (auth)/         # 認証関連のルートグループ
│   ├── (dashboard)/    # ダッシュボードルート
│   ├── api/           # APIルート
│   └── layout.tsx     # ルートレイアウト
├── components/         # Reactコンポーネント
│   ├── ui/            # 汎用UIコンポーネント
│   ├── features/      # 機能別コンポーネント
│   └── layouts/       # レイアウトコンポーネント
├── lib/               # ユーティリティ関数
│   ├── db/           # データベースユーティリティ
│   ├── auth/         # 認証関連
│   └── api/          # APIクライアント
├── hooks/             # カスタムReact Hooks
├── services/          # ビジネスロジック
├── types/             # TypeScript型定義
└── styles/           # グローバルスタイル
```

## 主要技術
- **フロントエンド**: Next.js 14, React 18, TypeScript 5
- **スタイリング**: Tailwind CSS 3.4, CSS Modules
- **状態管理**: Zustand 4.4 / React Context
- **データフェッチ**: SWR 2.2 / TanStack Query
- **フォーム**: React Hook Form 7.4 + Zod 3.22
- **テスト**: Jest 29, React Testing Library 14, Playwright 1.40
- **データベース**: PostgreSQL 15 + Prisma 5.7
- **認証**: NextAuth.js 4.24
- **デプロイ**: Vercel

## 開発ガイドライン

### コンポーネント開発
```typescript
// 必ずTypeScriptを使用
interface ComponentProps {
  title: string;
  onAction?: () => void;
}

// 関数コンポーネントを推奨
export function Component({ title, onAction }: ComponentProps) {
  return <div>{title}</div>;
}

// スタイルは同じディレクトリに配置
// Component.module.css
```

### 状態管理パターン
```typescript
// UIの状態はローカルステート
const [isOpen, setIsOpen] = useState(false);

// アプリケーションデータはグローバルステート
const { user, updateUser } = useUserStore();

// サーバー状態はSWRで管理
const { data, error, isLoading } = useSWR('/api/data', fetcher);
```

### API設計
```typescript
// app/api/users/route.ts
export async function GET(request: Request) {
  try {
    const users = await db.user.findMany();
    return NextResponse.json({ data: users });
  } catch (error) {
    return handleApiError(error);
  }
}

// 統一されたエラーハンドリング
export function handleApiError(error: unknown) {
  console.error('APIエラー:', error);
  return NextResponse.json(
    { error: '内部サーバーエラー' },
    { status: 500 }
  );
}
```

## カスタムコマンド

### `/new-page [名前]`
新しいページを必要なファイルと共に作成:
1. ルートファイル作成: `app/[名前]/page.tsx`
2. 必要に応じてレイアウト作成
3. ナビゲーションに追加
4. 初期テスト作成

### `/new-component [名前] [タイプ]`
コンポーネントのボイラープレート生成:
- タイプ: `ui`, `feature`, `layout`
- 作成物: コンポーネント、スタイル、テスト、Storybook

### `/test-all`
完全なテストスイートの実行:
1. リンティング: `npm run lint`
2. 型チェック: `npm run type-check`
3. ユニットテスト: `npm test`
4. E2Eテスト: `npm run test:e2e`

## よく行うタスク

### 新機能の追加
1. フィーチャーブランチを作成
2. コンポーネント構造を設計
3. TDDで実装
4. Storybookに追加
5. 統合テスト実施
6. ドキュメント更新

### パフォーマンス最適化
- `next/dynamic`でコード分割
- `loading.tsx`でUX向上
- `next/image`で画像最適化
- 静的コンテンツにISR有効化
- Web Vitalsでモニタリング

### デバッグのヒント
- React DevTools Profilerを使用
- Network タブでAPI呼び出し確認
- 環境変数の検証
- ビルド出力の警告確認

## セキュリティチェックリスト
- [ ] すべてのフォームで入力検証
- [ ] CSRF保護の有効化
- [ ] Content Security Policy設定
- [ ] APIレート制限実装
- [ ] 機密データの暗号化
- [ ] 定期的な依存関係更新

## デプロイプロセス
1. ローカルでテスト実行
2. プルリクエスト作成
3. Vercelでプレビューデプロイ
4. コードレビュー
5. mainブランチにマージ
6. 自動本番デプロイ

## パフォーマンス目標
- First Contentful Paint: < 1.5秒
- Time to Interactive: < 3.5秒
- Cumulative Layout Shift: < 0.1
- バンドルサイズ: < 300KB (gzip圧縮後)

## トラブルシューティング

### よくある問題
1. **ビルドエラー**: `npm run build`でエラー詳細確認
2. **型エラー**: `npm run type-check`で型チェック
3. **環境変数**: `.env.local`の設定確認
4. **キャッシュ問題**: `.next`ディレクトリ削除

### デバッグコマンド
```bash
# 依存関係の問題
npm ls [パッケージ名]

# バンドル分析
npm run analyze

# プロダクションビルドのローカル実行
npm run build && npm run start
```
```

---

## APIサーバー開発

### Node.js + Express + TypeScript

```markdown
# CLAUDE.md - [プロジェクト名] APIサーバー

## プロジェクト概要
Node.js、Express、TypeScriptで構築されたRESTful APIサーバーです。
[サービス内容]を提供し、[主要機能]を実装しています。

## アーキテクチャ

### レイヤードアーキテクチャ
```
src/
├── controllers/     # リクエストハンドラー
├── services/       # ビジネスロジック
├── repositories/   # データアクセス層
├── models/         # データモデル
├── middlewares/    # Expressミドルウェア
├── utils/          # ユーティリティ関数
├── validators/     # 入力検証
├── config/         # 設定
└── types/          # TypeScript型定義
```

## API仕様
ベースURL: `https://api.example.com/v1`

### 認証
すべてのリクエストにBearerトークンが必要:
```
Authorization: Bearer <token>
```

### エンドポイント

#### ユーザー管理
- `GET /users` - ユーザー一覧取得
- `GET /users/:id` - ユーザー詳細取得
- `POST /users` - ユーザー作成
- `PUT /users/:id` - ユーザー更新
- `DELETE /users/:id` - ユーザー削除

### エラーハンドリング
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力が無効です",
    "details": [{
      "field": "email",
      "message": "メールアドレスの形式が正しくありません"
    }]
  }
}
```

## 開発ガイドライン

### コントローラーパターン
```typescript
export class UserController {
  constructor(private userService: UserService) {}

  async getUsers(req: Request, res: Response, next: NextFunction) {
    try {
      const users = await this.userService.findAll();
      res.json({ data: users });
    } catch (error) {
      next(error);
    }
  }
}
```

### サービス層
```typescript
export class UserService {
  constructor(private userRepo: UserRepository) {}

  async findAll(): Promise<User[]> {
    // ビジネスロジックをここに実装
    return this.userRepo.findAll();
  }
}
```

### エラーハンドリングミドルウェア
```typescript
export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  logger.error(err);
  
  if (err instanceof ValidationError) {
    return res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: err.message,
        details: err.details
      }
    });
  }
  
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: '内部サーバーエラー'
    }
  });
}
```

## テスト戦略

### ユニットテスト
```typescript
describe('UserService', () => {
  it('すべてのユーザーを返すべき', async () => {
    const mockUsers = [{ id: 1, name: 'テスト' }];
    mockRepo.findAll.mockResolvedValue(mockUsers);
    
    const users = await userService.findAll();
    expect(users).toEqual(mockUsers);
  });
});
```

### 統合テスト
```typescript
describe('GET /users', () => {
  it('ユーザーリストを返すべき', async () => {
    const response = await request(app)
      .get('/users')
      .set('Authorization', `Bearer ${token}`);
      
    expect(response.status).toBe(200);
    expect(response.body.data).toBeArray();
  });
});
```

## データベーススキーマ
```sql
-- ユーザーテーブル
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- インデックス追加
CREATE INDEX idx_users_email ON users(email);
```

## パフォーマンス最適化
- データベース接続プーリング
- 頻繁なクエリのRedisキャッシュ
- リクエスト圧縮
- エンドポイント別レート制限
- インデックスによるクエリ最適化

## モニタリングとロギング
- Winstonによる構造化ログ
- DataDog/New RelicでのAPM
- ヘルスチェックエンドポイント
- メトリクス収集
- Sentryでのエラートラッキング

## デプロイ
```yaml
# docker-compose.yml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - postgres
      - redis
```

## カスタムコマンド

### `/generate-api [リソース名]`
新しいAPIリソースの完全なセットを生成:
1. モデル定義
2. リポジトリ実装
3. サービス層
4. コントローラー
5. ルーティング設定
6. テストファイル

### `/db-migrate`
データベースマイグレーションの実行:
1. マイグレーションファイル作成
2. マイグレーション実行
3. ロールバック機能

## セキュリティ考慮事項
- JWTトークンの適切な有効期限設定
- SQLインジェクション対策（パラメータ化クエリ）
- XSS対策（入力サニタイゼーション）
- CORS設定
- ヘルメットミドルウェアによるヘッダー保護

## 監視アラート
- レスポンスタイム > 1秒
- エラー率 > 5%
- CPU使用率 > 80%
- メモリ使用率 > 90%
- データベース接続エラー
```

---

## データパイプライン

### DBT + Airflow プロジェクト

```markdown
# CLAUDE.md - データパイプラインプロジェクト

## プロジェクト概要
DBTによるデータ変換とAirflowによるオーケストレーションを使用したモダンなデータパイプラインです。
[ソース]から日次[データ量]を処理し、[宛先]に配信します。

## アーキテクチャ
```
project/
├── dbt/                    # DBTプロジェクト
│   ├── models/            # SQL変換
│   │   ├── staging/       # 生データのクレンジング
│   │   ├── intermediate/  # ビジネスロジック
│   │   └── marts/         # 最終テーブル
│   ├── tests/            # データ品質テスト
│   ├── macros/           # 再利用可能なSQL
│   └── seeds/            # 静的データ
├── airflow/               # Airflow DAG
│   ├── dags/             # DAG定義
│   ├── plugins/          # カスタムオペレーター
│   └── tests/            # DAGテスト
└── scripts/              # ユーティリティスクリプト
```

## データフロー
```
ソース → ステージング → 中間層 → マート → BIツール
        ↓           ↓         ↓
      品質テスト  ビジネス  分析用
                  ルール    最適化
```

## DBTガイドライン

### モデル構成
```sql
-- models/staging/stg_orders.sql
{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'orders') }}
),

cleaned AS (
    SELECT
        id::INTEGER AS order_id,
        TRIM(status) AS order_status,
        created_at::TIMESTAMP AS created_at
    FROM source
    WHERE id IS NOT NULL
)

SELECT * FROM cleaned
```

### テスト戦略
```yaml
# models/staging/schema.yml
version: 2

models:
  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: order_status
        tests:
          - accepted_values:
              values: ['pending', 'completed', 'cancelled']
```

### マクロによる再利用性
```sql
-- macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

## Airflow設定

### DAG構造
```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

dag = DAG(
    'daily_data_pipeline',
    default_args=default_args,
    description='日次データ変換パイプライン',
    schedule='0 2 * * *',  # 毎日午前2時
    catchup=False
)

# タスク定義
extract_data = BashOperator(
    task_id='extract_data',
    bash_command='python /scripts/extract_data.py',
    dag=dag
)

run_dbt = DbtCloudRunJobOperator(
    task_id='run_dbt_models',
    job_id=12345,
    check_interval=30,
    timeout=3600,
    dag=dag
)

data_quality = BashOperator(
    task_id='run_data_quality_checks',
    bash_command='dbt test',
    dag=dag
)

# 依存関係
extract_data >> run_dbt >> data_quality
```

## データ品質フレームワーク

### 自動テスト
1. **スキーマテスト**: カラム存在、データ型
2. **参照整合性**: 外部キー検証
3. **ビジネスルール**: カスタムSQLテスト
4. **鮮度チェック**: データ新鮮度検証

### モニタリングとアラート
```yaml
# dbt_project.yml
on-run-end:
  - "{{ log_test_results() }}"
  - "{{ send_slack_notification() }}"
```

## パフォーマンス最適化
- 大規模テーブルのインクリメンタルモデル
- 適切なインデックス戦略
- パーティション枝刈り
- 複雑なクエリのマテリアライズドビュー
- クエリ結果のキャッシング

## カスタムコマンド

### `/run-pipeline [日付]`
特定日付のパイプライン実行:
1. Airflow DAGトリガー
2. 実行監視
3. 結果検証
4. 完了通知

### `/test-models [モデル名]`
特定のDBTモデルテスト:
1. SQLコンパイル
2. 開発環境で実行
3. テスト実行
4. レポート生成

### `/refresh-docs`
ドキュメント更新:
1. DBTドキュメント生成
2. データリネージ更新
3. カラム説明追加

## トラブルシューティング

### よくある問題
1. **遅いクエリ**: 実行計画を確認
2. **テスト失敗**: ソースデータ品質を検証
3. **DAG失敗**: Airflowログ確認
4. **メモリ問題**: モデルのマテリアライゼーション最適化

### デバッグクエリ
```sql
-- 行数確認
SELECT COUNT(*) FROM {{ ref('model_name') }};

-- 鮮度確認
SELECT MAX(updated_at) FROM {{ ref('model_name') }};

-- 重複検出
SELECT id, COUNT(*) 
FROM {{ ref('model_name') }}
GROUP BY id 
HAVING COUNT(*) > 1;
```

## 運用ガイドライン
- 本番環境への直接クエリは禁止
- 変更は必ず開発環境でテスト
- ドキュメントとテストは必須
- レビュー後のみマージ
```

---

## 機械学習プロジェクト

### Python ML プロジェクト

```markdown
# CLAUDE.md - 機械学習プロジェクト

## プロジェクト概要
[目的]のための機械学習プロジェクトで、[アルゴリズム]を使用しています。
[データセット]で[パフォーマンス指標]を達成しています。

## プロジェクト構造
```
project/
├── data/              # データ保存
│   ├── raw/          # 元データ
│   ├── processed/    # 処理済みデータ
│   └── external/     # 外部データセット
├── notebooks/         # Jupyterノートブック
│   ├── exploration/  # EDAノートブック
│   └── experiments/  # 実験追跡
├── src/              # ソースコード
│   ├── data/         # データ処理
│   ├── features/     # 特徴量エンジニアリング
│   ├── models/       # モデル定義
│   ├── training/     # 学習スクリプト
│   └── evaluation/   # 評価メトリクス
├── models/           # 保存されたモデル
├── reports/          # 生成されたレポート
└── tests/           # ユニットテスト
```

## MLパイプライン

### 1. データ準備
```python
# src/data/prepare.py
def prepare_dataset(raw_data_path: str) -> pd.DataFrame:
    """
    学習用データセットの準備
    
    ステップ:
    1. 生データの読み込み
    2. 欠損値の処理
    3. カテゴリ変数のエンコード
    4. 特徴量とターゲットの分離
    """
    df = pd.read_csv(raw_data_path)
    
    # 欠損値処理
    df = handle_missing_values(df)
    
    # 特徴量エンジニアリング
    df = create_features(df)
    
    return df
```

### 2. モデル学習
```python
# src/models/train.py
def train_model(
    X_train: np.ndarray,
    y_train: np.ndarray,
    model_type: str = 'xgboost'
) -> Model:
    """ハイパーパラメータチューニング付きモデル学習"""
    
    # モデル定義
    model = create_model(model_type)
    
    # ハイパーパラメータチューニング
    best_params = tune_hyperparameters(
        model, X_train, y_train
    )
    
    # 最終モデルの学習
    model.set_params(**best_params)
    model.fit(X_train, y_train)
    
    return model
```

### 3. 評価
```python
# src/evaluation/metrics.py
def evaluate_model(
    model: Model,
    X_test: np.ndarray,
    y_test: np.ndarray
) -> Dict[str, float]:
    """包括的なモデル評価"""
    
    predictions = model.predict(X_test)
    
    metrics = {
        'accuracy': accuracy_score(y_test, predictions),
        'precision': precision_score(y_test, predictions),
        'recall': recall_score(y_test, predictions),
        'f1': f1_score(y_test, predictions),
        'auc_roc': roc_auc_score(y_test, predictions)
    }
    
    return metrics
```

## 実験追跡

### MLflow統合
```python
import mlflow
import mlflow.sklearn

with mlflow.start_run():
    # パラメータログ
    mlflow.log_params({
        'model_type': 'xgboost',
        'n_estimators': 100,
        'learning_rate': 0.1
    })
    
    # モデル学習
    model = train_model(X_train, y_train)
    
    # メトリクスログ
    metrics = evaluate_model(model, X_test, y_test)
    mlflow.log_metrics(metrics)
    
    # モデルログ
    mlflow.sklearn.log_model(model, "model")
```

## 特徴量エンジニアリング

### 特徴量ストア
```python
# features/feature_store.py
class FeatureStore:
    """中央集権的な特徴量管理"""
    
    @staticmethod
    def get_numeric_features() -> List[str]:
        return ['age', 'income', 'credit_score']
    
    @staticmethod
    def get_categorical_features() -> List[str]:
        return ['gender', 'occupation', 'city']
    
    @staticmethod
    def get_feature_pipeline() -> Pipeline:
        return Pipeline([
            ('scaler', StandardScaler()),
            ('selector', SelectKBest(k=20))
        ])
```

## モデルデプロイ

### APIエンドポイント
```python
# api/predict.py
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class PredictionRequest(BaseModel):
    features: List[float]

@app.post("/predict")
async def predict(request: PredictionRequest):
    # モデルロード
    model = load_model('latest')
    
    # 予測実行
    prediction = model.predict([request.features])
    
    return {
        'prediction': prediction[0],
        'confidence': model.predict_proba([request.features])[0].max()
    }
```

## テスト戦略

### ユニットテスト
```python
# tests/test_features.py
def test_feature_engineering():
    # テストデータ
    df = pd.DataFrame({
        'age': [25, 30, 35],
        'income': [50000, 60000, 70000]
    })
    
    # 特徴量適用
    features = create_features(df)
    
    # アサーション
    assert 'age_group' in features.columns
    assert features.shape[0] == 3
```

### モデルテスト
```python
# tests/test_model.py
def test_model_prediction():
    # テストモデルロード
    model = load_test_model()
    
    # テスト入力
    X_test = [[25, 50000, 700]]
    
    # 予測
    pred = model.predict(X_test)
    
    # アサーション
    assert len(pred) == 1
    assert 0 <= pred[0] <= 1
```

## カスタムコマンド

### `/train [実験名]`
学習実験の実行:
1. データの読み込みと前処理
2. クロスバリデーションでモデル学習
3. MLflowに結果記録
4. ベストモデル保存

### `/evaluate [モデルID]`
特定モデルの評価:
1. レジストリからモデルロード
2. テストセットで実行
3. 評価レポート生成
4. 可視化作成

### `/deploy [モデルID] [環境]`
モデルを環境にデプロイ:
1. 最終テスト実行
2. Dockerコンテナ作成
3. Kubernetesにデプロイ
4. モニタリング設定

## パフォーマンス最適化
- 利用可能な場合はGPUを使用
- バッチ予測の実装
- 前処理済み特徴量のキャッシュ
- 推論用モデル量子化
- ハイパーパラメータ探索の並列化

## モニタリング
- モデルドリフト検出
- 予測レイテンシ追跡
- 特徴量重要度の変化
- データ品質モニタリング
- A/Bテストフレームワーク

## ベストプラクティス
- 実験の再現性を確保（シード固定）
- データリーケージの防止
- 適切な交差検証戦略
- モデルの解釈可能性を考慮
- 倫理的AI原則の遵守
```

---

## モバイルアプリ開発

### React Native + TypeScript

```markdown
# CLAUDE.md - モバイルアプリプロジェクト

## プロジェクト概要
React NativeとTypeScriptで構築されたクロスプラットフォームモバイルアプリケーションです。
iOSとAndroidの両方をサポートし、[主要機能]を提供します。

## プロジェクト構造
```
project/
├── src/
│   ├── components/      # 再利用可能コンポーネント
│   ├── screens/        # 画面コンポーネント
│   ├── navigation/     # ナビゲーション設定
│   ├── services/       # APIサービス
│   ├── store/          # 状態管理
│   ├── utils/          # ユーティリティ
│   └── types/          # TypeScript型
├── assets/             # 画像、フォント
├── ios/               # iOS固有
├── android/           # Android固有
└── __tests__/         # テストファイル
```

## 開発セットアップ

### 前提条件
```bash
# 依存関係インストール
npm install

# iOSセットアップ
cd ios && pod install

# Androidセットアップ
# Android StudioとEmulatorが設定済みであること
```

### アプリ実行
```bash
# iOS
npm run ios

# Android
npm run android

# 特定デバイスで実行
npm run ios -- --device "iPhone 14"
npm run android -- --deviceId emulator-5554
```

## ナビゲーション構造
```typescript
// navigation/AppNavigator.tsx
const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

function MainTabs() {
  return (
    <Tab.Navigator>
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
      <Tab.Screen name="Settings" component={SettingsScreen} />
    </Tab.Navigator>
  );
}

function AppNavigator() {
  const { isAuthenticated } = useAuth();
  
  return (
    <Stack.Navigator>
      {isAuthenticated ? (
        <Stack.Screen name="Main" component={MainTabs} />
      ) : (
        <Stack.Screen name="Auth" component={AuthStack} />
      )}
    </Stack.Navigator>
  );
}
```

## コンポーネントガイドライン

### コンポーネント構造
```typescript
// components/Button/Button.tsx
interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export function Button({
  title,
  onPress,
  variant = 'primary',
  disabled = false
}: ButtonProps) {
  return (
    <TouchableOpacity
      style={[
        styles.button,
        styles[variant],
        disabled && styles.disabled
      ]}
      onPress={onPress}
      disabled={disabled}
    >
      <Text style={styles.text}>{title}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    padding: 16,
    borderRadius: 8,
    alignItems: 'center'
  },
  primary: {
    backgroundColor: '#007AFF'
  },
  secondary: {
    backgroundColor: '#E5E5EA'
  },
  disabled: {
    opacity: 0.5
  },
  text: {
    fontSize: 16,
    fontWeight: '600'
  }
});
```

## 状態管理

### Zustandストア
```typescript
// store/userStore.ts
interface UserState {
  user: User | null;
  isLoading: boolean;
  error: string | null;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
}

export const useUserStore = create<UserState>((set) => ({
  user: null,
  isLoading: false,
  error: null,
  
  login: async (credentials) => {
    set({ isLoading: true, error: null });
    try {
      const user = await authService.login(credentials);
      set({ user, isLoading: false });
    } catch (error) {
      set({ error: error.message, isLoading: false });
    }
  },
  
  logout: () => {
    authService.logout();
    set({ user: null });
  }
}));
```

## API統合

### APIサービス
```typescript
// services/api.ts
class ApiService {
  private baseURL = Config.API_URL;
  
  private async request<T>(
    endpoint: string,
    options?: RequestInit
  ): Promise<T> {
    const response = await fetch(
      `${this.baseURL}${endpoint}`,
      {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers
        }
      }
    );
    
    if (!response.ok) {
      throw new Error(`APIエラー: ${response.status}`);
    }
    
    return response.json();
  }
  
  get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint);
  }
  
  post<T>(endpoint: string, data: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }
}

export const api = new ApiService();
```

## プラットフォーム固有コード

### プラットフォーム検出
```typescript
// utils/platform.ts
import { Platform } from 'react-native';

export const isIOS = Platform.OS === 'ios';
export const isAndroid = Platform.OS === 'android';

// プラットフォーム固有スタイル
export const platformStyles = StyleSheet.create({
  shadow: {
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
      },
      android: {
        elevation: 4,
      },
    }),
  },
});
```

## テスト戦略

### コンポーネントテスト
```typescript
// __tests__/Button.test.tsx
import { render, fireEvent } from '@testing-library/react-native';
import { Button } from '../src/components/Button';

describe('Button', () => {
  it('正しくレンダリングされる', () => {
    const { getByText } = render(
      <Button title="押してください" onPress={() => {}} />
    );
    
    expect(getByText('押してください')).toBeTruthy();
  });
  
  it('押されたときにonPressが呼ばれる', () => {
    const onPress = jest.fn();
    const { getByText } = render(
      <Button title="押してください" onPress={onPress} />
    );
    
    fireEvent.press(getByText('押してください'));
    expect(onPress).toHaveBeenCalled();
  });
});
```

## パフォーマンス最適化

### ベストプラクティス
1. 高価なコンポーネントには`React.memo`使用
2. `FlatList`の代わりに`FlashList`実装
3. 適切なサイジングで画像最適化
4. 画面の遅延読み込み
5. ブリッジコールの最小化

### パフォーマンスモニタリング
```typescript
// utils/performance.ts
import { Performance } from 'react-native-performance';

export function measureScreenLoad(screenName: string) {
  Performance.mark(`${screenName}_start`);
  
  return () => {
    Performance.mark(`${screenName}_end`);
    Performance.measure(
      screenName,
      `${screenName}_start`,
      `${screenName}_end`
    );
  };
}
```

## ビルドとデプロイ

### iOSビルド
```bash
# 開発ビルド
npm run ios:build:dev

# 本番ビルド
npm run ios:build:prod

# App Store用アーカイブ
cd ios && xcodebuild archive
```

### Androidビルド
```bash
# 開発APK
npm run android:build:dev

# 本番バンドル
npm run android:build:prod

# 署名済みAPK生成
cd android && ./gradlew assembleRelease
```

## カスタムコマンド

### `/new-screen [名前]`
ナビゲーション付き新画面作成:
1. 画面コンポーネント作成
2. ナビゲーションに追加
3. テスト作成
4. 型更新

### `/add-native-module [名前]`
ネイティブモジュール追加:
1. iOS実装作成
2. Android実装作成
3. TypeScriptインターフェース作成
4. パッケージに追加

## デバッグのヒント
- ネットワーク検査にFlipper使用
- 状態確認にReact Native Debugger
- iOS固有の問題はXcode
- AndroidログはAndroid Studio
- ChromeでリモートJSデバッグ

## リリースチェックリスト
- [ ] すべてのテストがパス
- [ ] アプリアイコンとスプラッシュ画面設定
- [ ] プッシュ通知証明書設定
- [ ] APIエンドポイントを本番に変更
- [ ] ProGuard設定（Android）
- [ ] App Transport Security設定（iOS）
```

---

## インフラストラクチャ

### Terraform + Kubernetes

```markdown
# CLAUDE.md - Infrastructure as Code

## プロジェクト概要
Terraformによるクラウドリソース管理とKubernetesによるコンテナオーケストレーションを使用したインフラ自動化プロジェクトです。

## リポジトリ構造
```
infrastructure/
├── terraform/           # Terraform設定
│   ├── environments/   # 環境別設定
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/       # 再利用可能モジュール
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── s3/
│   └── global/        # グローバルリソース
├── kubernetes/         # K8sマニフェスト
│   ├── base/          # ベース設定
│   ├── overlays/      # 環境別オーバーレイ
│   └── charts/        # Helmチャート
├── scripts/           # ユーティリティスクリプト
└── docs/             # ドキュメント
```

## Terraformガイドライン

### モジュール構造
```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-vpc"
    }
  )
}

# サブネット
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-${var.environment}-public-${count.index + 1}"
      Type = "public"
    }
  )
}
```

### 変数管理
```hcl
# environments/prod/terraform.tfvars
project     = "myapp"
environment = "prod"
region      = "ap-northeast-1"

# VPC設定
vpc_cidr = "10.0.0.0/16"
public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

# EKS設定
cluster_version = "1.28"
node_groups = {
  general = {
    desired_capacity = 3
    min_capacity     = 3
    max_capacity     = 10
    instance_types   = ["t3.medium"]
  }
}
```

### ステート管理
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Kubernetes設定

### ベースアプリケーション
```yaml
# kubernetes/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Kustomization
```yaml
# kubernetes/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

patchesStrategicMerge:
  - deployment.yaml
  - service.yaml

configMapGenerator:
  - name: app-config
    files:
      - config.json

secretGenerator:
  - name: app-secrets
    envs:
      - secrets.env

images:
  - name: myapp
    newName: 123456789.dkr.ecr.ap-northeast-1.amazonaws.com/myapp
    newTag: v1.2.3

replicas:
  - name: myapp
    count: 5
```

## GitOpsワークフロー

### ArgoCD Application
```yaml
# argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/infrastructure
    targetRevision: HEAD
    path: kubernetes/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 監視と可観測性

### Prometheusルール
```yaml
# monitoring/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-rules
spec:
  groups:
    - name: myapp
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: |
            rate(http_requests_total{status=~"5.."}[5m]) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: 高エラー率を検出
            description: "エラー率が5%を超えています"
```

## セキュリティベストプラクティス

### ネットワークポリシー
```yaml
# kubernetes/base/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-netpol
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: nginx-ingress
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
```

### シークレット管理
```bash
# Sealed Secretsの使用
kubectl create secret generic myapp-secrets \
  --from-literal=api-key=$API_KEY \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secrets.yaml
```

## 災害復旧

### バックアップ戦略
```bash
#!/bin/bash
# scripts/backup.sh

# RDSバックアップ
aws rds create-db-snapshot \
  --db-instance-identifier prod-db \
  --db-snapshot-identifier prod-db-$(date +%Y%m%d-%H%M%S)

# Kubernetesリソースバックアップ
velero backup create prod-backup-$(date +%Y%m%d) \
  --include-namespaces myapp \
  --ttl 720h

# S3データバックアップ
aws s3 sync s3://prod-data s3://prod-data-backup \
  --delete
```

## カスタムコマンド

### `/deploy [環境] [バージョン]`
アプリケーションバージョンのデプロイ:
1. Kustomizationでイメージタグ更新
2. 変更をコミット・プッシュ
3. ArgoCDが自動同期
4. デプロイ状況監視

### `/scale [環境] [レプリカ数]`
アプリケーションのスケーリング:
1. レプリカ数更新
2. 変更適用
3. Pod スケーリング確認
4. 監視アラート更新

### `/disaster-recovery [環境]`
災害復旧手順実行:
1. バックアップ作成
2. バックアップ整合性確認
3. 現在の状態を文書化
4. リストア手順テスト

## コスト最適化
- 非クリティカルワークロードにスポットインスタンス使用
- オートスケーリングポリシー実装
- 開発環境の定期シャットダウン
- リソース使用率の定期レビュー
- 安定したワークロードにリザーブドインスタンス

## コンプライアンスと監査
- 全リージョンでCloudTrail有効化
- リソースタグ戦略の実装
- 定期的なセキュリティスキャン
- 自動コンプライアンスチェック
- インフラ変更の追跡

## トラブルシューティング

### Terraform
```bash
# 状態の確認
terraform state list
terraform state show <resource>

# プランの詳細確認
terraform plan -detailed-exitcode

# 特定リソースのみ適用
terraform apply -target=aws_instance.example
```

### Kubernetes
```bash
# Pod のトラブルシューティング
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# リソース使用状況
kubectl top nodes
kubectl top pods

# ネットワーク診断
kubectl exec -it <pod-name> -- nslookup <service-name>
```
```

---

## まとめ

これらのテンプレートは、各種プロジェクトでClaude Codeを効果的に活用するための出発点となります。プロジェクトの特性に応じてカスタマイズし、チームで共有することで、AI支援開発の効果を最大化できます。

### テンプレート活用のポイント

1. **プロジェクト開始時に作成**: 最初からCLAUDE.mdを用意
2. **継続的な更新**: プロジェクトの進化に合わせて更新
3. **チームで共有**: 全員が同じコンテキストを持つ
4. **実例を含める**: 抽象的な説明より具体例
5. **カスタムコマンドの活用**: 繰り返し作業を自動化

### プロジェクトタイプ別の重要ポイント

- **Webアプリ**: パフォーマンス目標とセキュリティチェックリスト
- **API**: エラーハンドリングパターンとAPIドキュメント
- **データパイプライン**: データ品質フレームワークとモニタリング
- **機械学習**: 実験追跡とモデルライフサイクル管理
- **モバイル**: プラットフォーム固有の考慮事項
- **インフラ**: GitOpsワークフローとコスト最適化

これらのベストプラクティスを実践することで、Claude Codeとの協働がより効率的になります。