# 🏗️ Claude Code プロジェクトテンプレート集

実際のプロジェクトで使えるCLAUDE.mdとワークフローのテンプレート集です。

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
# CLAUDE.md - [Project Name] Web Application

## Project Overview
This is a modern web application built with Next.js 14, TypeScript, and Tailwind CSS.
The application serves [describe purpose] for [target audience].

## Quick Start
```bash
# Install dependencies
npm install

# Set up environment
cp .env.example .env.local

# Run development server
npm run dev

# Run tests
npm test
```

## Architecture

### Directory Structure
```
src/
├── app/                 # Next.js App Router
│   ├── (auth)/         # Auth group routes
│   ├── (dashboard)/    # Dashboard routes
│   ├── api/           # API routes
│   └── layout.tsx     # Root layout
├── components/         # React components
│   ├── ui/            # Generic UI components
│   ├── features/      # Feature-specific components
│   └── layouts/       # Layout components
├── lib/               # Utility functions
│   ├── db/           # Database utilities
│   ├── auth/         # Authentication
│   └── api/          # API clients
├── hooks/             # Custom React hooks
├── services/          # Business logic
├── types/             # TypeScript types
└── styles/           # Global styles
```

## Key Technologies
- **Frontend**: Next.js 14, React 18, TypeScript 5
- **Styling**: Tailwind CSS, CSS Modules
- **State Management**: Zustand / React Context
- **Data Fetching**: SWR / React Query
- **Forms**: React Hook Form + Zod
- **Testing**: Jest, React Testing Library, Playwright
- **Database**: PostgreSQL + Prisma ORM
- **Authentication**: NextAuth.js
- **Deployment**: Vercel

## Development Guidelines

### Component Development
```typescript
// Always use TypeScript
interface ComponentProps {
  title: string;
  onAction?: () => void;
}

// Prefer function components
export function Component({ title, onAction }: ComponentProps) {
  return <div>{title}</div>;
}

// Co-locate styles
// Component.module.css
```

### State Management Patterns
```typescript
// Local state for UI
const [isOpen, setIsOpen] = useState(false);

// Global state for app data
const { user, updateUser } = useUserStore();

// Server state with SWR
const { data, error, isLoading } = useSWR('/api/data', fetcher);
```

### API Design
```typescript
// app/api/users/route.ts
export async function GET(request: Request) {
  // Implementation
  return NextResponse.json({ users });
}

// Consistent error handling
export function handleApiError(error: unknown) {
  console.error('API Error:', error);
  return NextResponse.json(
    { error: 'Internal Server Error' },
    { status: 500 }
  );
}
```

## Custom Commands

### `/new-page [name]`
Create a new page with all necessary files:
1. Create route file: `app/[name]/page.tsx`
2. Create layout if needed
3. Add to navigation
4. Create initial tests

### `/new-component [name] [type]`
Generate component boilerplate:
- Types: `ui`, `feature`, `layout`
- Creates: Component, styles, tests, Storybook story

### `/test-all`
Run complete test suite:
1. Linting: `npm run lint`
2. Type checking: `npm run type-check`
3. Unit tests: `npm test`
4. E2E tests: `npm run test:e2e`

## Common Tasks

### Adding a New Feature
1. Create feature branch
2. Design component structure
3. Implement with TDD
4. Add to Storybook
5. Integration testing
6. Update documentation

### Performance Optimization
- Use `next/dynamic` for code splitting
- Implement `loading.tsx` for better UX
- Optimize images with `next/image`
- Enable ISR for static content
- Monitor with Web Vitals

### Debugging Tips
- Use React DevTools Profiler
- Check Network tab for API calls
- Verify environment variables
- Check build output for warnings

## Security Checklist
- [ ] Input validation on all forms
- [ ] CSRF protection enabled
- [ ] Content Security Policy configured
- [ ] API rate limiting implemented
- [ ] Sensitive data encrypted
- [ ] Regular dependency updates

## Deployment Process
1. Run tests locally
2. Create pull request
3. Preview deployment on Vercel
4. Code review
5. Merge to main
6. Automatic production deployment

## Performance Targets
- First Contentful Paint: < 1.5s
- Time to Interactive: < 3.5s
- Cumulative Layout Shift: < 0.1
- Bundle size: < 300KB (gzipped)
```

---

## APIサーバー開発

### Node.js + Express + TypeScript

```markdown
# CLAUDE.md - [Project Name] API Server

## Project Overview
RESTful API server built with Node.js, Express, and TypeScript.
Provides [services] with [key features].

## Architecture

### Layered Architecture
```
src/
├── controllers/     # Request handlers
├── services/       # Business logic
├── repositories/   # Data access layer
├── models/         # Data models
├── middlewares/    # Express middlewares
├── utils/          # Utility functions
├── validators/     # Input validation
├── config/         # Configuration
└── types/          # TypeScript types
```

## API Documentation
Base URL: `https://api.example.com/v1`

### Authentication
All requests require Bearer token:
```
Authorization: Bearer <token>
```

### Endpoints

#### Users
- `GET /users` - List users
- `GET /users/:id` - Get user
- `POST /users` - Create user
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user

### Error Handling
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [{
      "field": "email",
      "message": "Invalid email format"
    }]
  }
}
```

## Development Guidelines

### Controller Pattern
```typescript
export class UserController {
  constructor(private userService: UserService) {}

  async getUsers(req: Request, res: Response) {
    try {
      const users = await this.userService.findAll();
      res.json({ data: users });
    } catch (error) {
      next(error);
    }
  }
}
```

### Service Layer
```typescript
export class UserService {
  constructor(private userRepo: UserRepository) {}

  async findAll(): Promise<User[]> {
    // Business logic here
    return this.userRepo.findAll();
  }
}
```

### Error Handling Middleware
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
      message: 'Internal server error'
    }
  });
}
```

## Testing Strategy

### Unit Tests
```typescript
describe('UserService', () => {
  it('should return all users', async () => {
    const mockUsers = [{ id: 1, name: 'Test' }];
    mockRepo.findAll.mockResolvedValue(mockUsers);
    
    const users = await userService.findAll();
    expect(users).toEqual(mockUsers);
  });
});
```

### Integration Tests
```typescript
describe('GET /users', () => {
  it('should return users list', async () => {
    const response = await request(app)
      .get('/users')
      .set('Authorization', `Bearer ${token}`);
      
    expect(response.status).toBe(200);
    expect(response.body.data).toBeArray();
  });
});
```

## Database Schema
```sql
-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes
CREATE INDEX idx_users_email ON users(email);
```

## Performance Optimization
- Database connection pooling
- Redis caching for frequent queries
- Request compression
- Rate limiting per endpoint
- Query optimization with indexes

## Monitoring & Logging
- Structured logging with Winston
- APM with DataDog/New Relic
- Health check endpoint
- Metrics collection
- Error tracking with Sentry

## Deployment
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
```

---

## データパイプライン

### DBT + Airflow プロジェクト

```markdown
# CLAUDE.md - Data Pipeline Project

## Project Overview
Modern data pipeline using DBT for transformations and Airflow for orchestration.
Processes [data volume] daily from [sources] to [destination].

## Architecture
```
project/
├── dbt/                    # DBT project
│   ├── models/            # SQL transformations
│   │   ├── staging/       # Raw data cleaning
│   │   ├── intermediate/  # Business logic
│   │   └── marts/         # Final tables
│   ├── tests/            # Data quality tests
│   ├── macros/           # Reusable SQL
│   └── seeds/            # Static data
├── airflow/               # Airflow DAGs
│   ├── dags/             # DAG definitions
│   ├── plugins/          # Custom operators
│   └── tests/            # DAG tests
└── scripts/              # Utility scripts
```

## Data Flow
```
Sources → Staging → Intermediate → Marts → BI Tools
         ↓         ↓              ↓
      Quality   Business      Analytics
       Tests     Rules         Ready
```

## DBT Guidelines

### Model Organization
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

### Testing Strategy
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

### Macros for Reusability
```sql
-- macros/generate_alias_name.sql
{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {%- if custom_alias_name is none -%}
        {{ node.name }}
    {%- else -%}
        {{ custom_alias_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

## Airflow Configuration

### DAG Structure
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
    description='Daily data transformation pipeline',
    schedule='0 2 * * *',  # 2 AM daily
    catchup=False
)

# Tasks
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

# Dependencies
extract_data >> run_dbt >> data_quality
```

## Data Quality Framework

### Automated Tests
1. **Schema Tests**: Column existence, data types
2. **Referential Integrity**: Foreign key validation
3. **Business Rules**: Custom SQL tests
4. **Freshness Checks**: Data recency validation

### Monitoring & Alerts
```yaml
# dbt_project.yml
on-run-end:
  - "{{ log_test_results() }}"
  - "{{ send_slack_notification() }}"
```

## Performance Optimization
- Incremental models for large tables
- Proper indexing strategy
- Partition pruning
- Materialized views for complex queries
- Query result caching

## Custom Commands

### `/run-pipeline [date]`
Execute pipeline for specific date:
1. Trigger Airflow DAG
2. Monitor execution
3. Validate results
4. Send completion notification

### `/test-models [model]`
Test specific DBT models:
1. Compile SQL
2. Run in dev environment
3. Execute tests
4. Generate report

## Troubleshooting

### Common Issues
1. **Slow queries**: Check execution plan
2. **Test failures**: Verify source data quality
3. **DAG failures**: Check Airflow logs
4. **Memory issues**: Optimize model materialization

### Debug Queries
```sql
-- Check row counts
SELECT COUNT(*) FROM {{ ref('model_name') }};

-- Verify freshness
SELECT MAX(updated_at) FROM {{ ref('model_name') }};

-- Find duplicates
SELECT id, COUNT(*) 
FROM {{ ref('model_name') }}
GROUP BY id 
HAVING COUNT(*) > 1;
```
```

---

## 機械学習プロジェクト

### Python ML プロジェクト

```markdown
# CLAUDE.md - ML Project

## Project Overview
Machine learning project for [purpose] using [algorithms].
Achieves [performance metrics] on [dataset].

## Project Structure
```
project/
├── data/              # Data storage
│   ├── raw/          # Original data
│   ├── processed/    # Processed data
│   └── external/     # External datasets
├── notebooks/         # Jupyter notebooks
│   ├── exploration/  # EDA notebooks
│   └── experiments/  # Experiment tracking
├── src/              # Source code
│   ├── data/         # Data processing
│   ├── features/     # Feature engineering
│   ├── models/       # Model definitions
│   ├── training/     # Training scripts
│   └── evaluation/   # Evaluation metrics
├── models/           # Saved models
├── reports/          # Generated reports
└── tests/           # Unit tests
```

## ML Pipeline

### 1. Data Preparation
```python
# src/data/prepare.py
def prepare_dataset(raw_data_path: str) -> pd.DataFrame:
    """
    Load and prepare dataset for training
    
    Steps:
    1. Load raw data
    2. Handle missing values
    3. Encode categorical variables
    4. Split features and target
    """
    df = pd.read_csv(raw_data_path)
    
    # Handle missing values
    df = handle_missing_values(df)
    
    # Feature engineering
    df = create_features(df)
    
    return df
```

### 2. Model Training
```python
# src/models/train.py
def train_model(
    X_train: np.ndarray,
    y_train: np.ndarray,
    model_type: str = 'xgboost'
) -> Model:
    """Train ML model with hyperparameter tuning"""
    
    # Define model
    model = create_model(model_type)
    
    # Hyperparameter tuning
    best_params = tune_hyperparameters(
        model, X_train, y_train
    )
    
    # Train final model
    model.set_params(**best_params)
    model.fit(X_train, y_train)
    
    return model
```

### 3. Evaluation
```python
# src/evaluation/metrics.py
def evaluate_model(
    model: Model,
    X_test: np.ndarray,
    y_test: np.ndarray
) -> Dict[str, float]:
    """Comprehensive model evaluation"""
    
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

## Experiment Tracking

### MLflow Integration
```python
import mlflow
import mlflow.sklearn

with mlflow.start_run():
    # Log parameters
    mlflow.log_params({
        'model_type': 'xgboost',
        'n_estimators': 100,
        'learning_rate': 0.1
    })
    
    # Train model
    model = train_model(X_train, y_train)
    
    # Log metrics
    metrics = evaluate_model(model, X_test, y_test)
    mlflow.log_metrics(metrics)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
```

## Feature Engineering

### Feature Store
```python
# features/feature_store.py
class FeatureStore:
    """Centralized feature management"""
    
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

## Model Deployment

### API Endpoint
```python
# api/predict.py
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class PredictionRequest(BaseModel):
    features: List[float]

@app.post("/predict")
async def predict(request: PredictionRequest):
    # Load model
    model = load_model('latest')
    
    # Make prediction
    prediction = model.predict([request.features])
    
    return {
        'prediction': prediction[0],
        'confidence': model.predict_proba([request.features])[0].max()
    }
```

## Testing Strategy

### Unit Tests
```python
# tests/test_features.py
def test_feature_engineering():
    # Test data
    df = pd.DataFrame({
        'age': [25, 30, 35],
        'income': [50000, 60000, 70000]
    })
    
    # Apply features
    features = create_features(df)
    
    # Assertions
    assert 'age_group' in features.columns
    assert features.shape[0] == 3
```

### Model Tests
```python
# tests/test_model.py
def test_model_prediction():
    # Load test model
    model = load_test_model()
    
    # Test input
    X_test = [[25, 50000, 700]]
    
    # Prediction
    pred = model.predict(X_test)
    
    # Assertions
    assert len(pred) == 1
    assert 0 <= pred[0] <= 1
```

## Custom Commands

### `/train [experiment_name]`
Run training experiment:
1. Load and preprocess data
2. Train model with cross-validation
3. Log results to MLflow
4. Save best model

### `/evaluate [model_id]`
Evaluate specific model:
1. Load model from registry
2. Run on test set
3. Generate evaluation report
4. Create visualizations

### `/deploy [model_id] [environment]`
Deploy model to environment:
1. Run final tests
2. Create Docker container
3. Deploy to Kubernetes
4. Set up monitoring

## Performance Optimization
- Use GPU for training when available
- Implement batch prediction
- Cache preprocessed features
- Use model quantization for inference
- Parallelize hyperparameter search

## Monitoring
- Model drift detection
- Prediction latency tracking
- Feature importance changes
- Data quality monitoring
- A/B testing framework
```

---

## モバイルアプリ開発

### React Native + TypeScript

```markdown
# CLAUDE.md - Mobile App Project

## Project Overview
Cross-platform mobile application built with React Native and TypeScript.
Supports iOS and Android with [key features].

## Project Structure
```
project/
├── src/
│   ├── components/      # Reusable components
│   ├── screens/        # Screen components
│   ├── navigation/     # Navigation setup
│   ├── services/       # API services
│   ├── store/          # State management
│   ├── utils/          # Utilities
│   └── types/          # TypeScript types
├── assets/             # Images, fonts
├── ios/               # iOS specific
├── android/           # Android specific
└── __tests__/         # Test files
```

## Development Setup

### Prerequisites
```bash
# Install dependencies
npm install

# iOS setup
cd ios && pod install

# Android setup
# Ensure Android Studio and emulator are set up
```

### Running the App
```bash
# iOS
npm run ios

# Android
npm run android

# With specific device
npm run ios -- --device "iPhone 14"
npm run android -- --deviceId emulator-5554
```

## Navigation Structure
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

## Component Guidelines

### Component Structure
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

## State Management

### Zustand Store
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

## API Integration

### API Service
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
      throw new Error(`API Error: ${response.status}`);
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

## Platform-Specific Code

### Platform Detection
```typescript
// utils/platform.ts
import { Platform } from 'react-native';

export const isIOS = Platform.OS === 'ios';
export const isAndroid = Platform.OS === 'android';

// Platform-specific styles
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

## Testing Strategy

### Component Tests
```typescript
// __tests__/Button.test.tsx
import { render, fireEvent } from '@testing-library/react-native';
import { Button } from '../src/components/Button';

describe('Button', () => {
  it('renders correctly', () => {
    const { getByText } = render(
      <Button title="Press me" onPress={() => {}} />
    );
    
    expect(getByText('Press me')).toBeTruthy();
  });
  
  it('calls onPress when pressed', () => {
    const onPress = jest.fn();
    const { getByText } = render(
      <Button title="Press me" onPress={onPress} />
    );
    
    fireEvent.press(getByText('Press me'));
    expect(onPress).toHaveBeenCalled();
  });
});
```

## Performance Optimization

### Best Practices
1. Use `React.memo` for expensive components
2. Implement `FlashList` instead of `FlatList`
3. Optimize images with proper sizing
4. Use lazy loading for screens
5. Minimize bridge calls

### Performance Monitoring
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

## Build & Deployment

### iOS Build
```bash
# Development build
npm run ios:build:dev

# Production build
npm run ios:build:prod

# Archive for App Store
cd ios && xcodebuild archive
```

### Android Build
```bash
# Development APK
npm run android:build:dev

# Production bundle
npm run android:build:prod

# Generate signed APK
cd android && ./gradlew assembleRelease
```

## Custom Commands

### `/new-screen [name]`
Create new screen with navigation:
1. Create screen component
2. Add to navigation
3. Create tests
4. Update types

### `/add-native-module [name]`
Add native module:
1. Create iOS implementation
2. Create Android implementation
3. Create TypeScript interface
4. Add to package

## Debugging Tips
- Use Flipper for network inspection
- React Native Debugger for state
- Xcode for iOS specific issues
- Android Studio for Android logs
- Remote JS debugging in Chrome
```

---

## インフラストラクチャ

### Terraform + Kubernetes

```markdown
# CLAUDE.md - Infrastructure as Code

## Project Overview
Infrastructure automation using Terraform for cloud resources
and Kubernetes for container orchestration.

## Repository Structure
```
infrastructure/
├── terraform/           # Terraform configurations
│   ├── environments/   # Environment-specific
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/       # Reusable modules
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── s3/
│   └── global/        # Global resources
├── kubernetes/         # K8s manifests
│   ├── base/          # Base configurations
│   ├── overlays/      # Environment overlays
│   └── charts/        # Helm charts
├── scripts/           # Utility scripts
└── docs/             # Documentation
```

## Terraform Guidelines

### Module Structure
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

# Subnets
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

### Variable Management
```hcl
# environments/prod/terraform.tfvars
project     = "myapp"
environment = "prod"
region      = "us-east-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

# EKS Configuration
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

### State Management
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Kubernetes Configuration

### Base Application
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
    newName: 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp
    newTag: v1.2.3

replicas:
  - name: myapp
    count: 5
```

## GitOps Workflow

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

## Monitoring & Observability

### Prometheus Rules
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
            summary: High error rate detected
            description: "Error rate is above 5%"
```

## Security Best Practices

### Network Policies
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

### Secret Management
```bash
# Using Sealed Secrets
kubectl create secret generic myapp-secrets \
  --from-literal=api-key=$API_KEY \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secrets.yaml
```

## Disaster Recovery

### Backup Strategy
```bash
#!/bin/bash
# scripts/backup.sh

# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier prod-db \
  --db-snapshot-identifier prod-db-$(date +%Y%m%d-%H%M%S)

# Backup Kubernetes resources
velero backup create prod-backup-$(date +%Y%m%d) \
  --include-namespaces myapp \
  --ttl 720h

# Backup S3 data
aws s3 sync s3://prod-data s3://prod-data-backup \
  --delete
```

## Custom Commands

### `/deploy [environment] [version]`
Deploy application version:
1. Update image tag in Kustomization
2. Commit and push changes
3. ArgoCD syncs automatically
4. Monitor deployment status

### `/scale [environment] [replicas]`
Scale application:
1. Update replica count
2. Apply changes
3. Verify pod scaling
4. Update monitoring alerts

### `/disaster-recovery [environment]`
Execute DR procedure:
1. Create backups
2. Verify backup integrity
3. Document current state
4. Test restore procedure

## Cost Optimization
- Use spot instances for non-critical workloads
- Implement auto-scaling policies
- Schedule dev environment shutdown
- Regular resource utilization review
- Reserved instances for stable workloads

## Compliance & Auditing
- Enable CloudTrail for all regions
- Implement resource tagging strategy
- Regular security scanning
- Automated compliance checks
- Infrastructure change tracking
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

これらのベストプラクティスを実践することで、Claude Codeとの協働がより効率的になります。